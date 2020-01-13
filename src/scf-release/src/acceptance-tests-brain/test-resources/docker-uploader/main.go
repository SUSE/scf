// Package main implements the docker uploader application
package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/docker/libtrust"
)

func main() {
	var port int
	var err error

	if port, err = strconv.Atoi(os.Getenv("PORT")); err != nil {
		port = 8080
	}

	// Don't check for real CA certificates
	http.DefaultTransport.(*http.Transport).TLSClientConfig = &tls.Config{
		InsecureSkipVerify: true,
	}

	fmt.Printf("Listening on :%d\n", port)
	http.ListenAndServe(fmt.Sprintf(":%d", port), http.HandlerFunc(handler))
}

func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Printf("Handling %s\n", r.Method)
	if r.Method == http.MethodGet {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Ping!"))
		return
	}
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", strings.Join([]string{http.MethodGet, http.MethodPost}, ", "))
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	registry := r.FormValue("registry")
	if registry == "" {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte("Required parameter `registry` not specified"))
		return
	}

	name := r.FormValue("name")
	tag := "latest"
	if name == "" {
		name = "docker-uploader"
	}
	if strings.Contains(name, ":") {
		index := strings.LastIndex(name, ":")
		tag = name[index:]
		name = name[:index-1]
	}

	err := doUpload(r.Context(), registry, name, tag)
	if err != nil {
		fmt.Printf("Error uploading: %v\n", err)
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(fmt.Sprintf("Error uploading: %v", err)))
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Upload completed with no errors\n"))
}

func doUpload(ctx context.Context, registry, name, tag string) error {
	fmt.Printf("Will upload image %s:%s to %s\n", name, tag, registry)
	layerInfo, diffID, err := uploadTarBlob(ctx, registry, name)
	if err != nil {
		return fmt.Errorf("error uploading executable: %w", err)
	}
	if layerInfo.digest == "" {
		return fmt.Errorf("got invalid empty layer digest")
	}
	fmt.Printf("Uploaded layer blob with size %v digest %v\n", layerInfo.size, layerInfo.digest)

	configInfo, err := uploadConfigBlob(ctx, registry, name, diffID)
	if err != nil {
		return fmt.Errorf("error uploading config: %w", err)
	}
	if configInfo.digest == "" {
		return fmt.Errorf("got invalid empty config digest")
	}

	err = uploadManifest(ctx, registry, name, tag, layerInfo, configInfo)
	if err != nil {
		return fmt.Errorf("error uploading manifest: %w", err)
	}
	fmt.Printf("Upload completed with no errors\n")
	return nil
}

// makeLayer returns a tgz file of the executable, as well as the (uncompressed)
// digest of that tar file.  The uncompressed digest is required as the diff ID
// in the docker image.
func makeLayer() (*os.File, string, error) {
	outFile, err := ioutil.TempFile("", "layer-blob-")
	if err != nil {
		return nil, "", err
	}
	defer func() {
		if err != nil {
			outFile.Close()
			os.Remove(outFile.Name())
			// resultFile is assigned by the return statements
		}
	}()

	gzipFile := gzip.NewWriter(outFile)
	digestHasher := sha256.New()
	writerWrapper := io.MultiWriter(gzipFile, digestHasher)
	tarFile := tar.NewWriter(writerWrapper)

	file, err := os.Open("/proc/self/exe")
	if err != nil {
		return nil, "", err
	}
	info, err := file.Stat()
	if err != nil {
		return nil, "", err
	}

	err = tarFile.WriteHeader(&tar.Header{
		Typeflag: tar.TypeReg,
		Name:     "/entrypoint",
		Size:     info.Size(),
		Mode:     0755,
	})
	if err != nil {
		return nil, "", err
	}
	if _, err := io.Copy(tarFile, file); err != nil {
		return nil, "", err
	}

	// Unlike docker, garden-runc needs /etc/passwd to work
	for _, info := range []struct {
		*tar.Header
		contents string
	}{
		{
			Header: &tar.Header{
				Typeflag: tar.TypeDir,
				Name:     "/etc",
				Mode:     0755,
			},
		},
		{
			Header: &tar.Header{
				Name: "/etc/passwd",
			},
			contents: "root:x:0:0:root:/root:/bin/bash",
		},
	} {
		if info.Typeflag == 0 {
			info.Typeflag = tar.TypeReg
		}
		if info.Size == 0 {
			info.Size = int64(len(info.contents))
		}
		if info.Mode == 0 {
			info.Mode = 0644
		}
		err = tarFile.WriteHeader(info.Header)
		if err != nil {
			return nil, "", err
		}
		offset := 0
		for offset < len(info.contents) {
			written, err := tarFile.Write([]byte(info.contents[offset:]))
			if err != nil {
				return nil, "", err
			}
			offset += written
		}
	}

	if err := tarFile.Close(); err != nil {
		return nil, "", err
	}

	if err := gzipFile.Close(); err != nil {
		return nil, "", err
	}

	if _, err := outFile.Seek(0, io.SeekStart); err != nil {
		return nil, "", err
	}

	digest := digestHasher.Sum(nil)

	return outFile, fmt.Sprintf("sha256:%x", digest), nil
}

type blobInfo struct {
	digest string
	size   int64
}

// uploadTarBlob uploads the tar file blob, returning the layer digest and layer id
func uploadTarBlob(ctx context.Context, registry, name string) (*blobInfo, string, error) {
	file, uncompressedDigest, err := makeLayer()
	if err != nil {
		return nil, "", fmt.Errorf("error making layer: %w", err)
	}
	defer os.Remove(file.Name())

	resultInfo, err := uploadBlob(ctx, registry, name, file)
	return resultInfo, uncompressedDigest, err
}

// uploadBlob uploads a blob, returning the layer digest
func uploadBlob(ctx context.Context, registry, name string, blob io.ReadSeeker) (*blobInfo, error) {
	// The current version of github.com/docker/distribution doesn't actually
	// seem to support uploading in one go with a pre-supplied digest; just
	// initial the upload.
	// https://github.com/docker/distribution/blob/v2.7.1/docs/spec/api.md#starting-an-upload
	uploadURL := fmt.Sprintf("%s/v2/%s/blobs/uploads/", registry, name)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, uploadURL, nil)
	if err != nil {
		return nil, fmt.Errorf("error creating initial URL: %w", err)
	}
	req.Header.Set("Content-Length", "0")
	req.Header.Set("Content-Type", "application/octet-stream")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("error initiating upload: %w", err)
	}

	// Do the actual upload
	// https://github.com/docker/distribution/blob/v2.7.1/docs/spec/api.md#monolithic-upload

	newURL, err := url.Parse(resp.Header.Get("Location"))
	if err != nil {
		return nil, fmt.Errorf("error getting upload URL: %w", err)
	}
	_, err = io.Copy(ioutil.Discard, resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to discard response body: %w", err)
	}
	resp.Body.Close()

	digest, fileLength, err := calculateFileDigest(blob)
	if err != nil {
		return nil, err
	}
	query := newURL.Query()
	query.Add("digest", digest)
	newURL.RawQuery = query.Encode()

	fmt.Printf("Got redirected to %s\n", newURL.String())
	req, err = http.NewRequestWithContext(ctx, http.MethodPut, newURL.String(), blob)
	if err != nil {
		return nil, err
	}
	req.ContentLength = fileLength
	req.Header.Set("Content-Type", "application/octet-stream")
	resp, err = http.DefaultClient.Do(req)
	fmt.Printf("Blob upload completed, result %v\n", err)
	for k, v := range resp.Header {
		fmt.Printf("%s: %s\n", k, v)
	}
	fmt.Printf("\n")
	_, _ = io.Copy(os.Stdout, resp.Body)
	fmt.Printf("\n")
	if err != nil {
		return nil, err
	}

	switch resp.StatusCode {
	case http.StatusCreated:
		break
	case http.StatusBadRequest, http.StatusMethodNotAllowed, http.StatusForbidden, http.StatusNotFound:
		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return nil, fmt.Errorf("error reading response: %w", err)
		}
		return nil, fmt.Errorf("error uploading: %s: %s", resp.Status, string(body))
	case http.StatusUnauthorized:
		return nil, fmt.Errorf("error uploading: unauthorized")
	default:
		return nil, fmt.Errorf("error uploading: unknown status %s", resp.Status)
	}

	result := blobInfo{
		digest: resp.Header.Get("Docker-Content-Digest"),
		size:   fileLength,
	}
	fmt.Printf("Uploaded blob digest %s size %d\n", result.digest, result.size)
	return &result, nil
}

// calculate the digest and length of a file, and seek back to the start.
func calculateFileDigest(file io.ReadSeeker) (string, int64, error) {
	_, err := file.Seek(0, io.SeekStart)
	if err != nil {
		return "", 0, nil
	}

	digestHasher := sha256.New()
	length, err := io.Copy(digestHasher, file)
	if err != nil {
		return "", 0, fmt.Errorf("error calculating digest of file: %w", err)
	}

	_, err = file.Seek(0, io.SeekStart)
	if err != nil {
		return "", 0, nil
	}

	digest := fmt.Sprintf("sha256:%x", digestHasher.Sum(nil))
	return digest, length, nil
}

var privateKey libtrust.PrivateKey

// Sign a given structure, returning the JSON bytes.
func signStruct(structure interface{}) ([]byte, error) {
	var err error
	if privateKey == nil {
		rsaKey, err := rsa.GenerateKey(rand.Reader, 1024)
		if err != nil {
			return nil, fmt.Errorf("failed to create RSA key to sign blobs: %w", err)
		}
		privateKey, err = libtrust.FromCryptoPrivateKey(rsaKey)
		if err != nil {
			return nil, fmt.Errorf("failed to convert RSA key for signing: %w", err)
		}
	}

	jsonBytes, err := json.MarshalIndent(structure, "", "    ")
	if err != nil {
		return nil, fmt.Errorf("error marshalling structure for signing: %w", err)
	}

	sig, err := libtrust.NewJSONSignature(jsonBytes)
	if err != nil {
		return nil, fmt.Errorf("failed to make JSON signature: %w", err)
	}
	err = sig.Sign(privateKey)
	if err != nil {
		return nil, fmt.Errorf("failed to sign: %w", err)
	}
	blob, err := sig.PrettySignature("signatures")
	if err != nil {
		return nil, fmt.Errorf("failed to add sig: %w", err)
	}

	_, _ = os.Stdout.Write(blob)
	_, _ = os.Stdout.WriteString("\n")
	return blob, nil
}

// uploadConfigBlob uploads the docker image config blob, returning the layer signature and size
func uploadConfigBlob(ctx context.Context, registry, name, diffID string) (*blobInfo, error) {
	// https://github.com/moby/moby/blob/4fb59c20a4fb54f944fe170d0ff1d00eb4a24d6f/image/spec/v1.2.md#image-json-field-descriptions
	// We're only using a subset here, since the rest should _not_ be supplied
	// if there are no valid values.
	config := map[string]interface{}{
		"created":      time.Now(),
		"author":       "docker-uploader",
		"architecture": "amd64",
		"os":           "linux",
		"config": map[string]interface{}{
			"Entrypoint": []string{"/entrypoint"},
		},
		"rootfs": map[string]interface{}{
			"diff_ids": []string{diffID},
			"type":     "layers",
		},
	}
	signedBlob, err := signStruct(&config)
	if err != nil {
		return nil, fmt.Errorf("error signing config blob: %w", err)
	}

	return uploadBlob(ctx, registry, name, bytes.NewReader(signedBlob))
}

// buildManifest returns a serialized JSON manifest for a docker image of the
// given name and tag, with a single layer of the given layer digest
func buildManifest(name, tag string, layerInfo, configInfo *blobInfo) (io.Reader, error) {
	// https://github.com/docker/distribution/blob/v2.7.1/docs/spec/manifest-v2-2.md
	manifest := map[string]interface{}{
		"SchemaVersion": 2,
		"MediaType":     "application/vnd.docker.distribution.manifest.v2+json",
		"Config": map[string]interface{}{
			"MediaType": "application/vnd.docker.container.image.v1+json",
			"Size":      configInfo.size,
			"Digest":    configInfo.digest,
		},
		"Layers": []map[string]interface{}{
			{
				"MediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
				"Size":      layerInfo.size,
				"Digest":    layerInfo.digest,
			},
		},
	}
	signed, err := signStruct(&manifest)
	if err != nil {
		return nil, fmt.Errorf("error signing manifest: %w", err)
	}

	return bytes.NewReader(signed), nil
}

// uploadManifest uploads the docker image manifest to a docker registry
func uploadManifest(ctx context.Context, registry, name, tag string, layerInfo, configInfo *blobInfo) error {
	manifest, err := buildManifest(name, tag, layerInfo, configInfo)
	if err != nil {
		return fmt.Errorf("could not build manifest: %w", err)
	}
	manifestURL := fmt.Sprintf("%s/v2/%s/manifests/%s", registry, name, tag)
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, manifestURL, manifest)
	if err != nil {
		return fmt.Errorf("could not create manifest upload request: %w", err)
	}
	req.Header.Set("Content-Type", "application/vnd.docker.distribution.manifest.v2+json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("could not upload manifest: %w", err)
	}
	fmt.Printf("Got response: %s\n", resp.Status)
	for k, v := range resp.Header {
		fmt.Printf("%s: %s\n", k, v)
	}
	fmt.Printf("\n")
	_, _ = io.Copy(os.Stdout, resp.Body)
	fmt.Printf("\n")
	switch resp.StatusCode {
	case http.StatusOK, http.StatusCreated:
		return nil
	default:
		return fmt.Errorf("got unexpected status %d (%s)", resp.StatusCode, resp.Status)
	}
}

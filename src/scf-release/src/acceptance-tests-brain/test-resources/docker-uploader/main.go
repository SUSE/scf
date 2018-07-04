// Package main implements the docker uploader application
package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/tls"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"

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
	fmt.Printf("Will upload image %s:%s to %s\n", name, tag, registry)

	layerDigest, err := uploadBlob(registry, name)
	if err != nil {
		fmt.Printf("Error uploading executable: %s\n", err)
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(fmt.Sprintf("Error uploading executable: %s", err)))
		return
	}
	if layerDigest == "" {
		fmt.Printf("Got invalid empty digest\n")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("Got invalid empty digest"))
		return
	}
	fmt.Printf("Uploaded blob with digest %v\n", layerDigest)
	err = uploadManifest(registry, name, tag, layerDigest)
	if err != nil {
		fmt.Printf("Error uploading manifest: %s\n", err)
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(fmt.Sprintf("Error uploading manifest: %s", err)))
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Upload completed with no errors\n"))
	fmt.Printf("Upload completed with no errors\n")
}

// makeLayer returns a tar file of the executable
func makeLayer() (resultFile *os.File, err error) {
	outFile, err := ioutil.TempFile("", "layer-blob-")
	if err != nil {
		return nil, err
	}
	defer func() {
		if err != nil {
			outFile.Close()
			os.Remove(outFile.Name())
			// resultFile is assigned by the return statements
		}
	}()

	gzipFile := gzip.NewWriter(outFile)
	tarFile := tar.NewWriter(gzipFile)

	file, err := os.Open("/proc/self/exe")
	if err != nil {
		return nil, err
	}
	info, err := file.Stat()
	if err != nil {
		return nil, err
	}

	err = tarFile.WriteHeader(&tar.Header{
		Typeflag: tar.TypeReg,
		Name:     "/entrypoint",
		Size:     info.Size(),
		Mode:     0755,
	})
	if err != nil {
		return nil, err
	}
	if _, err := io.Copy(tarFile, file); err != nil {
		return nil, err
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
			return nil, err
		}
		offset := 0
		for offset < len(info.contents) {
			written, err := tarFile.Write([]byte(info.contents[offset:]))
			if err != nil {
				return nil, err
			}
			offset += written
		}
	}

	if err := tarFile.Close(); err != nil {
		return nil, err
	}

	if err := gzipFile.Close(); err != nil {
		return nil, err
	}

	if _, err := outFile.Seek(0, os.SEEK_SET); err != nil {
		return nil, err
	}

	return outFile, nil
}

// uploadBlob uploads the tar file blob, returning the layer signature
func uploadBlob(registry, name string) (string, error) {
	file, err := makeLayer()
	if err != nil {
		return "", err
	}
	defer os.Remove(file.Name())

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return "", err
	}
	digest := fmt.Sprintf("%x", hasher.Sum(nil))
	fileLength, err := file.Seek(0, os.SEEK_CUR)
	if err != nil {
		return "", err
	}
	if _, err := file.Seek(0, os.SEEK_SET); err != nil {
		return "", err
	}

	uploadURL := fmt.Sprintf("%s/v2/%s/blobs/uploads/?digest=sha256:%s", registry, name, digest)
	req, err := http.NewRequest(http.MethodPost, uploadURL, file)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Length", fmt.Sprintf("%d", fileLength))
	req.Header.Set("Content-Type", "application/octet-stream")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}

	for resp.StatusCode == http.StatusAccepted {
		fmt.Printf("Got `%s` even though we wanted one-stop upload, retrying\n", resp.Status)
		// The last upload closed the file; reopen it
		file, err = os.Open(file.Name())
		if err != nil {
			return "", err
		}
		newURL, err := url.Parse(resp.Header.Get("Location"))
		if err != nil {
			return "", err
		}
		query := newURL.Query()
		query.Add("digest", "sha256:"+digest)
		newURL.RawQuery = query.Encode()
		req, err = http.NewRequest(http.MethodPut, newURL.String(), file)
		if err != nil {
			return "", err
		}
		req.Header.Set("Content-Length", fmt.Sprintf("%d", fileLength))
		req.Header.Set("Content-Type", "application/octet-stream")
		resp, err = http.DefaultClient.Do(req)
		if err != nil {
			return "", err
		}
	}

	switch resp.StatusCode {
	case http.StatusCreated:
		break
	case http.StatusAccepted:
		panic("Got status accepted outside loop")
	case http.StatusBadRequest, http.StatusMethodNotAllowed, http.StatusForbidden, http.StatusNotFound:
		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return "", err
		}
		return "", fmt.Errorf("Error uploading: %s: %s", resp.Status, string(body))
	case http.StatusUnauthorized:
		return "", fmt.Errorf("Error uploading: unauthorized")
	default:
		return "", fmt.Errorf("Error uploading: unknown status %s", resp.Status)
	}

	return digest, nil
}

// buildManifest returns a serialized JSON manifest for a docker image of the
// given name and tag, with a single layer of the given layer digest
func buildManifest(name, tag, layerDigest string) (io.Reader, error) {
	mapping := map[string]interface{}{
		"schemaVersion": 1,
		"name":          name,
		"tag":           tag,
		"architecture":  "amd64",
		"fsLayers": []map[string]interface{}{
			map[string]interface{}{
				"blobSum": "sha256:" + layerDigest,
			},
		},
		"history": []map[string]string{
			map[string]string{
				"v1Compatibility": fmt.Sprintf(`{
					"architecture": "amd64",
					"config": {
						"Entrypoint": ["/entrypoint"]
					},
					"id": "%s"
				}`, layerDigest),
			},
		},
	}
	sig, err := libtrust.NewJSONSignatureFromMap(mapping)
	if err != nil {
		fmt.Printf("Failed to make JSON sig: %s\n", err)
		return nil, err
	}

	rsaKey, err := rsa.GenerateKey(rand.Reader, 1024)
	if err != nil {
		return nil, err
	}
	key, err := libtrust.FromCryptoPrivateKey(rsaKey)
	if err != nil {
		return nil, err
	}
	err = sig.Sign(key)
	if err != nil {
		fmt.Printf("Failed to sign: %s\n", err)
		return nil, err
	}

	blob, err := sig.PrettySignature("signatures")
	if err != nil {
		fmt.Printf("Failed to add sig: %s\n", err)
		return nil, err
	}

	fmt.Printf("%s\n", string(blob))
	return bytes.NewReader(blob), nil
}

// uploadManifest uploads the docker image manifest to a docker registry
func uploadManifest(registry, name, tag, layerDigest string) error {
	manifest, err := buildManifest(name, tag, layerDigest)
	if err != nil {
		return err
	}
	manifestURL := fmt.Sprintf("%s/v2/%s/manifests/%s", registry, name, tag)
	req, err := http.NewRequest(http.MethodPut, manifestURL, manifest)
	req.Header.Set("Content-Type", "application/vnd.docker.distribution.manifest.v1+json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	fmt.Printf("Got response: %s\n", resp.Status)
	for k, v := range resp.Header {
		fmt.Printf("%s: %s\n", k, v)
	}
	fmt.Printf("\n")
	io.Copy(os.Stdout, resp.Body)
	fmt.Printf("\n")
	return nil
}

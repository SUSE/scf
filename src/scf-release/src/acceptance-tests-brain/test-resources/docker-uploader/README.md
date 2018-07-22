# docker-uploader

This is a web server which implements uploading itself to a docker registry.

## Ping response

Any HTTP request with a `GET` method returns a ping response.

## Upload docker image

Any HTTP request with a `POST` method will upload the server as a docker image

### Parameters

| Name | Required | Description
|---|---|---
| `registry` | :white_check_mark: | Docker registry to upload to
| `name` | | Image tag; `docker-uploader:latest` by default.

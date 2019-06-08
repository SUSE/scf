load("@io_bazel_rules_docker//container:container.bzl", "container_pull")

RELEASES = {
    "pxc": struct(
        registry = "index.docker.io",
        repository = "cfcontainerization/pxc",
        tag = "opensuse-42.3-36.g03b4653-30.80-7.0.0_332.g0d8469bb-0.17.0",
        digest = "sha256:8013aabf5a318640bc38d083ebda1b83f3c4b4ae4d7826bb11662fb6951749dd",
    ),
}

def pull_releases():
    for release_name in RELEASES:
        release = RELEASES[release_name]
        container_pull(
            name = release_name,
            registry = release.registry,
            repository = release.repository,
            tag = release.tag,
            digest = release.digest,
        )

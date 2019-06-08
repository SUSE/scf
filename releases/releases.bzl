load("@io_bazel_rules_docker//container:container.bzl", "container_pull")

RELEASES = {
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

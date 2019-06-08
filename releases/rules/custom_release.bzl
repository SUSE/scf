load(
    "@io_bazel_rules_docker//container:container.bzl",
    "container_bundle",
    "container_image",
    "container_layer",
)
load("//releases:releases.bzl", "RELEASES")

def custom_release(name, base_release, overrides):
    layers = []
    layer_num = 1
    for override in overrides:
        layer = "layer-%d" % layer_num
        layer_num += 1
        layers += [":%s" % layer]
        container_layer(
            name = layer,
            files = [override],
            data_path = "./overrides/%s" % name,
            directory = "/var/vcap",
        )

    container_image_name = "%s_image" % name
    container_image_target = ":%s" % container_image_name

    container_image(
        name = container_image_name,
        base = "@%s//image" % base_release,
        layers = layers,
    )

    image_repository = "{STABLE_DOCKER_ORGANIZATION}/%s" % base_release
    image_tag = RELEASES[base_release].tag
    new_image_tag = "%s-{STABLE_VERSION_TAG}" % image_tag
    image = "%s:%s" % (image_repository, new_image_tag)

    container_bundle(
        name = name,
        images = {
            image: container_image_target,
        }
    )

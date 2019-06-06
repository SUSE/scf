workspace(name = "scf")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "io_bazel_rules_go",
    urls = ["https://github.com/bazelbuild/rules_go/releases/download/0.18.5/rules_go-0.18.5.tar.gz"],
    sha256 = "a82a352bffae6bee4e95f68a8d80a70e87f42c4741e6a448bec11998fcc82329",
)

http_archive(
    name = "bazel_gazelle",
    urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/0.17.0/bazel-gazelle-0.17.0.tar.gz"],
    sha256 = "3c681998538231a2d24d0c07ed5a7658cb72bfb5fd4bf9911157c0e9ac6a2687",
)

load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")

go_rules_dependencies()

go_register_toolchains()

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")

gazelle_dependencies()

go_repository(
    name = "com_github_cloudfoundry_cf_smoke_tests",
    commit = "8f6d750879fecebfc8104a2848ddcfff55526053",
    importpath = "github.com/cloudfoundry/cf-smoke-tests",
    build_file_proto_mode = "disable_global",
    build_external = "vendored",
)

go_repository(
    name = "com_github_cloudfoundry_cf_acceptance_tests",
    commit = "0dd6680ea3676c0ab6ec7336aa391251f5a75552",
    importpath = "github.com/cloudfoundry/cf-acceptance-tests",
    build_file_proto_mode = "disable_global",
    build_external = "vendored",
)

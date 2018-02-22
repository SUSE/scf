#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
    echo "usage: update-versions RELEASE"
    exit
fi

GIT_ROOT=${GIT_ROOT:-$(git rev-parse --show-toplevel)}

RELEASE=${1}

VERSION_INFO=$("${GIT_ROOT}/bin/get-cf-versions.sh" "${RELEASE}")

# Save, for debugging
mkdir -p ${GIT_ROOT}/_work
echo "${VERSION_INFO}" > ${GIT_ROOT}/_work/VERSION_INFO

release_ref () {
    release="${1}"
    echo "${VERSION_INFO}" | awk -F , "/$release/ { print \$2 }"
}

release_origin() {
    release=${1}
    case $release in
	*-buildpack-*)
	    where=$(git -C ${GIT_ROOT}/src/buildpacks/$release remote -v | grep fetch | awk '{ print $2 }' | uniq)
	    ;;
	*)
	    where=$(git -C ${GIT_ROOT}/src/$release remote -v | grep fetch| awk '{ print $2 }' | uniq)
	    ;;
    esac
    echo "${where}"
}

get_submodule_ref () {
    release=${1}
    dir="${2:-$release}"
    ref=$(release_ref $release)
    echo "${release}" = "${ref}" '@' "$(release_origin $dir)" \
        >> ${GIT_ROOT}/_work/SUBMODULE_REFERENCES
    echo "${ref}"
}

echo > ${GIT_ROOT}/_work/SUBMODULE_REFERENCES    ""

update_submodule () {
    echo
    echo _____________________________ "Updating Submodule ${1}"
    echo ............................. "Updating to commit ${2}"
    echo ............................. "Updating rootdir . ${3}"
	release_name=${1}
	commit_id=${2}
	root_dir=${3}
    echo ............................. "Updating for ..... ${GIT_ROOT}"
    echo ............................. "Updating directory ${GIT_ROOT}/${root_dir}/${release_name}"
    echo
	cd "${GIT_ROOT}/${root_dir}/${release_name}"
	git fetch --all
	cd "${GIT_ROOT}"
	git clone "${root_dir}/${release_name}" "${root_dir}/${release_name}-clone" --recursive
	cd "${root_dir}/${release_name}-clone"
	git fetch --all
	git checkout "${commit_id}"
	git submodule update --init --recursive
}

for release_name in \
    capi-release \
    cf-mysql-release \
    cf-smoke-tests-release \
    cf-syslog-drain-release \
    cflinuxf2-release \
    diego-release \
    garden-runc-release \
    loggregator-release \
    nats-release \
    nfs-volume-release \
    routing-release \
    statsd-injector-release
do
	clone_dir=${GIT_ROOT}/src/${release_name}-clone
	if test -e "${clone_dir}"
	then
		echo "${clone_dir} already exists from previous upgrade."
		exit 1
	fi
done

BUILDPACK_SUBMODULES="go-buildpack-release \
                      binary-buildpack-release \
                      nodejs-buildpack-release \
                      ruby-buildpack-release \
                      php-buildpack-release \
                      python-buildpack-release \
                      staticfile-buildpack-release \
                      java-buildpack-release"

for release_name in ${BUILDPACK_SUBMODULES}
do
	clone_dir=${GIT_ROOT}/src/buildpacks/${release_name}-clone
	if test -e "${clone_dir}"
	then
		echo "${clone_dir} already exists from previous upgrade."
		exit 1
	fi
done

# Note `v`-prefix on the version tags
CFLINUXFS2_RELEASE=v$(get_submodule_ref cflinuxfs2-release)
DIEGO_RELEASE=v$(get_submodule_ref diego-release)
GARDEN_RUNC_RELEASE=v$(get_submodule_ref garden-runc-release)
LOGGREGATOR_RELEASE=v$(get_submodule_ref loggregator-release)
MYSQL_RELEASE=v$(get_submodule_ref cf-mysql-release)
NATS_RELEASE=v$(get_submodule_ref nats-release)
STATSDI_RELEASE=v$(get_submodule_ref statsd-injector-release)
SYSLOG_DRAIN_RELEASE=v$(get_submodule_ref cf-syslog-drain-release)

# And version tags without any prefix
CAPI_RELEASE=$(get_submodule_ref capi-release)
ROUTING_RELEASE=$(get_submodule_ref cf-routing-release routing-release)

# cf-smoke-tests-release -- no tags, manual, clone at least
# nfs-volume-release -- manual, not in deployment

update_submodule capi-release "${CAPI_RELEASE}" src
update_submodule cf-mysql-release "${MYSQL_RELEASE}" src
update_submodule cf-smoke-tests-release "" src
update_submodule cf-syslog-drain-release "${SYSLOG_DRAIN_RELEASE}" src
update_submodule cflinuxfs2-release  "${CFLINUXFS2_RELEASE}"  src
update_submodule diego-release       "${DIEGO_RELEASE}"       src
update_submodule garden-runc-release "${GARDEN_RUNC_RELEASE}" src
update_submodule loggregator-release "${LOGGREGATOR_RELEASE}" src
update_submodule nats-release "${NATS_RELEASE}" src
update_submodule nfs-volume-release "" src
update_submodule routing-release "${ROUTING_RELEASE}" src
update_submodule statsd-injector-release "${STATSDI_RELEASE}" src

# Note: Buildpacks are bumped independently of the core CF, they are
#       our own forks anyway, to support SUSE.
#
# GO_BUILDPACK_RELEASE=$(get_submodule_ref go-buildpack-release)
# BINARY_BUILDPACK_RELEASE=$(get_submodule_ref binary-buildpack-release)
# NODEJS_BUILDPACK_RELEASE=$(get_submodule_ref nodejs-buildpack-release)
# RUBY_BUILDPACK_RELEASE=$(get_submodule_ref ruby-buildpack-release)
# PHP_BUILDPACK_RELEASE=$(get_submodule_ref php-buildpack-release)
# PYTHON_BUILDPACK_RELEASE=$(get_submodule_ref python-buildpack-release)
# STATICFILE_BUILDPACK_RELEASE=$(get_submodule_ref staticfile-buildpack-release)
# JAVA_BUILDPACK_RELEASE=$(get_submodule_ref java-buildpack-release)
#
# update_submodule go-buildpack-release "${GO_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule binary-buildpack-release "${BINARY_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule nodejs-buildpack-release "${NODEJS_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule ruby-buildpack-release "${RUBY_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule php-buildpack-release "${PHP_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule python-buildpack-release "${PYTHON_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule staticfile-buildpack-release "${STATICFILE_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule java-buildpack-release "${JAVA_BUILDPACK_RELEASE}" src/buildpacks

echo
echo
echo "ATTENTION, several releases were __not__ automatically bumped,"
echo "for various reasons. See below."
echo ""
echo "* uaa-release            - see src/uaa-fissile-release"
echo "* cf-acceptance-tests    - see src/scf-helper-release/src/github.com/cloudfoundry/cf-acceptance-tests"
echo "               ATTENTION: Branch tag must match CF version (${RELEASE})."
echo '* cf-smoke-tests-release - no tags, manually match version to commit'
echo '* nfs-volume-release     - no version known, not part of the standard deployment'
echo
echo "For the releases below clones were made, providing a starting point"
echo
echo '* cf-smoke-tests-release'
echo '* nfs-volume-release'
echo
echo

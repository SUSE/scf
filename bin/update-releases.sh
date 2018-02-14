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

CF_RELEASE=$(echo "${VERSION_INFO}" | jq -r .[\"cf-release-commit-sha\"])
DIEGO_RELEASE=v$(echo "${VERSION_INFO}" | jq -r .[\"diego-release-version\"])
CFLINUXFS2_RELEASE=v$(echo "${VERSION_INFO}" | jq -r .[\"cflinuxfs2-release-version\"])
GARDEN_RUNC_RELEASE=v$(echo "${VERSION_INFO}" | jq -r .[\"garden-runc-release-version\"])

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

for release_name in nats-release consul-release loggregator-release capi-release diego-release etcd-release garden-runc-release
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

update_submodule diego-release "${DIEGO_RELEASE}" src
update_submodule cflinuxfs2-release "${CFLINUXFS2_RELEASE}" src
update_submodule garden-runc-release "${GARDEN_RUNC_RELEASE}" src

CF_RELEASE_VERSION_INFO=$(curl --silent "https://api.github.com/repos/cloudfoundry/cf-release/contents/src?ref=${CF_RELEASE}")

echo > ${GIT_ROOT}/_work/CF_RELEASE_VERSION_INFO "${CF_RELEASE_VERSION_INFO}"
echo > ${GIT_ROOT}/_work/SUBMODULE_REFERENCES    ""

get_submodule_ref () {
	version_info=${1}
	release=${2}

	case $release in
	    *-buildpack-*)
		where=$(git -C ${GIT_ROOT}/src/buildpacks/$release remote -v | grep fetch | awk '{ print $2 }' | uniq)
		;;
	    *)
		where=$(git -C ${GIT_ROOT}/src/$release remote -v | grep fetch| awk '{ print $2 }' | uniq)
		;;
	esac

    echo "${release}" = $(echo "${version_info}" | jq -r ".[] | select(.name == \"${release}\") | .sha") '@' $where \
        >> ${GIT_ROOT}/_work/SUBMODULE_REFERENCES

	echo "${version_info}" | jq -r ".[] | select(.name == \"${release}\") | .sha"
}

# Note: Buildpacks are bumped independently of the core CF, they are
#       our own forks anyway, to support SUSE.
#
# GO_BUILDPACK_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" go-buildpack-release)
# BINARY_BUILDPACK_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" binary-buildpack-release)
# NODEJS_BUILDPACK_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" nodejs-buildpack-release)
# RUBY_BUILDPACK_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" ruby-buildpack-release)
# PHP_BUILDPACK_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" php-buildpack-release)
# PYTHON_BUILDPACK_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" python-buildpack-release)
# STATICFILE_BUILDPACK_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" staticfile-buildpack-release)
# JAVA_BUILDPACK_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" java-buildpack-release)

CAPI_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" capi-release)
CONSUL_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" consul-release)
ETCD_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" etcd-release)
LOGGREGATOR_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" loggregator-release)
NATS_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" nats-release)

#CFMYSQL_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" cf-mysql-release)
ROUTING_RELEASE=$(get_submodule_ref "${CF_RELEASE_VERSION_INFO}" routing-release)

# update_submodule go-buildpack-release "${GO_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule binary-buildpack-release "${BINARY_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule nodejs-buildpack-release "${NODEJS_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule ruby-buildpack-release "${RUBY_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule php-buildpack-release "${PHP_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule python-buildpack-release "${PYTHON_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule staticfile-buildpack-release "${STATICFILE_BUILDPACK_RELEASE}" src/buildpacks
# update_submodule java-buildpack-release "${JAVA_BUILDPACK_RELEASE}" src/buildpacks

update_submodule capi-release "${CAPI_RELEASE}" src
update_submodule consul-release "${CONSUL_RELEASE}" src
update_submodule etcd-release "${ETCD_RELEASE}" src
update_submodule loggregator "${LOGGREGATOR_RELEASE}" src
update_submodule nats-release "${NATS_RELEASE}" src
update_submodule routing-release "${ROUTING_RELEASE}" src


update_submodule cf-mysql-release "" src

echo
echo
echo ATTENTION, two releases not automatically bumped, no automatic information available
echo '* cf-mysql - look at the diego release notes'
echo Both have been cloned to ease the operation
echo
echo

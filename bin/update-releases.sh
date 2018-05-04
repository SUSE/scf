#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
    echo "usage: update-versions RELEASE"
    exit
fi

GIT_ROOT=${GIT_ROOT:-$(git rev-parse --show-toplevel)}

RELEASE=${1}

VERSION_INFO=$("${GIT_ROOT}/bin/get-cf-versions.sh" "${RELEASE}")

declare -A MISSING_REASONS=(
    [uaa-release]="see src/uaa-fissile-release"
    [consul-release]="not used"
    [cf-networking-release]="not used"
)

declare -A REMAINING_REASONS=(
    [src/buildpacks/binary-buildpack-release]="buildpacks bumped separately"
    [src/buildpacks/dotnet-core-buildpack-release]="buildpacks bumped separately"
    [src/buildpacks/go-buildpack-release]="buildpacks bumped separately"
    [src/buildpacks/java-buildpack-release]="buildpacks bumped separately"
    [src/buildpacks/nodejs-buildpack-release]="buildpacks bumped separately"
    [src/buildpacks/php-buildpack-release]="buildpacks bumped separately"
    [src/buildpacks/python-buildpack-release]="buildpacks bumped separately"
    [src/buildpacks/ruby-buildpack-release]="buildpacks bumped separately"
    [src/buildpacks/staticfile-buildpack-release]="buildpacks bumped separately"
    [src/cf-opensuse42-release]="stacks bumped separately"
    [src/cf-sle12-release]="stacks bumped separately"
    [src/cf-usb/cf-usb-release]="not upstream"
    [src/scf-helper-release]="not upstream"
    [src/nfs-volume-release]="non-standard"
)

# Save, for debugging
mkdir -p "${GIT_ROOT}/_work"
echo "${VERSION_INFO}" > "${GIT_ROOT}/_work/VERSION_INFO"

# Dump the versions into a bash associative array for looping
declare -A release_versions
while IFS=, read -r release_name release_version ; do
    release_versions[${release_name}]=${release_version}
done < <(echo "${VERSION_INFO}")

# Mapping of release name to path
declare -A release_paths
# paths that are yet to be bumped
declare -A remaining_paths
for dir in ${FISSILE_RELEASE//,/ } ; do
    origin="$(git -C "${dir}" remote get-url origin)"
    name="$(basename "${origin}" .git)"
    release_paths["${name}"]="${dir}"
    # We often fork locally with a cf- prefix
    release_paths["${name#cf-}"]="${dir}"
    # And "routing-release" is for some reason mapped as "cf-routing-release" in the manifest
    release_paths["cf-${name#cf-}"]="${dir}"
    # Track what releases we haven't bumped
    remaining_paths["${dir}"]=yes
done

# Given a release name (as in, upstream repo name), find the desired version
release_ref () {
    local release="${1}"
    echo "${release_versions[${release}]}"
}

# Given a release name (as in, upstream repo name), find the directory
release_dir () {
    echo "${release_paths[${1}]}"
}

declare -a missing_releases

update_submodule () {
    local name="${1}"
    local bold="\e[1m"
    local reset="\e[0m"
    local warn="\e[33m"
    local okay="\e[32m"
    local version="${release_versions[$name]}"
    local path="${release_paths[$name]}"
    local width=16
    if test -z "${path}" ; then
        printf '%b%*s %b%s%b\n' "${warn}" "${width}" "Skipping release" "${bold}" "${name}" "${reset}"
        missing_releases[${#missing_releases[@]}]="${name}"
        return 0
    fi
    unset remaining_paths["${path}"]
    printf "Updating release %b%-*s%b at %b%-*s%b to version %b%s%b\n" \
        "${okay}${bold}" 25 "${name}" "${reset}" \
        "${okay}" 30 "${path#${PWD}/}" "${reset}" \
        "${okay}" "${version}" "${reset}"

    git -C "${path}" fetch --all
    if ! test -d "${path}-clone" ; then
        git clone "${path}" "${path}-clone" --no-checkout
    fi
    git -C "${path}-clone" fetch --all
    if test -z "$(git -C "${path}-clone" tag --list "${version}")" ; then
        # Tag not found, try with a `v` prefix
        version="v${version}"
    fi
    git -C "${path}-clone" checkout "${version}"
    git -C "${path}-clone" submodule update --init --recursive
}

for name in "${!release_versions[@]}" ; do
    update_submodule "${name}"
done

if test "${#missing_releases[@]}" -gt 0 ; then
    echo
    printf "ATTENTION, some releases were missing\n"
    {
        printf "%b%s\t%s\t%s%b\n" "\e[0;1m" "Name" "Version" "Reason" "\e[0m"
        for name in "${missing_releases[@]}" ; do
            printf "%b%s\t%s\t%b\n" "\e[0;0m" \
                "${name}" \
                "${release_versions[${name}]}" \
                "${MISSING_REASONS[${name}]:-\e[31;1mUNKNOWN}\e[0m"
        done | sort 
    } | column -t -s $'\t' | sed 's@^@      @'
fi

if test "${#remaining_paths[@]}" -gt 0 ; then
    echo
    printf "ATTENTION, some releases were \e[1mnot\e[0m automatically bumped\n"
    {
        printf "%b%s\t%s%b\n" "\e[0;1m" "Name" "Reason" "\e[0m"
        for path in "${!remaining_paths[@]}" ; do
            path="${path#${PWD}/}"
            printf "%b%s\t%b\n" "\e[0;0m" \
                "${path}" \
                "${REMAINING_REASONS[${path}]:-\e[31;1mUNKNOWN}\e[0m"
        done | sort
    } | column -t -s $'\t' | sed 's@^@      @'
fi

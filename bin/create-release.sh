#!/bin/bash
set -e

ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../"`

if [[ $# < 2 || -z "$1" || -z "$2" ]]; then
  cat <<HELP
  Usage: create-release.sh <RELEASE_PATH> <RELEASE_NAME>"
  RELEASE_PATH must be relative to the root of hcf-infrastructure
HELP
  exit 1
fi

release_path=$1
release_name=$2


# Deletes all dev releases before creating a new one.
#
# This is because by default fissile will use the latest (based on semver) dev
# release available when working with a BOSH release.
#
# This is undesirable when working with newer releases, then switching back
# to older ones

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::${release_name} start
stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::docker::${release_name} start

# bosh create release calls `git status` (twice), but hcf doesn't need to know if the
# repo is dirty, so stub it out.

# import proxy information, if any, what there is.
# Note, the http:// schema prefix is intentional.
# Most of our bosh releases apparently do not understand the form without it.
proxies=
MO=
for var in http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY ; do
  if test -n "${!var}" ; then

      # Notes
      # - Accept only http and https as schemata. And if there is no
      #   schema, then we add http back in.
      # - Without a port, use the default 80/443 for http/https
      # - Strip trailing slash

      proxyspec=${!var}

      case ${proxyspec} in
	  http://*)
	      pproto=http
	      proxyspec=${proxyspec##http://}
	      ;;
	  https://*)
	      pproto=https
	      proxyspec=${proxyspec##https://}
	      ;;
	  *://*)
	      echo Found unsupported proxy protocol in $proxyspec
	      false
	      ;;
	  *)
	      # No protocol, default to http
	      pproto=http
	      ;;
      esac
      proxyspec=${proxyspec%%/}
      proxies="${proxies} --env ${var}=${pproto}://${proxyspec}"

      # Non-standard work for java/maven. Extract host/port
      # information and reassemble. This code assumes that schema and
      # trailing slash were stripped, see above.

      phost=${proxyspec%%:*}
      pport=${proxyspec##*:}

      if [ "${pport}" == "${proxyspec}" ] ; then
	  # No port found, use protocol-specific default
	  case ${pproto} in
	      https) pport=443 ;;
	      http)  pport=80 ;;
	  esac
      fi

      case ${var} in
	  http_*|HTTP_*)
	  MO="${MO} -Dhttp.proxyHost=${phost} -Dhttp.proxyPort=${pport} -Dhttp.proxyProtocol=${pproto}"
	  ;;
	  https_*|HTTPS_*)
	  MO="${MO} -Dhttps.proxyHost=${phost} -Dhttps.proxyPort=${pport} -Dhttp.proxyProtocol=${pproto}"
	  ;;
      esac
  fi
done

# Notes
# - JAVA_OPTS  - cf-release
# - MAVEN_OPTS - open-autoscaler-release

docker run \
    --interactive \
    --rm \
    --volume ${HOME}/.bosh:/root/.bosh \
    --volume $ROOT/:$ROOT/ \
    --env RBENV_VERSION="${RUBY_VERSION:-2.2.3}" \
    ${proxies} \
    --env MAVEN_OPTS="$MO" \
    --env JAVA_OPTS="$MO" \
    helioncf/hcf-pipeline-ruby-bosh \
    bash -l -c "env | grep -i proxy | sort |sed -e 's/^/PROXY SETUP: /' ; cp $ROOT/bin/dev/fake-git /usr/local/bin/git && rm -rf ${ROOT}/${release_path}/dev_releases && bosh --parallel 10 create release --dir ${ROOT}/${release_path} --force --name ${release_name}"
stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::docker::${release_name} done

# Convert YAML to JSON to escape strings nicely so the commit hashes don't get confused as floats
# The resulting JSON files are able to be loaded as YAML files by the go-yaml library

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::y2j::${release_name} start
find "${ROOT}/${release_path}/dev_releases/${release_name}" -name \*.yml \
    -exec mv {} /tmp/tmp-yaml-to-json \; \
    -exec sh -c "y2j < /tmp/tmp-yaml-to-json > {}" \; \
    -exec rm /tmp/tmp-yaml-to-json \;

stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::y2j::${release_name} done
stampy ${ROOT}/hcf_metrics.csv "${BASH_SOURCE[0]}" create-release::${release_name} done

#!/bin/sh
set -o errexit
set -o nounset

usage() {
	cat <<EOF
$(basename "${0}"): SCF Certificate Generator

  -d <domain>:     Sets the top level domain for the cluster
  -h:              Displays this help message
  -n <namespace>:  Sets namespace, default: 'cf'
  -o <output dir>: Sets output directory, default: \`pwd\`
EOF
}

namespace=cf
out_dir=$(pwd)

while getopts "d:hn:o:" opt; do
  case $opt in
    d)
      domain=${OPTARG}
      ;;
    h)
      usage
      exit
      ;;
    n)
      namespace=${OPTARG}
      ;;
    o)
      if ! test -d "${OPTARG}" ; then
        echo "Invalid -${opt} argument ${OPTARG}, must be a directory" >&2
        exit 1
      fi
      out_dir="$(cd "${OPTARG}" ; pwd)"
      ;;
  esac
done

shift $((OPTIND-1))


if [ -z "${domain:-}" ]
then
  usage
  exit 1
fi

echo Writing results to ${out_dir}

docker run --rm \
	--volume "${out_dir}":/out \
	--env NAMESPACE="${namespace}" \
	--env DOMAIN="${domain}" \
	splatform/cert-generator

echo "uaa-cert-values.yaml and scf-cert-values.yaml written to ${out_dir}"

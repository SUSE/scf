#!/bin/sh
set -e

usage() {
	cat <<EOF
$(basename "${0}"): SCF Certificate Generator

  -h:              Displays this help message
  -n <namespace>:  Sets namespace, default: 'cf'
  -o <output dir>: Sets output directory, default: \`pwd\`
EOF
}

namespace=cf
out_dir=$(pwd)

while getopts "hn:o:" opt; do
  case $opt in
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
      out_dir=${OPTARG}
      ;;
  esac
done

shift $((OPTIND-1))

docker run --rm \
	--volume "${out_dir}":/out \
	--env namespace="${namespace}" \
	splatform/cert-generator

echo "uaa-cert-values.yaml and scf-cert-values.yaml written to ${out_dir}"

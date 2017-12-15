set -e

BP="/var/vcap/packages/nodejs-buildpack/nodejs_buildpack-cached-v1.5.21.zip"
SENTINEL="${BP}.${0##*/}.sentinel"

if [ -f "${SENTINEL}" -o ! -f "${BP}" ]; then
  exit 0
fi

cd $(mktemp -dt nodejs.XXXXXX)

mkdir bin
cat << 'EOF' > bin/detect
#!/usr/bin/env bash
# bin/detect <build-dir>

BP=$(dirname "$(dirname $0)")
if [ -f "$1/package.json" ]; then
  echo "node.js "$(cat "$BP/VERSION")""
  exit 0
fi

exit 1
EOF

chmod +x bin/detect
zip -u "${BP}" bin/detect

touch "${SENTINEL}"

exit 0

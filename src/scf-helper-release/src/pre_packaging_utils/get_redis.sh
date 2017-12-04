set -e -x

REDIS_VERSION=3.2.3

redis_artifact_blob="redis/redis.tar.gz"

echo "Download Redis"

cd ${BUILD_DIR}

if [ ! -f $redis_artifact_blob ]; then
    mkdir -p `dirname $redis_artifact_blob`
	curl -o $redis_artifact_blob -L http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz
fi

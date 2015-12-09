#!/usr/bin/env bash
# © Copyright 2015 Hewlett Packard Enterprise Development LP

gato_status=`docker inspect -f "{{.State.Running}}" hcf-gato 2> /dev/null`

if [[ "$?" == "1" || $gato_status == 'false' ]] ; then
  docker rm --force hcf-gato 2> /dev/null 1> /dev/null
  docker run --interactive --name hcf-gato --entrypoint="bash" --net=hcf -d -v /opt/hcf/etc/gato:/root/.gato helioncf/hcf-gato:${build} -i > /dev/null
fi

case `tty` in
  "not a tty") args="" ;;
  *) args="--tty"
esac

docker exec --interactive $args hcf-gato gato "$@"

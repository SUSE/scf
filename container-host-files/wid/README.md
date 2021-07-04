# SCF workspace in Docker

You can build your own SCF workspace docker image by using:

`
    docker build -t your_org/wid:1.0.0 .
`
<br>
<br>

**NOTICE** <br>
1. You need to run Docker container with **--privileged** parameter to allow start Docker deamon in the Docker container and use volume parameter for inner docker data folder, such as:
`docker run -it --privileged --volume “/root/scf:/scf” --volume “/root/inner_docker_volume:/var/lib/docker” --name test your_org/wid:1.0.0 /bin/bash`
1. You need to execute `service docker start` in container by yourself
1. You need to execute `direnv allow` in your git repo manually
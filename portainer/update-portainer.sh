#!/usr/bin/env bash

echo "Instalation started!"
docker stop portainer
docker rm portainer

echo "Pulling portainer"

docker pull portainer/portainer-ce:latest

echo "Starting portainer"
docker run -d -p 9000:9000 -p 9443:9443 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

echo "Instalation finished!"
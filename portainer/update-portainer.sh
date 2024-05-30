#!/usr/bin/env bash

# Use "latest" as the default version tag if none is provided
VERSION_TAG=${1:-latest}

echo "Installation started!"
docker stop portainer
docker rm portainer

echo "Pulling portainer"

docker pull portainer/portainer-ce:$VERSION_TAG

echo "Starting portainer"
docker run -d -p 9000:9000 -p 9443:9443 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:$VERSION_TAG

echo "Installation finished with version: $VERSION_TAG"

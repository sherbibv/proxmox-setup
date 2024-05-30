#!/usr/bin/env bash

# Prompt the user for the version tag
read -p "Enter the Portainer version tag (default: latest): " VERSION_TAG

# Use "latest" if no input is provided
VERSION_TAG=${VERSION_TAG:-latest}

echo "Installation started!"
docker stop portainer
docker rm portainer

echo "Pulling portainer"

docker pull portainer/portainer-ce:$VERSION_TAG

echo "Starting portainer"
docker run -d -p 9000:9000 -p 9443:9443 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:$VERSION_TAG

echo "Installation finished with version: $VERSION_TAG"

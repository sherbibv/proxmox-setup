#!/usr/bin/env bash

# Function to prompt for the version tag
prompt_version_tag() {
  read -p "Enter the Portainer version tag (default: latest): " VERSION_TAG
  VERSION_TAG=${VERSION_TAG:-latest}
}

# Check if running in an interactive terminal
if [ -t 0 ]; then
  prompt_version_tag
else
  # If not interactive, force it to be
  echo "This script needs to run interactively to get user input."
  exec /bin/bash -i -c "$(declare -f prompt_version_tag); prompt_version_tag; $(<${BASH_SOURCE[0]})"
  exit
fi

echo "Installation started!"
docker stop portainer
docker rm portainer

echo "Pulling portainer"

docker pull portainer/portainer-ce:$VERSION_TAG

echo "Starting portainer"
docker run -d -p 9000:9000 -p 9443:9443 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:$VERSION_TAG

echo "Installation finished with version: $VERSION_TAG"

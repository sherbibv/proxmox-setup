#!/usr/bin/env bash

VERSION=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
echo "Installing Code-Server v${VERSION}"

curl -fOL https://github.com/coder/code-server/releases/download/v$VERSION/code-server_${VERSION}_amd64.deb &>/dev/null

sudo dpkg -i code-server_${VERSION}_amd64.deb &>/dev/null
rm -rf code-server_${VERSION}_amd64.deb

systemctl enable --now code-server@$USER &>/dev/null

systemctl restart code-server@$USER

echo "Instalation finished!"
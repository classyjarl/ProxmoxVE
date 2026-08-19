#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: ClassyJarl
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/chaptarr/chaptarr

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Runtime Dependencies"
$STD apt-get install -y \
  curl sudo mc ca-certificates gnupg jq sqlite3
msg_ok "Installed Runtime Dependencies"

msg_info "Installing .NET 10 Runtime"
curl -fsSL https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb
$STD dpkg -i /tmp/packages-microsoft-prod.deb
rm -f /tmp/packages-microsoft-prod.deb
$STD apt-get update
$STD apt-get install -y aspnetcore-runtime-10.0
msg_ok "Installed .NET 10 Runtime"

msg_info "Installing Build Toolchain"
$STD apt-get install -y git dotnet-sdk-10.0
$STD bash -c "curl -fsSL https://deb.nodesource.com/setup_20.x | bash -"
$STD apt-get install -y nodejs
$STD npm install -g yarn
msg_ok "Installed Build Toolchain"

msg_info "Cloning Chaptarr Source"
rm -rf /opt/chaptarr-src
cd /opt
$STD git clone https://github.com/chaptarr/chaptarr.git chaptarr-src
cd /opt/chaptarr-src
# Try latest tag from git itself; fall back to HEAD if no tags exist
RELEASE=$(git tag -l | sort -V | tail -1)
if [[ -n "$RELEASE" ]]; then
  $STD git checkout "$RELEASE"
else
  RELEASE=$(git rev-parse --short HEAD)
fi
msg_ok "Cloned Chaptarr Source ($RELEASE)"

msg_info "Building Backend (dotnet — this may take several minutes)"
cd /opt/chaptarr-src
$STD dotnet publish src/NzbDrone.Console/Chaptarr.Console.csproj \
  -c Release -f net10.0 -o _output/publish
msg_ok "Built Backend"

msg_info "Building Frontend (yarn)"
cd /opt/chaptarr-src
$STD yarn install --frozen-lockfile
$STD yarn build
cp -r _output/UI _output/publish/UI
msg_ok "Built Frontend"

msg_info "Installing Application"
mv /opt/chaptarr-src/_output/publish /opt/chaptarr
mkdir -p /var/lib/chaptarr
chmod 755 /opt/chaptarr
echo "$RELEASE" >/opt/${APP}_version.txt
msg_ok "Installed Application"

msg_info "Creating Service"
cat >/etc/systemd/system/chaptarr.service <<EOF
[Unit]
Description=Chaptarr
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/chaptarr
ExecStart=/usr/bin/dotnet /opt/chaptarr/Chaptarr.dll -data=/var/lib/chaptarr
Restart=on-failure
RestartSec=5
User=root
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now chaptarr.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y purge --auto-remove \
  dotnet-sdk-10.0 nodejs git
rm -rf /opt/chaptarr-src \
       /root/.nuget /root/.dotnet /root/.cache \
       /root/.npm /root/.yarn /tmp/*
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

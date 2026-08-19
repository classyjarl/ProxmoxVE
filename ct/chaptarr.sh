#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: ClassyJarl
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/chaptarr/chaptarr

APP="Chaptarr"
var_tags="${var_tags:-arr;media}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-6}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/chaptarr ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Stopping $APP"
  systemctl stop chaptarr
  msg_ok "Stopped $APP"

  msg_info "Installing Build Toolchain"
  $STD apt-get install -y dotnet-sdk-10.0 nodejs
  $STD npm install -g yarn
  msg_ok "Installed Build Toolchain"

  msg_info "Rebuilding $APP"
  cd /opt/chaptarr-src
  $STD git fetch --all --prune
  $STD git reset --hard origin/main
  RELEASE=$(git rev-parse --short HEAD)
  rm -rf _output
  $STD dotnet publish src/NzbDrone.Console/Chaptarr.Console.csproj -c Release -f net10.0 -o _output/publish
  $STD yarn install --frozen-lockfile
  $STD yarn build
  cp -r _output/UI _output/publish/UI
  rm -rf /opt/chaptarr
  mv _output/publish /opt/chaptarr
  echo "$RELEASE" >/opt/${APP}_version.txt
  msg_ok "Rebuilt $APP $RELEASE"

  msg_info "Removing Build Toolchain"
  $STD apt-get -y purge --auto-remove dotnet-sdk-10.0 nodejs
  rm -rf /root/.nuget /root/.dotnet /root/.cache/yarn /root/.npm /opt/chaptarr-src/node_modules
  msg_ok "Removed Build Toolchain"

  msg_info "Starting $APP"
  systemctl start chaptarr
  msg_ok "Started $APP"

  msg_ok "Update Complete"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8686${CL}"

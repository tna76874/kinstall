#!/bin/bash

DEB="https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"
DIR="/tmp/tv"

update_system() {
    sudo apt update && sudo apt upgrade -y || sudo apt --fix-broken install && sudo apt update && sudo apt upgrade -y
}

# install teamviewer
install_tv() {
    mkdir -p "$DIR"
    cd "$DIR"

    wget -P "$DIR" "$DEB"

    sudo dpkg --install "$DIR/teamviewer_amd64.deb"
}

# start teamviewer daemon and optionally set PW
start_teamviewer_daemon() {
  # cleanup running teamviewer
  sudo killall /opt/teamviewer/tv_bin/TeamViewer >/dev/null 2>&1 || :
  # ensure systemctl symlink and start teamviewer daemon
  sudo teamviewer daemon enable >/dev/null 2>&1
  sudo systemctl start teamviewerd.service >/dev/null 2>&1
  sudo teamviewer --daemon start >/dev/null 2>&1
  # wait a bit until teamviewer daemon is started
  sleep 5
  # ensure license is accepted
  sudo teamviewer license accept >/dev/null 2>&1
}

install_tv && start_teamviewer_daemon
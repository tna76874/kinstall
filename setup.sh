#!/bin/bash

DEB="https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"
DIR="/tmp/tv"

mkdir -p "$DIR"
cd "$DIR"

wget -P "$DIR" "$DEB"

sudo dpkg --install "$DIR/teamviewer_amd64.deb"

/usr/bin/teamviewer >/dev/null 2>&1 &
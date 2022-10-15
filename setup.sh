#!/bin/bash

DEB="https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"
DIR="/tmp/tv"

mkdir -p "$DIR"
cd "$DIR"

sudo dpkg --install "$DIR/teamviewer_amd64.deb"

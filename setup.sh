#!/bin/bash

# only run script as root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi

# define variables
SSHKEYS="https://github.com/tna76874.keys"
JITSISERVER="https://www.kuketz-meet.de"
RANDID=`openssl rand -hex 16`
DEB="https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"
DEBCL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
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

# install cloudflared
install_cf() {
    mkdir -p "$DIR"
    cd "$DIR"

    wget -P "$DIR" "$DEBCL"

    sudo dpkg --install "$DIR/cloudflared-linux-amd64.deb"
}

update_system
sudo apt update && sudo apt install screen libminizip1 pwgen -y
install_tv
install_cf

############################

# define functions
## countdown function
countdown() {
    secs=$(( 10 ))
    while [ $secs -gt 0 ]; do
    echo -ne "(CTRL+C to abort)      $secs\033[0K\r"
    sleep 1
    : $((secs--))
    done
}

## simple yes or no function for promts
function confirm() {
    # call with a prompt string or use a default
    read -r -p "$@"" [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

function gotify_send() {
    export CURL_EXE="/usr/bin/curl"
    export MESSAGE=${1:-"Message"}
    export TOPIC=${2:-"Notification"}
    export PRIORITY=${3:-"8"}

    "$CURL_EXE" -k  -X POST "https://push.hilberg.eu/message?token=AsDui-AXoaQMcCD" -F "title=$TOPIC [SUPPORT] " -F "message=$MESSAGE" -F "priority=$PRIORITY" >/dev/null 2>&1
}

# start teamviewer daemon and optionally set PW
start_teamviewer_daemon() {
  # cleanup running teamviewer
  sudo killall /opt/teamviewer/tv_bin/TeamViewer >/dev/null 2>&1 || :
  # ensure systemctl symlink and start teamviewer daemon
  sudo teamviewer daemon enable >/dev/null 2>&1
  sudo systemctl start teamviewerd.service >/dev/null 2>&1
  sudo teamviewer --daemon start >/dev/null 2>&1
  # ensure license is accepted
  sudo teamviewer license accept >/dev/null 2>&1
}

set_teamviewer_pw() {
  # generate random password and get teamviewer-id
  TVPASSWORD=`openssl rand -base64 8`
  TVID=`sudo teamviewer --info | grep "TeamViewer ID" | cut -d ':' -f2 | xargs | tr -dc '[:alnum:]\n\r' |  sed 's/0m//'`
  # set pw and print credentials
  sudo teamviewer passwd $TVPASSWORD >/dev/null 2>&1 || :
  # Sending access data
  gotify_send "TeamViewer: $TVID $TVPASSWORD" "TeamViewer Request"
  # Echo Access Data
  echo -e "ID: $TVID\nPW: $TVPASSWORD"
}

## starting teamviewer and set random password
function start_team_viewer() {
  start_teamviewer_daemon || :
  set_teamviewer_pw
}

## the screen session dump with the cloudflared tunnel gets parsed every second to find the cloudflared tunnel URL
function check_for_url() {
    export TURL=""
    touch /tmp/ctun
    while [[ $TURL == "" ]]; do
    export TURL="$(cat /tmp/ctun | grep -v 'developers.cloudflare.com' | grep 'https' | cut -d '|' -f2 | sed -e 's/^[[:space:]]*//' | sed 's/https:\/\///')"
    sleep 1
    done
}

## defining cleanup function
function cleanup()
{
    # deleting all screen sessions with the name 'cloudflare_tunnel'
    screen -ls | awk -vFS='\t|[.]' '/cloudflare_tunnel/ {system("screen -S "$2" -X quit")}'
    # ensure all cloudflared tunnels are terminated
    sudo killall cloudflared >/dev/null 2>&1 ||:
    # ensure teamviewer ist shutdown
    sudo teamviewer daemon disable >/dev/null 2>&1 ||:
    sudo killall /opt/teamviewer/tv_bin/TeamViewer >/dev/null 2>&1 || :
    sudo systemctl stop teamviewerd.service >/dev/null 2>&1 || :
    sudo systemctl disable teamviewerd.service >/dev/null 2>&1 || :
    # ensure temporary authorized keys are deleted
    rm -f /root/.ssh/authorized_keys_temp
    # cleanup temporary logfile from screen session dump
    rm -f /tmp/ctun
    # print message
    echo -e "\e[32mSystem access cleaned up.\e[0m"
}

function start_ssh_tunnel() {
    # ensure .ssh directory
    mkdir -p /root/.ssh

    # Import temporary ssh keys
    wget -q -O /root/.ssh/authorized_keys_temp "$SSHKEYS" &> /dev/null

    # ensure permission and
    chown -R root:root /root/.ssh
    chmod 644 /root/.ssh/authorized_keys_temp

    # starting cloudflare tunnel in a screen session
    sysctl -w net.core.rmem_max=2500000 >/dev/null 2>&1
    screen -S cloudflare_tunnel -L -Logfile /tmp/ctun -d -m /usr/bin/cloudflared tunnel --url ssh://localhost:22

    # getting URL from cloudflared and send via gotify
    check_for_url
    /usr/local/bin/gotify "cssh root@$TURL $JITSISERVER/$RANDID" "SSH Tunnel Request"

    echo -e "Support request ssh channel is initalized.\n\nOpen in Browser for Meeting:\n$JITSISERVER/$RANDID\n\nAccess Endpoint for Support:\n$TURL\n\n"
}

######################################

# printing disclaimer
echo -e "\e[31mOpening a support request will grant $SSHKEYS temporary full system access as long as this terminal is open. A TeamViewer session will be started. A push message containing the ssh support url and the TeamViewer credentials will be send to support.\nOnly proceed if you absolutely trust the listed person!\e[0m\n"
countdown

# Proceed with support request
echo -e "Please wait until the request tunnel is initiated. [Exit with CTRL+C]"

# Make sure access is temporary - as long as script runs
## trap with cleanup function in case there is an error in the script
trap cleanup EXIT

# ensure no old tunnel sessions open
cleanup

# open ssh tunnel and start teamviewer
start_ssh_tunnel &
start_team_viewer &

wait

echo -e "\n\n"

# wait until tunnel gets closed
read -r -p "Type ENTER to exit tunnel" response

# run cleanup
cleanup
sleep 2

# delete trap
trap "" EXIT
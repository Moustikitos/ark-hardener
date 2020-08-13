#!/bin/bash

VENVDIR="$HOME/.local/share/pyrex/venv"
GITREPO="https://github.com/Moustikitos/ark-hardener.git"

clear

if [ $# = 0 ]; then
    B="master"
else
    B=$1
fi
echo "github branch to use : $B"

echo
echo installing system dependencies
echo ==============================
sudo apt-get -qq install ipset iptables-persistent
sudo apt-get -qq install python3 python3-dev python3-setuptools python3-pip
sudo apt-get -qq install virtualenv
echo "done"

echo
echo downloading ark-hardener package
echo ================================

cd ~
if (git clone --branch $B $GITREPO) then
    echo "package cloned !"
else
    echo "package already cloned !"
fi

cd ~/ark-hardener
git reset --hard
git fetch --all
if [ "$B" == "master" ]; then
    git checkout $B -f
else
    git checkout tags/$B -f
fi
git pull

echo "done"

echo
echo creating virtual environment
echo ============================

if [ -d $VENVDIR ]; then
    read -p "remove previous virtual environement ? [y/N]> " r
    case $r in
    y) rm -rf $VENVDIR;;
    Y) rm -rf $VENVDIR;;
    *) echo -e "previous virtual environement keeped";;
    esac
fi

if [ ! -d $VENVDIR ]; then
    TARGET="$(which python3)"
    mkdir $VENVDIR -p
    virtualenv -p $TARGET $VENVDIR -q
fi

echo "done"

echo
echo installing python dependencies
echo ==============================
. $VENVDIR/bin/activate
export PYTHONPATH=${HOME}/ark-hardener
cd ~/ark-hardener
pip install -r requirements.txt -q
echo "done"

echo
echo creating ipset service
echo ======================

cat > $HOME/save-ipset-rules.service << EOF
[Unit]
Description=ipset persistent rule service
Before=netfilter-persistent.service
ConditionFileNotEmpty=/etc/iptables/ipset

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ipset -exist -file /etc/iptables/ipset restore
ExecStop=/sbin/ipset -file /etc/iptables/ipset save

[Install]
WantedBy=multi-user.target
EOF

sudo ipset create blacklist hash:ip hashsize 4096

sudo ipset -file /etc/iptables/ipset save
sudo mv --force $HOME/save-ipset-rules.service /etc/systemd/system

sudo iptables -I INPUT -m set --match-set blacklist src -j DROP
sudo iptables -I FORWARD -m set --match-set blacklist src -j DROP

echo "done"

echo
echo creating pyrex service
echo ======================

cat > $HOME/pyrex.service << EOF
[Unit]
Description=pyrex service to harden ark forger
After=network.target

[Service]
User=${USER}
WorkingDirectory=${HOME}/.local/share/pyrex
Environment=PYTHONPATH=${HOME}/ark-hardener
ExecStart=${HOME}/.local/share/pyrex/venv/bin/python -c "from pyrex import service; service.start(60)"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo mv --force $HOME/pyrex.service /etc/systemd/system

echo "done"


echo
echo starting services
echo =================

sudo systemctl daemon-reload
sudo systemctl start save-ipset-rules.service
sudo systemctl start pyrex.service
sudo systemctl enable save-ipset-rules.service
sudo systemctl enable pyrex.service

echo "done"

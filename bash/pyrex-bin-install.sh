#!/bin/bash

VENVDIR="$HOME/.local/share/pyrex/venv"
RAWGIT="https://raw.githubusercontent.com/Moustikitos/ark-hardener/master"
IS_PY64="$(python -c 'import sys;print(sys.maxsize==2**64//2-1)')"

clear

echo
echo installing system dependencies
echo ==============================
sudo apt-get -qq install ipset iptables-persistent
sudo apt-get -qq install python3 python3-dev python3-setuptools python3-pip
sudo apt-get -qq install virtualenv
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
Environment=PYTHONPATH=${HOME}/.local/share
ExecStart=${HOME}/.local/share/pyrex/venv/bin/python -c "from pyrex import service; service.start(60)"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo mv --force $HOME/pyrex.service /etc/systemd/system

echo "done"

echo
echo installing python dependencies
echo ==============================
. $VENVDIR/bin/activate
wget -q ${RAWGIT}/requirements.txt -P ${HOME}
pip install -r ${HOME}/requirements.txt -q
rm ${HOME}/requirements.txt
echo "done"

PY3="$(python3 -V)"
MINOR="${PY3[@]: 9:1}"
if [ $IS_PY64 = 'True' ]; then
  MACHINE="x64"
else
  MACHINE="x32"
fi
wget -q ${RAWGIT}/bin/pyrex.${MACHINE}.cpython-3${MINOR}.so -P ${HOME}/.local/share
mv ${HOME}/.local/share/pyrex.${MACHINE}.cpython-3${MINOR}.so ${HOME}/.local/share/pyrex.so
chmod 777 ${HOME}/.local/share/pyrex

export PYTHONPATH=${HOME}/.local/share
python -c "import pyrex; pyrex.getP2pPort()"

echo
echo starting services
echo =================

sudo systemctl daemon-reload
sudo systemctl start save-ipset-rules.service
sudo systemctl start pyrex.service
sudo systemctl enable save-ipset-rules.service
sudo systemctl enable pyrex.service

echo "done"

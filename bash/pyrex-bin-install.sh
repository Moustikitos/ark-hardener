#!/bin/bash

VENVDIR=${HOME}/.local/share/pyrex/venv
RAWGIT="https://raw.githubusercontent.com/Moustikitos/ark-hardener/master"
TARGET="$(which python3)"

clear
echo installing system dependencies
echo ==============================
sudo apt-get -q install ipset iptables-persistent net-tools
# install python3 if not found
if [ ! -f  $TARGET ]; then
	sudo apt-get -q install python3 python3-dev python3-setuptools python3-pip
fi

echo "done"

echo
echo creating virtual environment
echo ============================
$TARGET -m pip install --user --upgrade pip
$TARGET -m pip install --user virtualenv

if [ -d $VENVDIR ]; then
    read -p "remove previous virtual environement ? [y/N]> " R
    case $R in
    y) rm -rf $VENVDIR;;
    Y) rm -rf $VENVDIR;;
    *) echo -e "previous virtual environement keeped";;
    esac
fi

if [ ! -d $VENVDIR ]; then
    mkdir $VENVDIR -p
    $TARGET -m venv $VENVDIR
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
# from there: $TARGET --> python

# install dependencies
wget -q ${RAWGIT}/requirements.txt -P ${HOME}
python -m pip install -r ${HOME}/requirements.txt
rm ${HOME}/requirements.txt

# choose and install the right binary
PY3="$(python -V)"
MINOR="${PY3[@]: 9:1}"
IS_PY64="$(python -c 'import sys; print(sys.maxsize==2**64//2-1)')"

if [ $IS_PY64 = 'True' ]; then
  MACHINE="x64"
else
  MACHINE="x32"
fi

wget -q ${RAWGIT}/bin/pyrex.${MACHINE}.cpython-3${MINOR}.so -P ${HOME}/.local/share
mv --force ${HOME}/.local/share/pyrex.${MACHINE}.cpython-3${MINOR}.so ${HOME}/.local/share/pyrex.so

# initialize pyrex
export PYTHONPATH=${HOME}/.local/share
chmod 777 ${HOME}/.local/share/pyrex
python -c "import pyrex; pyrex.getP2pPort()"

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

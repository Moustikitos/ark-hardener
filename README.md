# `pyrex`

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://raw.githubusercontent.com/Moustikitos/ark-hardener/master/LICENSE)

This package aims to harden [ark](https://ark.io) nodes against ddos attacks using
[`iptables`](https://manpages.ubuntu.com/manpages/bionic/en/man8/iptables.8.html)
and [`ipset`](https://manpages.ubuntu.com/manpages/bionic/man8/ipset.8.html).

## Support this project

  * [X] Send &#1126; to `AUahWfkfr5J4tYakugRbfow7RWVTK35GPW`
  * [X] Vote `arky` on [Ark blockchain](https://explorer.ark.io) and [earn &#1126; weekly](http://dpos.arky-delegate.info/arky)

## Install

```bash
bash <(curl -s https://raw.githubusercontent.com/Moustikitos/ark-hardener/master/bash/pyrex-install.sh)
```

## Configure

First activate virtual environement and run python:
```bash
$ . ~/.local/share/pyrex/venv/bin/activate
$ python
```

Then all is available from `rules` and `nets` modules:
```python
>>> from pyrex import rules, nets
```

Configuration is stored in `~/ark-hardener/pyrex/.json/config.json`.

### Add/delete trusted ip

You may want to grant specific ip address. It is usefull if a relay have to reach hardened node (the one runing `pyrex`) behind a TOR network.

```python
>>> # add ip in trusted list
>>> nets.add_trusted_ip("242.124.32.12")
>>> # delete localhost ip from trusted list
>>> nets.drop_trusted_ip("242.124.32.12")
```

### Enable [ipinfo](https://ipinfo.io) API (not mandatory)

Register your token from your `ipinfo` dashbord.

```python
>>> nets.register_ipinfo_token("azndbUTJzdsqdi"))
```

### Add/delete a rule

A rule is a piece of python code executed on either ip address as string or ip info if `ipinfo` enabled. The piece of code have to return `True` to avoid ban.

```python
>>> # add rule : every ipinfo containing "tor" are granted
>>> rules.register(
...    "TOR", # name you want to give to the rule
...    lambda ip_or_info:
...        ("tor" in ip_or_info.get("hostname", ""))
...        if isinstance(ip_or_info, dict) else False
... )
>>> # delete TOR rule
>>> rules.drop("TOR")
```

## Use

Even if `pyrex` is providen as a python package, it runs in background as a system service. Because `sudo` user is needed by `pyrex` to add ip in `ipset` blacklist, `sudo` command have to run witout password prompt.

To do so:

```bash
$ sudo visudo
```

then add this line at the end of the file:

```
<username> ALL=(ALL) NOPASSWD:ALL
```

where `<username>` is the user running `pyrex` service, then close (`CTRL+X`) and save (`Y`).

### Start/restart/stop `pyrex` service

```bash
$ sudo systemctl start pyrex
$ sudo systemctl restart pyrex
$ sudo systemctl stop pyrex
```

### Check `pyrex` logs

```bash
$ sudo journalctl -u pyrex -ef
```

### Extract `pyrex` logs

```bash
$ sudo journalctl -u pyrex --since "1 day ago" > ~/pyrex.log
```

### Launch `pyrex` on reboot

```bash
$ sudo systemctl enable pyrex
```

### More ?

Check [`systemd` man pages](https://man7.org/linux/man-pages/man1/systemd.1.html)
and [`journalctl` man pages](https://man7.org/linux/man-pages/man1/journalctl.1.html).

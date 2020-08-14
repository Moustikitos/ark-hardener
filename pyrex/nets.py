# coding:utf-8

import subprocess
import random
import sys

from pyrex import CONFIG, dumpJson
# $ pip install git+http://github.com/Moustikitos/micro-io#egg=uio
from uio import req


TRUSTED = set(["127.0.0.1"])


def get_trusted():
    # https://raw.githubusercontent.com/ARKEcosystem/peers/master/mainnet.json
    global TRUSTED
    try:
        TRUSTED |= set([
            peer["ip"] for peer in req.GET.ARKEcosystem.peers.master(
                "mainnet.json", peer="https://raw.githubusercontent.com"
            )
        ])
    except Exception:
        pass
    finally:
        TRUSTED |= set(["127.0.0.1"] + CONFIG.get("trusted", []))


def get_foreign_ip(*ports):
    col = 2 if "win" in sys.platform else 4
    output = subprocess.check_output("netstat -nt".split())
    output = output.decode("latin-1") if isinstance(output, bytes) else output
    foreign_ip = [
        d[col] for d in [
            li.split() for li in output.split("\n")
        ] if len(d) > col
    ]

    for ip in foreign_ip:
        ok = False
        for port in ports:
            if ip.endswith(":%s" % port):
                ok = True
                break
        if ok:
            yield(ip.split(":")[0])


def get_peers(seeds=CONFIG.get("seeds", ["https://explorer.ark.io:8443"])):
    seed = random.choice(seeds)
    if not req.connect(seed):
        raise Exception("connection with %s failed!" % seeds)
    else:
        r = req.GET.api.peers()
        peers = r.get("data", [])
        for i in range(2, r.get("meta", {}).get('pageCount', 1) + 1, 1):
            r = req.GET.api.peers(page=i)
            peers.extend(r.get("data", []))

        for peer in peers:
            yield(peer["ip"])


def get_suspicious_ip():
    return (
        set(get_foreign_ip(CONFIG.get("p2p port", 4001)))
        - set(get_peers()) - TRUSTED
    )


def register_ipinfo_token(token):
    CONFIG["ipinfo token"] = token
    dumpJson(CONFIG, "config.json")


def register_trusted_ip(ip):
    global TRUSTED
    CONFIG["trusted"] = list(set(CONFIG.get("trusted", []) + [ip]))
    TRUSTED.add(ip)
    dumpJson(CONFIG, "config.json")


def drop_trusted_ip(ip):
    global TRUSTED
    trusted = CONFIG.get("trusted", [])
    if ip in trusted:
        trusted.remove(ip)
        CONFIG["trusted"] = trusted
        TRUSTED.remove(ip)
        dumpJson(CONFIG, "config.json")

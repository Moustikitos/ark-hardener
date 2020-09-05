# coding:utf-8

import logging
import json
import sys
import os
import io

PY3 = True if sys.version_info[0] >= 3 else False
ROOT = os.path.abspath(os.path.dirname(__file__))
JSON = os.path.abspath(os.path.join(ROOT, ".json"))
try:
    HOME = os.path.join(os.environ["HOMEDRIVE"], os.environ["HOMEPATH"])
except Exception:
    HOME = os.environ.get("HOME", ROOT)
finally:
    HOME = os.path.normpath(HOME)

__path__.append(os.path.normpath(os.path.join(ROOT, ".hidden")))


def loadEnv(pathname):
    with io.open(pathname, "r") as environ:
        lines = [line.strip() for line in environ.read().split("\n")]
    result = {}
    for line in [li for li in lines if li != ""]:
        key, value = [e.strip() for e in line.split("=")]
        try:
            result[key] = int(value)
        except Exception:
            result[key] = value
    return result


def loadJson(name, folder=None, reload=False):
    filename = os.path.join(JSON if not folder else folder, name)
    if os.path.exists(filename):
        with io.open(filename) as in_:
            data = json.load(in_)
    else:
        data = {}
    return data


def dumpJson(data, name, folder=None):
    filename = os.path.join(JSON if not folder else folder, name)
    try:
        os.makedirs(os.path.dirname(filename))
    except OSError:
        pass
    with io.open(filename, "w" if PY3 else "wb") as out:
        json.dump(data, out, indent=4)


def chooseItem(msg, *elem):
    n = len(elem)
    if n > 1:
        sys.stdout.write(msg + "\n")
        for i in range(n):
            sys.stdout.write("    %d - %s\n" % (i + 1, elem[i]))
        sys.stdout.write("    0 - quit\n")
        i = -1
        while i < 0 or i > n:
            try:
                i = input("Choose an item: [1-%d]> " % n)
                i = int(i)
            except ValueError:
                i = -1
            except KeyboardInterrupt:
                sys.stdout.write("\n")
                sys.stdout.flush()
                return False
        if i == 0:
            return None
        return elem[i - 1]
    elif n == 1:
        return elem[0]
    else:
        sys.stdout.write("Nothing to choose...\n")
        return False


CONFIG = loadJson("config.json")


def getP2pPort():
    ark_core = os.path.join(HOME, ".config", "ark-core")
    if os.path.isdir(ark_core) and not CONFIG.get("p2p port", False):
        networks = [
            name for name in os.listdir(ark_core)
            if os.path.isdir(os.path.join(ark_core, name))
        ]

        network = chooseItem("Select network >", *networks)
        if network:
            CONFIG["p2p port"] = loadEnv(
                os.path.join(ark_core, network, ".env")
            ).get("CORE_P2P_PORT", 4001)
            dumpJson(CONFIG, "config.json")

    return CONFIG.get("p2p port", 4001)


def setLogLevel(level, logger=None):
    CONFIG["log level"] = level
    dumpJson(CONFIG, "config.json")
    if logger is not None:
        logger.setLevel(level)

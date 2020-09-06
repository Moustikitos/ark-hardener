# coding:utf-8

import binascii
import marshal
import types

from pyrex import loadJson, dumpJson, CONFIG, PY3


def _func(name, code):
    code = binascii.unhexlify(code)
    code = marshal.loads(
        code if isinstance(code, bytes) else code.encode("utf-8")
    )
    return types.FunctionType(code, globals())


def register(name, obj):
    code = binascii.hexlify(
        marshal.dumps(
            getattr(obj, "__code__" if PY3 else "func_code")
        )
    )

    CONFIG["rules"] = dict(
        CONFIG.get("rules", {}),
        **{name: code.decode("utf-8") if isinstance(code, bytes) else code}
    )

    dumpJson(CONFIG, "config.json")


def drop(name):
    rule = CONFIG.get("rules", {}).pop(name, False)
    dumpJson(CONFIG, "config.json")
    return rule


def load():
    CONFIG.update(loadJson("config.json"))
    return dict([(n, _func(n, m)) for n, m in CONFIG.get("rules", {}).items()])


# def get_ip(name, action):
#     s = sqlite3.connect(name)
#     s.row_factory = sqlite3.Row
#     req = s.execute("SELECT * FROM iptable WHERE action=?;", (action, ))
#     return set([r["ip"] for r in req.fetchall()])

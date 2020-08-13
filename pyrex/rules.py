# coding:utf-8

import binascii
import marshal
import types

from pyrex import dumpJson, CONFIG, PY3


def _func(name, code):
    code = binascii.unhexlify(code)
    code = marshal.loads(
        code if isinstance(code, bytes) else code.encode("utf-8")
    )
    return types.FunctionType(code, globals())


def add(name, obj):
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
    return dict([(n, _func(n, m)) for n, m in CONFIG.get("rules", {}).items()])

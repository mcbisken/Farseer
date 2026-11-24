"""Kör Farseer i Lua 5.1 (lupa) mot wowmock.lua och kör tests.lua.

Användning:  python tests/run_tests.py   (kräver: pip install lupa)
"""
import os
import sys

import lupa.lua51 as lua51

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.join(os.path.dirname(HERE), "Farseer")


def toc_files():
    files = []
    with open(os.path.join(ADDON, "Farseer.toc"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                files.append(line.replace("\\", "/"))
    return files


def main():
    rt = lua51.LuaRuntime(unpack_returned_tuples=True)
    g = rt.globals()

    def run_file(path, *args):
        with open(path, encoding="utf-8") as f:
            src = f.read()
        chunk = rt.eval("function(src, name) local f, err = loadstring(src, name); if not f then error(err) end; return f end")(
            src, "@" + os.path.relpath(path, os.path.dirname(HERE)))
        return chunk(*args)

    run_file(os.path.join(HERE, "wowmock.lua"))
    # Fånga globala skrivningar från addonet (oavsiktliga globaler = buggar)
    rt.execute('''
        GLOBAL_WRITES = {}
        setmetatable(_G, { __newindex = function(t, k, v) GLOBAL_WRITES[k] = true; rawset(t, k, v) end })
    ''')
    ns = rt.table()
    g.FARSEER_NS = ns
    for rel in toc_files():
        run_file(os.path.join(ADDON, rel), "Farseer", ns)
    rt.execute('MOCK.fire("ADDON_LOADED", "Farseer"); MOCK.fire("PLAYER_LOGIN"); MOCK.fire("PLAYER_ENTERING_WORLD"); MOCK.runTimers()')
    errs = list(g.MOCK.errors.values())
    if errs:
        print("Fel vid inloggning:")
        for e in errs:
            print("  ", e)
    run_file(os.path.join(HERE, "tests.lua"))
    run_file(os.path.join(HERE, "tests_v11.lua"))
    run_file(os.path.join(HERE, "tests_v12.lua"))
    rt.execute("FINISH()")
    allowed = ("FarseerDB", "FarseerCharDB", "SLASH_FARSEER1", "SLASH_FARSEER2", "Farseer_OnCompartmentClick",
               "Farseer_OnCompartmentEnter", "Farseer_OnCompartmentLeave", "RESULTS", "FARSEER_NS", "TEST", "CHECK", "FINISH", "C_EncodingUtil")
    leaks = sorted(k for k in g.GLOBAL_WRITES.keys()
                   if not str(k).startswith(("BINDING_", "Farseer")) and str(k) not in allowed)
    if leaks:
        print("Oavsiktliga globaler:", ", ".join(map(str, leaks)))
    res = g.RESULTS
    for line in res.lines.values():
        print(line)
    return 1 if (res.fail or errs or leaks) else 0


if __name__ == "__main__":
    sys.exit(main())

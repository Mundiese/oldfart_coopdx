import argparse
import json
import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(os.path.dirname(HERE))
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)
from studio.core import loader
from studio.exchange import gltf
def main(argv):
    ap = argparse.ArgumentParser(prog="python3 tools/studio/exchange",
                                 description="glTF 2.0 out to Blender and back.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("export", help="a map -> .glb / .gltf")
    e.add_argument("map", help="venue:<key>, a mapgen --out folder or a layout .json")
    e.add_argument("out")
    e.add_argument("--scale", type=float, default=0.01,
                   help="metres per game unit (0.01 = Fast64's default 100)")
    i = sub.add_parser("import", help="a .glb / .gltf edited in Blender -> a layout")
    i.add_argument("file")
    i.add_argument("layout", help="the layout it was exported from (keeps everything else)")
    i.add_argument("--out", help="write the new layout here (default: print the report only)")
    a = ap.parse_args(argv)
    if a.cmd == "export":
        got = loader.load(a.map)
        gltf.export(got.pieces, got.markers, a.out, a.scale,
                    name=got.meta.get("name") or os.path.basename(a.map))
        print("glTF: %d pieces, %d markers -> %s" % (len(got.pieces), len(got.markers), a.out))
        return 0
    with open(a.layout, encoding="utf-8") as f:
        layout = json.load(f)
    imp = gltf.read(a.file)
    new, lines = gltf.merge(layout, imp)
    for line in lines:
        print(line)
    if a.out:
        with open(a.out, "w", encoding="utf-8") as f:
            json.dump(new, f, indent=1, sort_keys=True)
        print("wrote %s - check it: python3 tools/mapgen check %s" % (a.out, a.out))
    return 0
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

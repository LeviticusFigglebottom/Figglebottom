#!/usr/bin/env python3
"""Weld a skinned GLB whose surface was left as loose triangles.

A local decimate (tools/art/decimate_glb.py, used when Tripo's remesh fails)
can leave neighbouring triangles with their own copies of a corner, a hair
apart and with different skin weights. At rest the surface looks closed;
animated, the copies part and the model shows cracks. This snaps every group
of corners within EPS of each other to one position with one set of joints
and weights (the copies stay, so UVs and normals are kept), marks the
materials double-sided like the rest of the cast, and reports the open edges
before and after. Pure Python, no Blender.

usage: python3 tools/art/weld_glb.py in.glb out.glb [eps_metres=0.002]
       python3 tools/art/weld_glb.py --report in.glb
"""
import json
import struct
import sys
from collections import defaultdict

CT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path):
    data = open(path, "rb").read()
    assert data[:4] == b"glTF"
    jl = struct.unpack_from("<I", data, 12)[0]
    js = json.loads(data[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack_from("<I", data, off)[0]
    return js, bytearray(data[off + 8:off + 8 + bl])


def write_glb(path, js, binb):
    jb = json.dumps(js, separators=(",", ":")).encode()
    jb += b" " * (-len(jb) % 4)
    binb = bytes(binb) + b"\0" * (-len(binb) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(jb) + 8 + len(binb)))
        f.write(struct.pack("<I4s", len(jb), b"JSON") + jb)
        f.write(struct.pack("<I4s", len(binb), b"BIN\0") + binb)


def acc_info(js, k):
    a = js["accessors"][k]
    bv = js["bufferViews"][a["bufferView"]]
    fmt, size = CT[a["componentType"]]
    n = NC[a["type"]]
    stride = bv.get("byteStride") or size * n
    return a, bv.get("byteOffset", 0) + a.get("byteOffset", 0), fmt, n, stride


def read_acc(js, binb, k):
    a, off, fmt, n, stride = acc_info(js, k)
    return [struct.unpack_from("<%d%s" % (n, fmt), binb, off + i * stride) for i in range(a["count"])]


def write_acc(js, binb, k, rows):
    a, off, fmt, n, stride = acc_info(js, k)
    for i, r in enumerate(rows):
        struct.pack_into("<%d%s" % (n, fmt), binb, off + i * stride, *r)


def clusters(pos, eps):
    """Union corners closer than eps (grid hash + union-find)."""
    parent = list(range(len(pos)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    grid = defaultdict(list)
    inv = 1.0 / eps
    for i, p in enumerate(pos):
        grid[(int(p[0] * inv), int(p[1] * inv), int(p[2] * inv))].append(i)
    e2 = eps * eps
    for (cx, cy, cz), mem in grid.items():
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    other = grid.get((cx + dx, cy + dy, cz + dz))
                    if not other:
                        continue
                    for i in mem:
                        pi = pos[i]
                        for j in other:
                            if j <= i:
                                continue
                            pj = pos[j]
                            if (pi[0] - pj[0]) ** 2 + (pi[1] - pj[1]) ** 2 + (pi[2] - pj[2]) ** 2 <= e2:
                                ra, rb = find(i), find(j)
                                if ra != rb:
                                    parent[rb] = ra
    return [find(i) for i in range(len(pos))]


def open_edges(idx, cid):
    cnt = defaultdict(int)
    for t in range(0, len(idx), 3):
        a, b, c = cid[idx[t]], cid[idx[t + 1]], cid[idx[t + 2]]
        for u, v in ((a, b), (b, c), (c, a)):
            if u != v:
                cnt[(min(u, v), max(u, v))] += 1
    return sum(1 for v in cnt.values() if v == 1)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    report = "--report" in sys.argv
    js, binb = read_glb(args[0])
    eps = float(args[2]) if len(args) > 2 else 0.002
    for mesh in js["meshes"]:
        for prim in mesh["primitives"]:
            at = prim["attributes"]
            pos = read_acc(js, binb, at["POSITION"])
            idx = [r[0] for r in read_acc(js, binb, prim["indices"])]
            exact = clusters(pos, 1e-6)
            print("%s: %d corners, %d triangles, %d open edges as stored" % (mesh.get("name", "mesh"), len(pos), len(idx) // 3, open_edges(idx, exact)))
            if report:
                for e in (0.0005, 0.001, 0.002, 0.004, 0.008):
                    cid = clusters(pos, e)
                    print("   eps %.1f mm: %d groups, %d open edges" % (e * 1000, len(set(cid)), open_edges(idx, cid)))
                continue
            cid = clusters(pos, eps)
            groups = defaultdict(list)
            for i, c in enumerate(cid):
                groups[c].append(i)
            joints = read_acc(js, binb, at["JOINTS_0"]) if "JOINTS_0" in at else None
            weights = read_acc(js, binb, at["WEIGHTS_0"]) if "WEIGHTS_0" in at else None
            moved = 0
            for mem in groups.values():
                if len(mem) < 2:
                    continue
                m = tuple(sum(pos[i][k] for i in mem) / len(mem) for k in range(3))
                lead = min(mem)
                for i in mem:
                    if pos[i] != m:
                        moved += 1
                    pos[i] = m
                    if joints is not None:
                        joints[i] = joints[lead]
                        weights[i] = weights[lead]
            write_acc(js, binb, at["POSITION"], pos)
            if joints is not None:
                write_acc(js, binb, at["JOINTS_0"], joints)
                write_acc(js, binb, at["WEIGHTS_0"], weights)
            print("   welded at %.1f mm: %d corners moved, %d open edges left" % (eps * 1000, moved, open_edges(idx, cid)))
    if report:
        return
    for m in js.get("materials", []):
        m["doubleSided"] = True
    write_glb(args[1], js, binb)


if __name__ == "__main__":
    main()

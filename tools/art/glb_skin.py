"""Read and rewrite the skin of a processed character GLB in place.

The rig-fix scripts (fix_host_hip_arm.py, fix_fellcaller_horn.py,
fix_leadvoice_cloak.py) share this: positions, joints, weights and triangles
as numpy arrays, mesh islands by connected components (vertices welded by
position, since a UV seam splits them), and writers that put new joints,
weights or a shorter triangle list back without moving any other byte, so the
clips, the rest pose and the textures stay exactly as blender_process.py
exported them.

Positions are the mesh's own bind space (the processed GLBs: metres at
target height before the armature's scale, +Y up).
"""
import json
import struct
from pathlib import Path

import numpy as np

DT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Glb:
    def __init__(self, path):
        self.path = Path(path)
        b = self.path.read_bytes()
        n = struct.unpack_from("<I", b, 12)[0]
        self.head = bytearray(b[:20 + n])
        self.j = json.loads(b[20:20 + n])
        self.bin = bytearray(b[20 + n + 8:])
        self.tail_head = b[20 + n:20 + n + 8]
        self.names = [self.j["nodes"][i]["name"] for i in self.j["skins"][0]["joints"]]
        self._json_dirty = False

    # ---- accessors
    def _view(self, i):
        a = self.j["accessors"][i]
        bv = self.j["bufferViews"][a["bufferView"]]
        dt = np.dtype(DT[a["componentType"]])
        nc = NC[a["type"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride", dt.itemsize * nc)
        return a, dt, nc, off, stride

    def read(self, i):
        a, dt, nc, off, stride = self._view(i)
        if stride == dt.itemsize * nc:
            arr = np.frombuffer(self.bin, dt, a["count"] * nc, off)
        else:
            raw = np.frombuffer(self.bin, np.uint8, a["count"] * stride, off).reshape(a["count"], stride)
            arr = raw[:, :dt.itemsize * nc].copy().view(dt)
        return arr.reshape(a["count"], nc).copy() if nc > 1 else arr.copy()

    def write(self, i, arr):
        a, dt, nc, off, stride = self._view(i)
        arr = np.ascontiguousarray(arr, dt).reshape(-1, nc)
        assert len(arr) <= a["count"], "an accessor can shrink, never grow"
        for k in range(len(arr)) if stride != dt.itemsize * nc else ():
            self.bin[off + k * stride:off + k * stride + dt.itemsize * nc] = arr[k].tobytes()
        if stride == dt.itemsize * nc:
            self.bin[off:off + arr.nbytes] = arr.tobytes()
        if len(arr) != a["count"]:
            a["count"] = len(arr)
            self._json_dirty = True

    # ---- the skinned primitives
    def prims(self):
        return [p for m in self.j["meshes"] for p in m["primitives"] if "JOINTS_0" in p["attributes"]]

    def joint(self, name):
        """Index of a joint by the end of its name (mixamorig:Hips, tripo::...)."""
        hit = [i for i, n in enumerate(self.names) if n.endswith(name)]
        assert len(hit) == 1, (name, hit)
        return hit[0]

    def save(self):
        if self._json_dirty:
            # the JSON chunk keeps its length (padded with spaces) so the
            # binary chunk does not move
            raw = json.dumps(self.j, separators=(",", ":")).encode()
            room = len(self.head) - 20
            assert len(raw) <= room, "JSON grew"
            self.head[20:] = raw + b" " * (room - len(raw))
        self.path.write_bytes(bytes(self.head) + self.tail_head + bytes(self.bin))


class Prim:
    """One skinned primitive: pos (n,3), joints (n,4), weights (n,4), tris (m,3)."""

    def __init__(self, glb, prim):
        self.g = glb
        self.p = prim
        at = prim["attributes"]
        self.pos = glb.read(at["POSITION"]).astype(np.float64)
        self.joints = glb.read(at["JOINTS_0"]).astype(np.int64)
        self.weights = glb.read(at["WEIGHTS_0"]).astype(np.float64)
        self.tris = glb.read(prim["indices"]).astype(np.int64).reshape(-1, 3)

    def dominant(self):
        """Each vertex's heaviest joint."""
        return self.joints[np.arange(len(self.pos)), self.weights.argmax(1)]

    def weight_of(self, joints):
        """Per vertex, the weight carried by any joint in `joints`."""
        m = np.isin(self.joints, list(joints))
        return (self.weights * m).sum(1)

    def islands(self, tol=1e-5):
        """Connected components over the triangles, with vertices at one
        position welded. Returns a label per vertex (-1: in no triangle)."""
        key = np.round(self.pos / tol).astype(np.int64)
        _, weld = np.unique(key, axis=0, return_inverse=True)
        weld = weld.ravel()
        parent = np.arange(weld.max() + 1)

        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x
        for a, b, c in weld[self.tris]:
            ra, rb, rc = find(a), find(b), find(c)
            parent[rb] = ra
            parent[rc] = ra
        root = np.array([find(x) for x in range(len(parent))])
        used = np.zeros(len(self.pos), bool)
        used[self.tris.ravel()] = True
        _, lab = np.unique(root[weld], return_inverse=True)
        lab = lab.ravel()
        lab[~used] = -1
        return lab

    def grow(self, seed, stop=None, tol=1e-5):
        """Flood a vertex mask across shared triangle edges (welded), not
        entering vertices where `stop` is set."""
        key = np.round(self.pos / tol).astype(np.int64)
        _, weld = np.unique(key, axis=0, return_inverse=True)
        weld = weld.ravel()
        nw = weld.max() + 1
        on = np.zeros(nw, bool)
        on[weld[seed]] = True
        block = np.zeros(nw, bool)
        if stop is not None:
            block[weld[stop]] = True
            block &= ~on
        wt = weld[self.tris]
        while True:
            hit = on[wt].any(1)
            new = np.zeros(nw, bool)
            new[wt[hit].ravel()] = True
            new &= ~on & ~block
            if not new.any():
                break
            on |= new
        return on[weld]

    def tube(self, seed, limit, lo=0.1, hi=1.4, step=0.02, axis=None):
        """A stray limb from its far end: flood from `seed` up the limb's own
        axis and stop at the furthest cut that is still only the limb (past
        its root the flood takes in the body and jumps over `limit`)."""
        c = self.pos[seed].mean(0)
        if axis is None:
            axis = np.linalg.svd(self.pos[seed] - c)[2][0]
        axis = np.asarray(axis, float)
        if axis[1] < 0:
            axis = -axis   # up the limb, toward its root
        t = (self.pos - c) @ axis
        best = None
        for s0 in np.arange(lo, hi, step):
            m = self.grow(seed, t > s0)
            if m.sum() > limit:
                break
            best = m
        return best

    def live(self):
        """Vertices still used by a triangle."""
        m = np.zeros(len(self.pos), bool)
        m[self.tris.ravel()] = True
        return m

    def bind(self, mask, joints, weights):
        """Give the masked vertices these joints and weights (up to four)."""
        js = np.zeros(4, np.int64)
        ws = np.zeros(4)
        js[:len(joints)] = joints
        ws[:len(weights)] = weights
        self.joints[mask] = js
        self.weights[mask] = ws / ws.sum()

    def set_rows(self, mask, joints, weights):
        """Per-vertex joints (k,4) and weights (k,4) for the masked vertices."""
        self.joints[mask] = joints
        w = np.asarray(weights, float)
        self.weights[mask] = w / w.sum(1, keepdims=True)

    def drop(self, mask):
        """Remove every triangle that touches a masked vertex."""
        keep = ~mask[self.tris].any(1)
        n = int((~keep).sum())
        self.tris = self.tris[keep]
        return n

    def drop_and_cap(self, mask, tol=1e-5):
        """Remove the masked limb and close the hole it leaves: one of the
        removed vertices is moved to the middle of the cut and fanned to its
        rim, bound like the rim, so nothing is added to the buffers."""
        key = np.round(self.pos / tol).astype(np.int64)
        _, weld = np.unique(key, axis=0, return_inverse=True)
        weld = weld.ravel()
        gone = mask[self.tris].any(1)
        cut = {(weld[t[(i + 1) % 3]], weld[t[i]]) for t in self.tris[gone] for i in range(3)}
        rim = [(t[i], t[(i + 1) % 3]) for t in self.tris[~gone] for i in range(3)
               if (weld[t[i]], weld[t[(i + 1) % 3]]) in cut]
        n = int(gone.sum())
        self.tris = self.tris[~gone]
        if not rim:
            return n
        ring = np.unique(np.array(rim).ravel())
        at = self.p["attributes"]
        centre = int(np.flatnonzero(mask & ~np.isin(np.arange(len(mask)), self.tris.ravel()))[0])
        self.pos[centre] = self.pos[ring].mean(0)
        nrm = self.g.read(at["NORMAL"])
        v = nrm[ring].mean(0)
        nrm[centre] = v / max(np.linalg.norm(v), 1e-6)
        self.g.write(at["NORMAL"], nrm)
        uv = self.g.read(at["TEXCOORD_0"])
        uv[centre] = uv[ring[0]]
        self.g.write(at["TEXCOORD_0"], uv)
        tot = {}
        for r in ring:
            for jn, w in zip(self.joints[r], self.weights[r]):
                tot[jn] = tot.get(jn, 0.0) + w
        top = sorted(tot, key=tot.get, reverse=True)[:4]
        self.bind(np.arange(len(mask)) == centre, top, [tot[k] for k in top])
        self.tris = np.vstack([self.tris, [(b, a, centre) for a, b in rim]])
        self._pos_dirty = True
        return n

    def flush(self):
        if getattr(self, "_pos_dirty", False):
            self.g.write(self.p["attributes"]["POSITION"], self.pos)
        at = self.p["attributes"]
        self.g.write(at["JOINTS_0"], self.joints)
        self.g.write(at["WEIGHTS_0"], self.weights)
        self.g.write(self.p["indices"], self.tris.ravel())

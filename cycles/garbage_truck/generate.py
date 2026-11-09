#!/usr/bin/env python3
"""Generates the Garbage Truck cycle model: cycle.ase and bike.png.

Usage: python3 cycles/garbage_truck/generate.py   (from the repository root)

Coordinates are in world units (a classic cycle is about 1.4 long):
x forward, y left, z up. The front of the bumper is at x = 0, the cycle's
true position; the game also aligns the front-most point there by itself.
ASE units are world units * 80 (the game reads ASE in inches, * 0.025,
and draws cycle models at half size).

bike.png is a 4x4 palette of 16x16 cells; each face samples the centre of
its colour's cell. Transparent pixels show the player colour.
"""
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ASE_SCALE = 80.0

# palette: name -> (cell index, RGBA)
PALETTE = {
    'paint':  (0, (0, 0, 0, 0)),          # player colour
    'cab':    (1, (0, 0, 0, 64)),         # player colour, a little darker
    'stripe': (2, (250, 215, 40, 255)),
    'glass':  (3, (40, 60, 80, 255)),
    'wheel':  (4, (25, 25, 25, 255)),
    'hub':    (5, (170, 170, 170, 255)),
    'steel':  (6, (120, 125, 130, 255)),
    'light':  (7, (255, 255, 230, 255)),
    'bumper': (8, (235, 235, 235, 255)),
}
CELLS, CELL = 4, 16


def box(x0, x1, y0, y1, z0, z1, part):
    p = [(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
    quads = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (1, 3, 7, 5), (0, 4, 6, 2)]
    return [([p[i] for i in q], part) for q in quads]


def wedge(x0, x1, y0, y1, z0, z_back, z_front, part):
    """box whose top slopes from z_back at x0 to z_front at x1"""
    p = [(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0),
         (x0, y0, z_back), (x0, y1, z_back), (x1, y1, z_front), (x1, y0, z_front)]
    quads = [(0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5), (4, 5, 6, 7), (0, 3, 2, 1)]
    return [([p[i] for i in q], part) for q in quads]


def truck():
    t = []
    w = .3  # half width
    t += box(-1.62, -0.03, -w, w, .10, .18, 'steel')            # chassis
    t += box(-1.30, -0.50, -w, w, .18, .78, 'paint')             # compactor body
    t += wedge(-1.62, -1.30, -w, w, .18, .55, .78, 'paint')      # rear hopper
    t += box(-1.30, -0.50, -w - .005, w + .005, .42, .50, 'stripe')
    t += box(-0.50, -0.06, -w, w, .18, .62, 'cab')
    t += box(-0.065, -0.055, -w + .04, w - .04, .38, .58, 'glass')   # windscreen
    t += box(-0.42, -0.16, -w - .006, w + .006, .40, .57, 'glass')   # side windows
    t += box(-0.06, 0.0, -w - .02, w + .02, .12, .24, 'bumper')      # front = true position
    t += box(-0.07, -0.02, -w + .02, -w + .1, .26, .32, 'light')
    t += box(-0.07, -0.02, w - .1, w - .02, .26, .32, 'light')
    for x in (-0.30, -1.05, -1.32):
        for side in (-1, 1):
            a, b = sorted((side * (w - .02), side * (w + .05)))
            t += box(x - .13, x + .13, a, b, 0, .26, 'wheel')
            a, b = sorted((side * (w + .05), side * (w + .055)))
            t += box(x - .05, x + .05, a, b, .08, .18, 'hub')
    return t


def outward(quads):
    """orient every quad counter-clockwise seen from outside its solid"""
    out = []
    solids = {}
    for q, part in quads:
        pass
    # each solid is 6 consecutive quads
    for i in range(0, len(quads), 6):
        solid = quads[i:i + 6]
        pts = [v for q, _ in solid for v in q]
        c = [sum(v[k] for v in pts) / len(pts) for k in range(3)]
        for q, part in solid:
            a, b, d = q[0], q[1], q[3]
            u = [b[k] - a[k] for k in range(3)]
            v = [d[k] - a[k] for k in range(3)]
            n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            fc = [sum(p[k] for p in q) / 4 for k in range(3)]
            if sum(n[k] * (fc[k] - c[k]) for k in range(3)) < 0:
                q = list(reversed(q))
            out.append((q, part))
    return out


def write_ase(quads, path):
    verts, faces, tverts, tfaces = [], [], [], []
    for q, part in quads:
        cell = PALETTE[part][0]
        u = ((cell % CELLS) + .5) / CELLS
        row = (cell // CELLS) + .5
        v = 1 - row / CELLS  # the game flips v: texture row = (1 - v) * size
        t = len(tverts)
        tverts.append((u, v))
        base = len(verts)
        verts.extend(q)
        for tri in ((0, 1, 2), (0, 2, 3)):
            faces.append(tuple(base + i for i in tri))
            tfaces.append((t, t, t))
    with open(path, 'w') as f:
        f.write('*3DSMAX_ASCIIEXPORT 200\n*COMMENT "Armagetron Pizza: Garbage Truck, made by generate.py"\n')
        f.write('*GEOMOBJECT {\n *NODE_NAME "truck"\n *MESH {\n')
        f.write(f'  *MESH_NUMVERTEX {len(verts)}\n  *MESH_NUMFACES {len(faces)}\n  *MESH_VERTEX_LIST {{\n')
        for i, (x, y, z) in enumerate(verts):
            f.write(f'   *MESH_VERTEX {i} {x * ASE_SCALE:.4f} {y * ASE_SCALE:.4f} {z * ASE_SCALE:.4f}\n')
        f.write('  }\n  *MESH_FACE_LIST {\n')
        for i, (a, b, c) in enumerate(faces):
            f.write(f'   *MESH_FACE {i}: A: {a} B: {b} C: {c} AB: 1 BC: 1 CA: 0\n')
        f.write(f'  }}\n  *MESH_NUMTVERTEX {len(tverts)}\n  *MESH_TVERTLIST {{\n')
        for i, (u, v) in enumerate(tverts):
            f.write(f'   *MESH_TVERT {i} {u:.4f} {v:.4f} 0.0000\n')
        f.write(f'  }}\n  *MESH_NUMTVFACES {len(tfaces)}\n  *MESH_TFACELIST {{\n')
        for i, (a, b, c) in enumerate(tfaces):
            f.write(f'   *MESH_TFACE {i} {a} {b} {c}\n')
        f.write('  }\n }\n}\n')
    return len(verts), len(faces)


def write_png(path):
    size = CELLS * CELL
    pixels = [[(0, 0, 0, 0)] * size for _ in range(size)]
    for cell, rgba in PALETTE.values():
        cx, cy = (cell % CELLS) * CELL, (cell // CELLS) * CELL
        for y in range(cy, cy + CELL):
            for x in range(cx, cx + CELL):
                pixels[y][x] = rgba
    raw = b''.join(b'\x00' + bytes(c for px in row for c in px) for row in pixels)

    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)


if __name__ == '__main__':
    quads = outward(truck())
    nv, nf = write_ase(quads, os.path.join(HERE, 'cycle.ase'))
    write_png(os.path.join(HERE, 'bike.png'))
    print(f'cycle.ase: {nv} vertices, {nf} triangles; bike.png written')

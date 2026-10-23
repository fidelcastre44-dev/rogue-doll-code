"""Reprise d'une capture CMU (BVH) sur le héros en blocs.
Pour chaque image : orientation mondiale de chaque os du héros, calculée d'après les directions des membres de la capture
(bras, avant-bras, cuisse, tibia) et l'orientation du bassin, du buste et de la tête ; puis rotations locales (quaternions).
Les pieds qui restent au sol sont donnés en position (le jeu les plante par IK, ils ne glissent plus).
Sortie : JSON lu par tools/import_cmu.gd (qui convertit en angles, aligne le coup sur l'ancien et écrit fiches + poses).
  python3 tools/cmu/retarget.py <dossier des .bvh> <sortie.json>
"""
import json, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from bvh import BVH
from clips import CLIPS

C = np.diag([-1.0, 1.0, -1.0])        # capture : regarde +Z, gauche en +X ; héros : regarde -Z, gauche en -X
LEG = 0.43 + 0.45
GUARD_FEET = {"l": np.array([-0.13, 0.02, -0.22]), "r": np.array([0.16, 0.02, 0.24])}   # pieds de la garde (poses.tres)


def nrm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def quat(m):
    """Matrice de rotation -> quaternion [x, y, z, w]."""
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        w, x, y, z = 0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w, x, y, z = (m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w, x, y, z = (m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s
    else:
        s = np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w, x, y, z = (m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s
    q = np.array([x, y, z, w])
    return (q / np.linalg.norm(q)).tolist()


def basis(y, z):
    """Base orthonormée (colonnes x, y, z) d'axe y donné, z le plus proche possible de z."""
    y = nrm(y)
    z = nrm(z - y * np.dot(z, y))
    return np.column_stack([np.cross(y, z), y, z])


def rx(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(a):
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


class Retarget:
    def __init__(self, b):
        self.b, self.I = b, b.idx
        o = b.offset
        self.leg = np.linalg.norm(o[self.I["LeftLeg"]]) + np.linalg.norm(o[self.I["LeftFoot"]])
        self.s = LEG / self.leg
        self.prev_z = {}

    def frame(self, f, yaw, ground, plant):
        b, I = self.b, self.I
        P, R = b.fk(f)
        Y = ry(yaw)
        W = lambda name: Y @ C @ P[I[name]]                    # position, repère du héros (non mise à l'échelle)
        Rot = lambda name: Y @ C @ R[I[name]] @ C              # orientation d'un os du tronc, repère du héros
        out = {}
        # bassin : hauteur des hanches (articulations des cuisses) au-dessus du sol, à l'échelle
        hj = (W("LeftUpLeg") + W("RightUpLeg")) * 0.5
        # pieds d'appui : ils restent là où la garde du jeu les met ; le bassin se place par rapport à eux comme dans la capture
        ref = sum(W({"l": "LeftFoot", "r": "RightFoot"}[k]) for k in plant) / len(plant)
        gref = sum(GUARD_FEET[k] for k in plant) / len(plant)
        hp = (hj - ref) * self.s + gref
        hp[1] = (hj[1] - ground) * self.s + 0.02 - 0.9
        out["hips_pos"] = hp.tolist()
        G = {}
        G["hips"] = basis(W("Spine") - W("Hips"), Rot("Hips")[:, 2])
        G["spine"] = basis(W("Neck1") - W("Spine"), Rot("Spine1")[:, 2])
        G["head"] = basis(Y @ C @ b.end_pos(P, R, "Head") - W("Neck1"), Rot("Head")[:, 2])
        for side, cs in (("l", "Left"), ("r", "Right")):
            u = nrm(W(cs + "ForeArm") - W(cs + "Arm"))
            fa = nrm(W(cs + "Hand") - W(cs + "ForeArm"))
            perp = fa - u * np.dot(fa, u)
            key = "sh_" + side
            pz = self.prev_z.get(key, G["spine"][:, 2])
            z = -perp if np.linalg.norm(perp) > 0.15 else -perp + pz * 0.3
            G[key] = basis(-u, z)
            self.prev_z[key] = G[key][:, 2]
            ang = np.arccos(np.clip(np.dot(u, fa), -1, 1))
            G["el_" + side] = G[key] @ rx(ang)
            t = nrm(W(cs + "Leg") - W(cs + "UpLeg"))
            sh = nrm(W(cs + "Foot") - W(cs + "Leg"))
            toe = nrm(W(cs + "ToeBase") - W(cs + "Foot"))
            perp = sh - t * np.dot(sh, t)
            tperp = toe - t * np.dot(toe, t)
            G["hip_" + side] = basis(-t, perp - tperp * 0.3)
            ang = np.arccos(np.clip(np.dot(t, sh), -1, 1))
            G["kn_" + side] = G["hip_" + side] @ rx(-ang)
            if side in plant:
                out["foot_" + side] = GUARD_FEET[side].tolist()
            else:
                out["foot_" + side] = None
        par = {"hips": None, "spine": "hips", "head": "spine", "sh_l": "spine", "el_l": "sh_l", "sh_r": "spine", "el_r": "sh_r",
               "hip_l": "hips", "kn_l": "hip_l", "hip_r": "hips", "kn_r": "hip_r"}
        for n, p in par.items():
            loc = G[n] if p is None else G[p].T @ G[n]
            out[n] = quat(loc)
        # points utiles pour l'analyse (repère du héros, à l'échelle)
        out["_tip"] = {k: ((W(v) - ref) * self.s + gref).tolist() for k, v in
                       (("fist_l", "LeftHand"), ("fist_r", "RightHand"), ("foot_l", "LeftFoot"), ("foot_r", "RightFoot"))}
        return out


def run(folder, dest):
    res = {}
    for c in CLIPS:
        b = BVH(os.path.join(folder, c["file"] + ".bvh"))
        rt = Retarget(b)
        fr = lambda t: int(round(t / b.dt))
        # cap : la direction « frappe » (du buste vers le point d'impact) devient -Z
        P, R = b.fk(fr(c.get("aim", c["hit"])))
        I = b.idx
        src = {"fist_l": "LeftHand", "fist_r": "RightHand", "foot_l": "LeftFoot", "foot_r": "RightFoot"}[c["tip"]]
        d = C @ (P[I[src]] - P[I["Spine1" if c["tip"].startswith("fist") else "Hips"]])
        yaw = np.arctan2(d[0], -d[2]) * -1.0
        # vérifie : ry(yaw) @ d doit pointer vers -Z
        dd = ry(yaw) @ d
        if dd[2] > 0:
            yaw += np.pi
        Y = ry(yaw)
        lo = min(fr(c["t0"]), fr(c.get("gt0", c["t0"])))
        hi = max(fr(c["t1"]), fr(c.get("gt1", c["t1"])))
        ground = min(min((Y @ C @ b.fk(f)[0][I[n]])[1] for n in ("LeftFoot", "RightFoot")) for f in range(lo, hi + 1, 2))
        frames = []
        for tm in c["samples"]:
            fd = rt.frame(fr(tm[1]), yaw, ground, tm[2] if len(tm) > 2 else c.get("plant", "lr"))
            fd["t"] = tm[0]
            fd["hips_pos"][1] += c.get("lift", 0.0)   # bassin un peu plus haut : le pied qui balaie ne frotte pas le sol
            frames.append(fd)
        rest = [rt.frame(fr(c[k]), yaw, ground, c.get("plant", "lr")) for k in ("t0", "t1")]   # garde de la capture, avant et après
        res[c["move"]] = {"clip": c["file"], "pose": c["pose"], "frames": frames, "rest": rest, "curve": c.get("curve", "lin"),
                          "end_key": c.get("end_key", "guard"), "align": c.get("align", True)}
    json.dump(res, open(dest, "w"), indent=1)
    print("ok", list(res))


if __name__ == "__main__":
    run(sys.argv[1], sys.argv[2])

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
from clips import CLIPS, CYCLES, GETUPS

C = np.diag([-1.0, 1.0, -1.0])        # capture : regarde +Z, gauche en +X ; héros : regarde -Z, gauche en -X
LEG = 0.43 + 0.45
ATTACK_SPEED = 1.35   # player.attack_speed
LOW = ("LeftFoot", "RightFoot", "LeftHand", "RightHand", "Neck1")   # ce qui peut toucher le sol quand il est couché
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

    def frame(self, f, yaw, ground, plant, origin=None):
        b, I = self.b, self.I
        P, R = b.fk(f)
        Y = ry(yaw)
        W = lambda name: Y @ C @ P[I[name]]                    # position, repère du héros (non mise à l'échelle)
        Rot = lambda name: Y @ C @ R[I[name]] @ C              # orientation d'un os du tronc, repère du héros
        out = {}
        # bassin : hauteur des hanches (articulations des cuisses) au-dessus du sol, à l'échelle
        hj = (W("LeftUpLeg") + W("RightUpLeg")) * 0.5
        # pieds d'appui : ils restent là où la garde du jeu les met ; le bassin se place par rapport à eux comme dans la capture
        if plant:
            ref = sum(W({"l": "LeftFoot", "r": "RightFoot"}[k]) for k in plant) / len(plant)
            gref = sum(GUARD_FEET[k] for k in plant) / len(plant)
        else:   # cycle (course, marche) : le bassin se place par rapport à un point qui avance à vitesse constante
            ref, gref = origin, np.zeros(3)
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


def cycle(folder, c):
    """Cycle (course, marche, garde) : n images sur une période ; le déplacement moyen est retiré (le jeu fait avancer le héros),
    le cap moyen devient -Z ; la phase 0 = pied gauche le plus en avant. Sortie : images + foulée (m par cycle) + période."""
    b = BVH(os.path.join(folder, c["file"] + ".bvh"))
    rt = Retarget(b)
    I = b.idx
    if c.get("rm"):
        c = dict(c, period=c["t1"] - c["t0"])
    f0, n = int(round(c["t0"] / b.dt)), int(round(c["period"] / b.dt))
    if c.get("end_origin"):
        # relevé : repère = debout à la fin (pieds au milieu, cap du bassin) ; le bassin garde tout son trajet jusque-là
        fr = lambda t: int(round(t / b.dt))
        P, R = b.fk(fr(c["t1"]))
        fw = C @ R[I["Hips"]] @ np.array([0, 0, 1.0])
        yaw = -np.arctan2(fw[0], -fw[2])
        if (ry(yaw) @ fw)[2] > 0:
            yaw += np.pi
        Y = ry(yaw)
        org = Y @ C @ ((P[I["LeftFoot"]] + P[I["RightFoot"]]) * 0.5)
        org[1] = 0.0
        ground = min(min((Y @ C @ b.fk(f)[0][I[k]])[1] for k in LOW) for f in range(f0, f0 + n + 1, 4))
        N = c.get("n", 24)
        frames = [rt.frame(f0 + int(round(i * n / (N - 1))), yaw, ground, "", origin=org) for i in range(N)]
        return {"clip": c["file"], "frames": frames, "stride": 0.0, "period": c["period"], "rm": True, "planted": False, "end_origin": True}
    H = np.array([b.fk(f)[0][0] for f in range(f0, f0 + n + 1)])   # bassin, repère de la capture
    draw = H[-1] - H[0]
    draw[1] = 0.0
    d = C @ draw
    move = np.linalg.norm(d)
    yaw = 0.0
    if move > 1e-3 and not c.get("plant") and c.get("face") != "hips":
        yaw = -np.arctan2(d[0], -d[2])
        if (ry(yaw) @ d)[2] > 0:
            yaw += np.pi
    else:   # sur place (garde) : on garde le cap du bassin
        fw = C @ b.fk(f0)[1][0] @ np.array([0, 0, 1.0])
        yaw = -np.arctan2(fw[0], -fw[2])
        if (ry(yaw) @ fw)[2] > 0:
            yaw += np.pi
        yaw += np.radians(c.get("yaw", 0.0))
    Y = ry(yaw)
    ground = min(min((Y @ C @ b.fk(f)[0][I[k]])[1] for k in ("LeftFoot", "RightFoot")) for f in range(f0, f0 + n + 1))
    if c.get("rm"):
        # geste avec déplacement (enjambée, roulade, réception…) : le bassin garde tout son trajet depuis le départ ;
        # le jeu en tire la trajectoire du héros (tools/import_cmu.gd)
        if "ground_t" in c:   # sol de la fin (tapis…) : hauteur des chevilles à cet instant
            P = b.fk(int(round(c["ground_t"] / b.dt)))[0]
            ground = min((Y @ C @ P[I[k]])[1] for k in ("LeftFoot", "RightFoot"))
        N = c.get("n", 24)
        org = Y @ C @ H[0]
        org[1] = 0.0
        frames = []
        for i in range(N):
            f = f0 + int(round(i * n / (N - 1)))
            frames.append(rt.frame(f, yaw, ground, c.get("plant", ""), origin=org))
        return {"clip": c["file"], "frames": frames, "stride": float(move * rt.s), "period": c["period"], "rm": True,
                "planted": bool(c.get("plant"))}
    # phase 0 : pied gauche le plus en avant (par rapport au bassin)
    best, k0 = None, 0
    for k in range(n):
        P = b.fk(f0 + k)[0]
        z = (Y @ C @ (P[I["LeftFoot"]] - P[0]))[2]
        if best is None or z < best:
            best, k0 = z, k
    N = c.get("n", 32)
    frames = []
    for i in range(N):
        k = (k0 + i * n / N) % n
        f = f0 + int(round(k))
        org = Y @ C @ (H[0] + draw * (k / n))
        org[1] = 0.0
        fd = rt.frame(f, yaw, ground, c.get("plant", ""), origin=org)
        frames.append(fd)
    # le bassin oscille autour de la verticale des pieds : on centre le cycle
    if c.get("plant"):
        return {"clip": c["file"], "frames": frames, "stride": 0.0, "period": c["period"], "additive": True}
    mx = np.mean([fd["hips_pos"][0] for fd in frames])
    mz = np.mean([fd["hips_pos"][2] for fd in frames])
    for fd in frames:
        fd["hips_pos"][0] -= mx
        fd["hips_pos"][2] -= mz
    return {"clip": c["file"], "frames": frames, "stride": float(move * rt.s), "period": c["period"]}


def anime_samples(b, c, src):
    """Rythme « combat anime » (v0.215) : armé lisible (t0 -> a, en W s), frappe sèche (a -> impact, en S s, 5 images),
    pose figée à l'impact (H s), retour amorti (impact -> t1, en R s). a = le moment où le membre part vraiment
    (sa vitesse dépasse 35 % de son pic). Temps réels en secondes, convertis en temps de fiche (× vitesse d'attaque)."""
    I = b.idx
    fr = lambda t: int(round(t / b.dt))
    an = c["anime"]
    W, S, H, R = (an[k] * ATTACK_SPEED for k in ("windup", "strike", "hold", "recover"))
    ts = np.arange(c["t0"], c["hit"] + 1e-6, b.dt)
    pos = np.array([b.fk(fr(x))[0][I[src]] - b.fk(fr(x))[0][0] for x in ts])
    v = np.r_[0.0, np.linalg.norm(np.diff(pos, axis=0), axis=1)]
    pk = v.max()
    a = c["t0"]
    for x, vv in zip(ts, v):
        if vv < 0.35 * pk:
            a = x
    a = min(max(a, c["t0"] + 0.02), c["hit"] - 0.03)
    def plant(x):
        pl = c.get("plant", "lr")
        for a0, a1, p in c.get("plant_at", []):
            if a0 <= x <= a1:
                pl = p
        return pl
    out = []
    for x in np.arange(c["t0"] + 1 / 30, a - 1e-6, 1 / 30):
        out.append((round((x - c["t0"]) / (a - c["t0"]) * W, 4), float(x), plant(x)))
    for i in range(5):
        x = a + (c["hit"] - a) * i / 4
        out.append((round(W + S * i / 4, 4), float(x), plant(x)))
    out.append((round(W + S + H, 4), c["hit"], plant(c["hit"])))
    for x in list(np.arange(c["hit"] + 1 / 30, c["t1"] - 1e-6, 1 / 30)) + [c["t1"]]:
        out.append((round(W + S + H + (x - c["hit"]) / (c["t1"] - c["hit"]) * R, 4), float(x), plant(x)))
    return out, {"active": round(W + S, 4), "end": round(W + S + H + R + c.get("blend", 0.08), 4), "hold": round(H, 4)}


def getup(folder, c):
    """Relevé (fin d'une fiche) : les clés de la fiche jusqu'à `keep` (temps du jeu) restent (il est couché), puis la capture,
    du bassin qui décolle (t0) à debout (t1), `speed` fois plus vite. Le héros finit planté là où la capture se tient debout."""
    b = BVH(os.path.join(folder, c["file"] + ".bvh"))
    rt = Retarget(b)
    I = b.idx
    fr = lambda t: int(round(t / b.dt))
    P, R = b.fk(fr(c["t1"]))
    fw = C @ R[I["Hips"]] @ np.array([0, 0, 1.0])
    yaw = -np.arctan2(fw[0], -fw[2])
    if (ry(yaw) @ fw)[2] > 0:
        yaw += np.pi
    Y = ry(yaw)
    org = Y @ C @ ((P[I["LeftFoot"]] + P[I["RightFoot"]]) * 0.5)
    org[1] = 0.0
    # couché : le plus bas des chevilles, des mains et de la tête touche le sol
    ground = min(min((Y @ C @ b.fk(f)[0][I[k]])[1] for k in LOW) for f in range(fr(c["t0"]), fr(c["t1"]) + 1, 4))
    sp = c.get("speed", 2.0) / ATTACK_SPEED
    step = c.get("step", 1.0 / 15.0)
    ts = list(np.arange(c["t0"], c["t1"] - 1e-6, step)) + [c["t1"]]
    frames = []
    if c.get("lie"):   # il reste couché dans la pose de la capture (au lieu de la pose couchée de la fiche)
        for tt in (c.get("gap", 0.06), c["keep"]):
            fd = rt.frame(fr(c["t0"]), yaw, ground, "", origin=org)
            fd["t"] = round(tt, 4)
            frames.append(fd)
        ts = ts[1:]
    for x in ts:
        fd = rt.frame(fr(x), yaw, ground, "", origin=org)
        fd["t"] = round(c["keep"] + c.get("gap", 0.06) + (x - c["t0"]) / sp, 4)
        frames.append(fd)
    end = round(frames[-1]["t"] + c.get("blend", 0.08), 4)
    return {"clip": c["file"], "pose": c["pose"], "frames": frames, "rest": None, "curve": "lin", "end_key": "guard",
            "align": False, "reach": False, "keep": c["keep"], "lie": bool(c.get("lie")), "timing": {"end": end}}


def run(folder, dest):
    res = {"_cycles": {}}
    for c in CYCLES:
        res["_cycles"][c["name"]] = cycle(folder, c)
    for c in GETUPS:
        res[c["move"]] = getup(folder, c)
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
        timing = None
        samples = c.get("samples")
        if c.get("anime"):
            samples, timing = anime_samples(b, c, src)
        elif samples is None:
            # rythme de la capture, accéléré `speed` fois (temps des fiches = avant la vitesse d'attaque du héros)
            sp = c.get("speed", 2.0) / ATTACK_SPEED
            step = c.get("step", 1.0 / 30.0)
            ts = list(np.arange(c["t0"] + step, c["t1"] - 1e-6, step)) + [c["hit"], c["t1"]]
            ts = sorted(set(round(float(x), 4) for x in ts))
            ts = [x for x in ts if abs(x - c["hit"]) > step * 0.4 or x == c["hit"]]
            samples = []
            for x in ts:
                pl = c.get("plant", "lr")
                for a0, a1, p in c.get("plant_at", []):
                    if a0 <= x <= a1:
                        pl = p
                samples.append((round((x - c["t0"]) / sp, 4), x, pl))
            timing = {"active": round((c["hit"] - c["t0"]) / sp, 4), "end": round((c["t1"] - c["t0"]) / sp + c.get("blend", 0.08), 4)}
        frames = []
        for tm in samples:
            fd = rt.frame(fr(tm[1]), yaw, ground, tm[2] if len(tm) > 2 else c.get("plant", "lr"))
            fd["t"] = tm[0]
            fd["hips_pos"][1] += c.get("lift", 0.0)   # bassin un peu plus haut : le pied qui balaie ne frotte pas le sol
            frames.append(fd)
        rest = [rt.frame(fr(c[k]), yaw, ground, c.get("plant", "lr")) for k in ("t0", "t1")]   # garde de la capture, avant et après
        res[c["move"]] = {"clip": c["file"], "pose": c["pose"], "frames": frames, "rest": rest, "curve": c.get("curve", "lin"),
                          "end_key": c.get("end_key", "guard"), "align": c.get("align", True),
                          "reach": c.get("reach", False), "timing": timing, "amp": c.get("amp", 1.0), "cancel_r": c.get("cancel_r"),
                          **({"aim_y": c["aim_y"]} if "aim_y" in c else {})}
    json.dump(res, open(dest, "w"), indent=1)
    print("ok", list(res))


if __name__ == "__main__":
    run(sys.argv[1], sys.argv[2])

"""Lecture d'un BVH (CMU / cgspeed) et cinématique directe : positions et orientations mondiales de chaque articulation."""
import numpy as np


def _rot(axis, deg):
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    if axis == "X":
        return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if axis == "Y":
        return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


class BVH:
    def __init__(self, path):
        lines = open(path).read().split("\n")
        self.names, self.parent, self.offset, self.chans, self.ends = [], [], [], [], {}
        stack, i, cur = [], 0, None
        while i < len(lines):
            tok = lines[i].split()
            i += 1
            if not tok:
                continue
            if tok[0] in ("ROOT", "JOINT"):
                self.names.append(tok[1]); self.parent.append(stack[-1] if stack else -1)
                self.offset.append(None); self.chans.append([]); cur = len(self.names) - 1
            elif tok[0] == "End":
                cur = ("end", stack[-1])
            elif tok[0] == "{":
                stack.append(cur if not isinstance(cur, tuple) else -2)
            elif tok[0] == "}":
                stack.pop()
                while stack and stack[-1] == -2:
                    break
            elif tok[0] == "OFFSET":
                v = np.array([float(x) for x in tok[1:4]])
                if isinstance(cur, tuple):
                    self.ends[cur[1]] = v
                else:
                    self.offset[cur] = v
            elif tok[0] == "CHANNELS":
                self.chans[cur] = tok[2:]
            elif tok[0] == "MOTION":
                break
        # « End Site » : la pile contient -2 ; on corrige les parents
        self.nframes = int(lines[i].split()[1]); self.dt = float(lines[i + 1].split()[2])
        self.data = np.array([[float(x) for x in l.split()] for l in lines[i + 2:i + 2 + self.nframes]])
        self.idx = {n: k for k, n in enumerate(self.names)}

    def fk(self, f):
        """Positions et rotations mondiales à l'image f."""
        row, c = self.data[f], 0
        P, R = [None] * len(self.names), [None] * len(self.names)
        for k in range(len(self.names)):
            loc, rot = self.offset[k].copy(), np.eye(3)
            for ch in self.chans[k]:
                v = row[c]; c += 1
                if ch.endswith("position"):
                    loc["XYZ".index(ch[0])] = v
                else:
                    rot = rot @ _rot(ch[0], v)
            p = self.parent[k]
            if p < 0:
                P[k], R[k] = loc, rot
            else:
                P[k], R[k] = P[p] + R[p] @ loc, R[p] @ rot
        return P, R

    def end_pos(self, P, R, name):
        k = self.idx[name]
        return P[k] + R[k] @ self.ends[k]

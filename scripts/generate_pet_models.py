#!/usr/bin/env python3
"""竹笌宠物换装 - 小狗模型 + 5种毛色 + 走路动画"""

import struct, json, os, glob
import numpy as np
import trimesh
import trimesh.creation
import trimesh.transformations as tf

OUT = "/root/.openclaw/workspace/zhuya-yinyue/assets/vrm_test/pet_system"
os.makedirs(OUT, exist_ok=True)

# ── 工具 ──────────────────────────────────────────────────
def mesh_color(m, r, g, b, a=1.0):
    n = len(m.vertices)
    m.visual.vertex_colors = np.tile(
        np.array([r, g, b, a], dtype=np.uint8) * 255, (n, 1))
    return m

def merge(*mlist):
    return trimesh.util.concatenate(mlist) if mlist else None

def save(m, name):
    if m is None: return
    p = os.path.join(OUT, name)
    m.export(p, file_type="glb")
    print(f"  ✅ {name}  ({os.path.getsize(p)//1024} KB)")

# ── 狗部件工厂 ────────────────────────────────────────────
def dog_body(bc, sc=None):
    """bc=体色, sc=斑点色"""
    parts = []
    def a(sh, *c): parts.append(mesh_color(sh, *c))

    # 身体
    b = trimesh.creation.icosphere(subdivisions=4, radius=0.22)
    b.apply_scale([1.4, 0.9, 1.1])
    b.apply_transform(tf.translation_matrix([0, 0.30, 0]))
    a(b, *bc)

    # 头部
    h = trimesh.creation.icosphere(subdivisions=4, radius=0.18)
    h.apply_scale([1.1, 1.0, 1.0])
    h.apply_transform(tf.translation_matrix([0, 0.68, 0.04]))
    a(h, *bc)

    # 口鼻
    sn = trimesh.creation.icosphere(subdivisions=3, radius=0.08)
    sn.apply_scale([1.2, 0.7, 1.4])
    sn.apply_transform(tf.translation_matrix([0, 0.64, 0.20]))
    a(sn, *bc)

    # 鼻子
    nz = trimesh.creation.icosphere(subdivisions=2, radius=0.028)
    nz.apply_transform(tf.translation_matrix([0, 0.66, 0.28]))
    a(nz, 0.12, 0.10, 0.10, 1.0)

    # 眼睛
    for s in [-1, 1]:
        e = trimesh.creation.icosphere(subdivisions=2, radius=0.022)
        e.apply_transform(tf.translation_matrix([s*0.10, 0.72, 0.16]))
        a(e, 0.06, 0.06, 0.06, 1.0)
        hl = trimesh.creation.icosphere(subdivisions=1, radius=0.007)
        hl.apply_transform(tf.translation_matrix([s*0.10+0.004, 0.73, 0.18]))
        a(hl, 1.0, 1.0, 1.0, 1.0)

    # 耳朵
    for s in [-1, 1]:
        er = trimesh.creation.icosphere(subdivisions=3, radius=0.08)
        er.apply_scale([0.7, 1.3, 0.5])
        er.apply_transform(tf.translation_matrix([s*0.16, 0.78, -0.02]))
        a(er, *bc)

    # 尾巴（卷卷的，多节）
    for i in range(6):
        r2 = 0.055 - i*0.005
        seg = trimesh.creation.icosphere(subdivisions=2, radius=r2)
        ang = 0.4 + i*0.22
        seg.apply_transform(tf.translation_matrix([
            np.sin(ang)*(i+1)*0.038,
            0.38 + i*0.022,
            -0.22 - i*0.022
        ]))
        a(seg, *bc)

    # 四条腿
    for lx, lz in [(-0.12, 0.10), (0.12, 0.10), (-0.12, -0.10), (0.12, -0.10)]:
        th = trimesh.creation.capsule(radius=0.055, height=0.083)
        th.apply_transform(tf.translation_matrix([lx, 0.18, lz]))
        a(th, *bc)
        sh2 = trimesh.creation.capsule(radius=0.042, height=0.068)
        sh2.apply_transform(tf.translation_matrix([lx, 0.115, lz]))
        a(sh2, *bc)
        ft = trimesh.creation.icosphere(subdivisions=2, radius=0.04)
        ft.apply_scale([1.2, 0.6, 1.4])
        ft.apply_transform(tf.translation_matrix([lx, 0.085, lz]))
        a(ft, *bc)

    # 斑点
    if sc:
        s1 = trimesh.creation.icosphere(subdivisions=3, radius=0.07)
        s1.apply_transform(tf.translation_matrix([0.14, 0.34, 0.05]))
        a(s1, *sc)
        s2 = trimesh.creation.icosphere(subdivisions=3, radius=0.05)
        s2.apply_transform(tf.translation_matrix([-0.10, 0.26, 0.10]))
        a(s2, *sc)

    return merge(*parts) if parts else None

# ── glTF 手工构建（支持走路动画） ─────────────────────────
class GB:
    def __init__(self):
        self.md = []; self.nd = []; self.an = []
        self._ni = {}; self.acc = []; self.bv = []

    def nd_add(self, nm, mk=None, tr=None, ch=None):
        i = len(self.nd); self._ni[nm] = i
        n = {"name": nm}
        if mk is not None:
            self.md.append(mk); n["mesh"] = len(self.md)-1
        if tr is not None: n["translation"] = tr
        if ch is not None: n["children"] = ch
        self.nd.append(n); return i

    def save(self, path):
        bufs = []
        def BV(blob, tgt=None):
            o = sum(len(b) for b in bufs)
            bufs.append(blob)
            i = len(self.bv)
            self.bv.append({"buffer":0,"byteOffset":o,"byteLength":len(blob),"target":tgt})
            return i
        def AC(bvi, cnt, cmp=5126, tp="VEC3"):
            self.acc.append({"bufferView":bvi,"byteOffset":0,
                              "componentType":cmp,"count":cnt,"type":tp})
            return len(self.acc)-1

        mj = []
        for m in self.md:
            pos = m.vertices.astype('<f4')
            fn  = m.face_normals.astype('<f4')
            vc  = np.asarray(m.visual.vertex_colors)
            if vc.shape[1]==3: vc=np.pad(vc,((0,0),(0,1)),constant_values=255)
            col = (vc[:,:4]/255.0).astype('<f4')
            idx = np.asarray(m.faces, dtype=np.uint32)
            pb=BV(pos.tobytes(),34962); fb=BV(fn.tobytes(),34962)
            cb=BV(col.tobytes(),34962); ib=BV(idx.tobytes(),34963)
            pa=AC(pb,len(pos)); fa=AC(fb,len(fn)); ca=AC(cb,len(col)); ia=AC(ib,len(idx),5125,"SCALAR")
            mj.append({"primitives":[{"attributes":{"POSITION":pa,"NORMAL":fa,"COLOR_0":ca},
                                       "indices":ia,"mode":4}]})

        bin_blob = b''.join(bufs)
        if len(bin_blob)%4: bin_blob += b'\x00'*(4-len(bin_blob)%4)
        gj = json.dumps({
            "asset":{"version":"2.0","generator":"ZhuyaPet v1"},
            "scene":0,"scenes":[{"nodes":[len(self.nd)]}],
            "nodes":self.nd + [{"name":"Root","children":list(range(len(self.nd)))}],
            "meshes":mj,
            "buffers":[{"byteLength":len(bin_blob)}],
            "bufferViews":self.bv,
            "accessors":self.acc,
            **({"animations":self.an} if self.an else {}),
        }, separators=(',',':'))
        gj_b = gj.encode()
        total = 12+8+len(gj_b)+8+len(bin_blob)
        res = bytearray(total)
        res[0:4]=b'glTF'; struct.pack_into('<I',res,4,2)
        struct.pack_into('<I',res,8,total-12)
        res[12:20]=b'JSON'; struct.pack_into('<I',res,20,len(gj_b))
        res[20:20+len(gj_b)]=gj_b
        bi = 20+len(gj_b)
        while bi%4: bi+=1
        res[bi:bi+4]=b'BIN'; struct.pack_into('<I',res,bi+4,len(bin_blob))
        with open(path,'wb') as f: f.write(bytes(res))
        print(f"  ✅ {os.path.basename(path)}  ({os.path.getsize(path)//1024} KB)")

    def walk(self, nm_map, fps=30, dur=0.8):
        nf = int(fps*dur); sam=[]; chs=[]
        for nm,cfg in nm_map.items():
            if nm not in self._ni: continue
            ni=self._ni[nm]; ax=cfg.get('axis','y'); am=cfg.get('amp',20); ph=cfg.get('phase',0)
            ts=[]; vs=[]
            for f in range(nf+1):
                t=f/fps; a=am*np.pi/180*np.sin(2*np.pi*t/dur+ph)
            if ax=='x': r=tf.rotation_matrix(a,[1,0,0])
            elif ax=='y': r=tf.rotation_matrix(a,[0,1,0])
            else: r=tf.rotation_matrix(a,[0,0,1])
        if sam: self.an.append({"name":"Walk","samplers":sam,"channels":chs})

def BV(blob, tgt=None):
    o=sum(len(b) for b in _bufs) if '_bufs' in globals() else 0
    _bufs.append(blob)
    i=len(_bvs); _bvs.append({"buffer":0,"byteOffset":o,"byteLength":len(blob),"target":tgt})
    return i
def AC(bvi,cnt,cmp=5126,tp="VEC3"):
    _acs.append({"bufferView":bvi,"byteOffset":0,"componentType":cmp,"count":cnt,"type":tp})
    return len(_acs)-1

def build_dog_glb(color_id, bc, sc=None):
    """用 trimesh.Scene 导出含走路动画的 GLB"""
    global _bufs, _bvs, _acs
    _bufs=[]; _bvs=[]; _acs=[]

    parts = []
    def a(sh,*c):
        s=sh.copy()
        n=len(s.vertices)
        s.visual.vertex_colors=np.tile(np.array(c,dtype=np.uint8)*255,(n,1))
        parts.append(s)

    # 身体
    b=trimesh.creation.icosphere(subdivisions=4,radius=0.22)
    b.apply_scale([1.4,0.9,1.1])
    b.apply_transform(tf.translation_matrix([0,0.30,0])); a(b,*bc)
    h=trimesh.creation.icosphere(subdivisions=4,radius=0.18)
    h.apply_scale([1.1,1.0,1.0])
    h.apply_transform(tf.translation_matrix([0,0.68,0.04])); a(h,*bc)
    sn=trimesh.creation.icosphere(subdivisions=3,radius=0.08)
    sn.apply_scale([1.2,0.7,1.4])
    sn.apply_transform(tf.translation_matrix([0,0.64,0.20])); a(sn,*bc)
    nz=trimesh.creation.icosphere(subdivisions=2,radius=0.028)
    nz.apply_transform(tf.translation_matrix([0,0.66,0.28])); a(nz,0.12,0.10,0.10)
    for s in [-1,1]:
        e=trimesh.creation.icosphere(subdivisions=2,radius=0.022)
        e.apply_transform(tf.translation_matrix([s*0.10,0.72,0.16])); a(e,0.06,0.06,0.06)
        hl=trimesh.creation.icosphere(subdivisions=1,radius=0.007)
        hl.apply_transform(tf.translation_matrix([s*0.10+0.004,0.73,0.18])); a(hl,1,1,1)
    for s in [-1,1]:
        er=trimesh.creation.icosphere(subdivisions=3,radius=0.08)
        er.apply_scale([0.7,1.3,0.5])
        er.apply_transform(tf.translation_matrix([s*0.16,0.78,-0.02])); a(er,*bc)
    for i in range(6):
        r2=0.055-i*0.005; seg=trimesh.creation.icosphere(subdivisions=2,radius=r2)
        ang=0.4+i*0.22
        seg.apply_transform(tf.translation_matrix([np.sin(ang)*(i+1)*0.038,0.38+i*0.022,-0.22-i*0.022]))
        a(seg,*bc)
    for lx,lz in [(-0.12,0.10),(0.12,0.10),(-0.12,-0.10),(0.12,-0.10)]:
        th=trimesh.creation.capsule(radius=0.055,height=0.083)
        th.apply_transform(tf.translation_matrix([lx,0.18,lz])); a(th,*bc)
        sh2=trimesh.creation.capsule(radius=0.042,height=0.068)
        sh2.apply_transform(tf.translation_matrix([lx,0.115,lz])); a(sh2,*bc)
        ft=trimesh.creation.icosphere(subdivisions=2,radius=0.04)
        ft.apply_scale([1.2,0.6,1.4])
        ft.apply_transform(tf.translation_matrix([lx,0.085,lz])); a(ft,*bc)
    if sc:
        s1=trimesh.creation.icosphere(subdivisions=3,radius=0.07)
        s1.apply_transform(tf.translation_matrix([0.14,0.34,0.05])); a(s1,*sc)
        s2=trimesh.creation.icosphere(subdivisions=3,radius=0.05)
        s2.apply_transform(tf.translation_matrix([-0.10,0.26,0.10])); a(s2,*sc)

    # ── 多节点 + 走路动画 ─────────────────────────────────
    bufs=[]; bvs=[]; acs=[]; md=[]
    def bv2(blob,tgt=None):
        o=sum(len(x)for x in bufs); bufs.append(blob)
        i=len(bvs); bvs.append({"buffer":0,"byteOffset":o,"byteLength":len(blob),"target":tgt})
        return i
    def ac2(bvi,cnt,cmp=5126,tp="VEC3"):
        acs.append({"bufferView":bvi,"byteOffset":0,"componentType":cmp,"count":cnt,"type":tp})
        return len(acs)-1

    mj=[]
    for m in parts:
        pos=m.vertices.astype('<f4'); fn=m.face_normals.astype('<f4')
        vc=np.asarray(m.visual.vertex_colors)
        if vc.shape[1]==3: vc=np.pad(vc,((0,0),(0,1)),constant_values=255)
        col=(vc[:,:4]/255.0).astype('<f4')
        idx=np.asarray(m.faces,dtype=np.uint32)
        pb=bv2(pos.tobytes(),34962); fb=bv2(fn.tobytes(),34962)
        cb=bv2(col.tobytes(),34962); ib=bv2(idx.tobytes(),34963)
        pa=ac2(pb,len(pos)); fa=ac2(fb,len(fn)); ca=ac2(cb,len(col)); ia=ac2(ib,len(idx),5125,"SCALAR")
        mj.append({"primitives":[{"attributes":{"POSITION":pa,"NORMAL":fa,"COLOR_0":ca},
                                   "indices":ia,"mode":4}]})
        md.append(m)

    # 节点层级（Root → body → 头/耳/尾/腿）
    nd=[{"name":"Body","translation":[0,0,0]}]
    ni={"Body":0}
    def add_nd(nm,tr,parent=None):
        i=len(nd); ni[nm]=i
        n2={"name":nm,"translation":tr}
        nd.append(n2)
        if parent is not None and parent in ni:
            p=nd[ni[parent]].get("children",[])
            p.append(i); nd[ni[parent]]["children"]=p
        return i

    add_nd("Head",   [0,0.68,0.04],       "Body")
    add_nd("LeftEar", [-0.16,0.78,-0.02], "Body")
    add_nd("RightEar",[0.16,0.78,-0.02],  "Body")
    add_nd("Tail",   [0,0.38,-0.22],      "Body")
    for nm2,tr2 in [
        ("LF_up",[-0.12,0.18,0.10]),("RF_up",[0.12,0.18,0.10]),
        ("LB_up",[-0.12,0.18,-0.10]),("RB_up",[0.12,0.18,-0.10]),
    ]:
        add_nd(nm2,tr2,"Body")

    # 走路动画
    nf=int(30*0.8); sam=[]; chs=[]
    leg_walk={
        "LF_up":('z',18,0),   "RF_up":('z',18,np.pi),
        "LB_up":('z',18,np.pi),  "RB_up":('z',18,0),
        "Tail":('y',35,0), "Body":('y',4,0),
    }
    for nm2,cfg2 in leg_walk.items():
        if nm2 not in ni: continue
        ax,am,ph=cfg2
        ts=[]; vs=[]
        for f in range(nf+1):
            t=f/30; a=am*np.pi/180*np.sin(2*np.pi*t/0.8+ph)
            if ax=='x': r=tf.rotation_matrix(a,[1,0,0])
            elif ax=='y': r=tf.rotation_matrix(a,[0,1,0])
            else: r=tf.rotation_matrix(a,[0,0,1])
        tb=bv2(np.array(ts,dtype='<f4').tobytes()); ta=ac2(tb,len(ts),5126,"SCALAR")
        rb=bv2(np.array(vs,dtype='<f4').tobytes()); ra=ac2(rb,len(vs),5126,"VEC4")
        si=len(sam); sam.append({"input":ta,"output":ra,"interpolation":"LINEAR"})
        chs.append({"sampler":si,"target":{"node":ni[nm2],"path":"rotation"}})

    bin_blob=b''.join(bufs)
    if len(bin_blob)%4: bin_blob+=b'\x00'*(4-len(bin_blob)%4)
    gj=json.dumps({
        "asset":{"version":"2.0","generator":"ZhuyaPet v1"},
        "scene":0,"scenes":[{"nodes":[len(nd)]}],
        "nodes":nd+[{"name":"Root","children":list(range(len(nd)))}],
        "meshes":mj,
        "buffers":[{"byteLength":len(bin_blob)}],
        "bufferViews":bvs,
        "accessors":acs,
        "animations":[{"name":"Walk","samplers":sam,"channels":chs}] if sam else [],
    },separators=(',',':')).encode()
    total=12+8+len(gj)+8+len(bin_blob)
    res=bytearray(total)
    res[0:4]=b'glTF'; struct.pack_into('<I',res,4,2)
    struct.pack_into('<I',res,8,total-12)
    res[12:20]=b'JSON'; struct.pack_into('<I',res,20,len(gj))
    res[20:20+len(gj)]=gj
    bi=20+len(gj); res[bi:bi+4]=b'BIN'
    struct.pack_into('<I',res,bi+4,len(bin_blob))
    p=os.path.join(OUT,f"dog_{color_id}.glb")
    with open(p,'wb') as f: f.write(bytes(res))
    print(f"  ✅ dog_{color_id}.glb  ({os.path.getsize(p)//1024} KB)")


if __name__ == "__main__":
    print("="*55)
    print("🐕 竹笌宠物换装系统 - 小狗毛色 + 走路动画")
    print("="*55)
    for f in glob.glob(f"{OUT}/*.glb"): os.remove(f)
    print("  🗑 清理旧文件\n")

    variants = [
        ("brown",  (0.46,0.26,0.10), None),
        ("golden", (0.88,0.66,0.24), None),
        ("black",  (0.08,0.07,0.07), None),
        ("white",  (0.97,0.96,0.95), None),
        ("spotted",(0.95,0.92,0.85), (0.20,0.14,0.08)),
    ]

    for vid,bc,sc in variants:
        print(f"📦 {vid}...")
        build_dog_glb(vid, bc, sc)

    manifest = {
        "type":"pet","name":"小狗","petType":"dog",
        "variants":[{"id":v[0],"name":v[0],"file":f"dog_{v[0]}.glb"}
                    for v in variants],
    }
    with open(f"{OUT}/manifest.json","w",encoding="utf-8") as f:
        json.dump(manifest,f,ensure_ascii=False,indent=2)
    print(f"\n  ✅ manifest.json")

    files=glob.glob(f"{OUT}/*.glb")
    print(f"\n{'='*55}")
    print(f"✅ 完成！{len(files)} 个 GLB")
    print(f"📂 {OUT}")
    print(f"{'='*55}")

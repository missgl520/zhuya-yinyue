#!/usr/bin/env python3
"""
竹笌 · 骨骼动画生成器
"""
import json, struct, math, os, sys
import numpy as np
import trimesh
from pathlib import Path

OUT_DIR = Path('/root/.openclaw/workspace/zhuya-yinyue/assets/3d/models')

# ─── 骨骼定义 ───────────────────────────────────────────────────────
BONES = {
    'Root':       ( 0.00, -1.50,  0.00),
    'Spine':      ( 0.00, -0.90,  0.00),
    'Chest':      ( 0.00, -0.20,  0.00),
    'Neck':       ( 0.00,  0.25,  0.00),
    'Head':       ( 0.00,  0.50,  0.00),
    'L_Shoulder': (-0.40,  0.00,  0.00),
    'R_Shoulder': ( 0.40,  0.00,  0.00),
    'L_Elbow':    (-0.55, -0.45,  0.00),
    'R_Elbow':    ( 0.55, -0.45,  0.00),
    'L_Hand':     (-0.55, -0.80,  0.00),
    'R_Hand':     ( 0.55, -0.80,  0.00),
    'L_Hip':      (-0.18, -1.50,  0.00),
    'R_Hip':      ( 0.18, -1.50,  0.00),
    'L_Knee':     (-0.18, -1.00,  0.00),
    'R_Knee':     ( 0.18, -1.00,  0.00),
    'L_Foot':     (-0.18, -1.98,  0.00),
    'R_Foot':     ( 0.18, -1.98,  0.00),
    'Tail1':      ( 0.00, -1.50, -0.20),
    'Tail2':      ( 0.00, -1.70, -0.40),
    'Tail3':      ( 0.00, -1.85, -0.50),
}
BONE_HIERARCHY = [
    ('Root', None), ('Spine', 'Root'), ('Chest', 'Spine'),
    ('Neck', 'Chest'), ('Head', 'Neck'),
    ('L_Shoulder', 'Chest'), ('R_Shoulder', 'Chest'),
    ('L_Elbow', 'L_Shoulder'), ('R_Elbow', 'R_Shoulder'),
    ('L_Hand', 'L_Elbow'), ('R_Hand', 'R_Elbow'),
    ('L_Hip', 'Root'), ('R_Hip', 'Root'),
    ('L_Knee', 'L_Hip'), ('R_Knee', 'R_Hip'),
    ('L_Foot', 'L_Knee'), ('R_Foot', 'R_Knee'),
    ('Tail1', 'Root'), ('Tail2', 'Tail1'), ('Tail3', 'Tail2'),
]
BONE_INDEX = {n: i for i, (n, _) in enumerate(BONE_HIERARCHY)}
N_BONES = len(BONE_INDEX)

# ─── 辅助函数 ───────────────────────────────────────────────────────
def trs_to_mat(t=(0,0,0), r=(0,0,0)):
    cx,sx=math.cos(r[0]),math.sin(r[0])
    cy,sy=math.cos(r[1]),math.sin(r[1])
    cz,sz=math.cos(r[2]),math.sin(r[2])
    m=np.eye(4,dtype=np.float32)
    m[0,0]=cy*cz; m[0,1]=sx*sy*cz-cx*sz; m[0,2]=cx*sy*cz+sx*sz
    m[1,0]=cy*sz; m[1,1]=sx*sy*sz+cx*cz; m[1,2]=cx*sy*sz-sx*cz
    m[2,0]=-sy;   m[2,1]=sx*cy;         m[2,2]=cx*cy
    m[:3,3]=t; m[3,:]=[0,0,0,1]
    return m

def build_bind_inverse(bone_name, parent_name):
    pos = BONES[bone_name]
    m = trs_to_mat(t=pos)
    if parent_name:
        p_pos = BONES[parent_name]
        p_inv = np.linalg.inv(trs_to_mat(t=p_pos))
        m = p_inv @ m
    return np.linalg.inv(m).T  # 列主序

def euler_to_quat(rx, ry, rz):
    cx,sx=math.cos(rx/2),math.sin(rx/2)
    cy,sy=math.cos(ry/2),math.sin(ry/2)
    cz,sz=math.cos(rz/2),math.sin(rz/2)
    w=cx*cy*cz-sx*sy*sz; x=sx*cy*cz+cx*sy*sz
    y=cx*sy*cz-sx*cy*sz; z=cx*cy*sz+sx*sy*cz
    return [x,y,z,w]

def compute_normals(vertices, indices):
    n = np.zeros_like(vertices)
    for i in range(0,len(indices),3):
        a,b,c=indices[i],indices[i+1],indices[i+2]
        e1=vertices[b]-vertices[a]; e2=vertices[c]-vertices[a]
        nn=np.cross(e1,e2)
        for vi in(a,b,c): n[vi]+=nn
    norms=np.linalg.norm(n,axis=1,keepdims=True); norms[norms==0]=1
    return n/norms

# ─── 蒙皮权重 ───────────────────────────────────────────────────────
def compute_skin_weights(vertices):
    N=len(vertices)
    bone_ranges={
        'Head':       ( 0.20,  0.80,  0,  0),
        'Neck':       ( 0.10,  0.40,  0,  0),
        'Chest':      (-0.40,  0.25,  0,  0),
        'Spine':      (-1.20, -0.25,  0,  0),
        'L_Shoulder': (-0.20,  0.20, -1,  0.30),
        'R_Shoulder': (-0.20,  0.20,  1,  0.30),
        'L_Elbow':    (-0.75, -0.20, -1,  0.10),
        'R_Elbow':    (-0.75, -0.20,  1,  0.10),
        'L_Hand':     (-1.10, -0.75, -1,  0.10),
        'R_Hand':     (-1.10, -0.75,  1,  0.10),
        'L_Hip':      (-1.75, -1.35, -1,  0.10),
        'R_Hip':      (-1.75, -1.35,  1,  0.10),
        'L_Knee':     (-1.35, -1.05, -1,  0.10),
        'R_Knee':     (-1.35, -1.05,  1,  0.10),
        'L_Foot':     (-2.05, -1.65, -1,  0.10),
        'R_Foot':     (-2.05, -1.65,  1,  0.10),
        'Tail1':      (-1.75, -1.40,  0, -0.15),
        'Tail2':      (-1.90, -1.65,  0, -0.35),
        'Tail3':      (-2.05, -1.80,  0, -0.45),
    }
    raw_w={}
    for bone,(y_lo,y_hi,x_side,x_abs) in bone_ranges.items():
        y_d=np.maximum(0,np.maximum(y_lo-vertices[:,1],vertices[:,1]-y_hi))
        if x_side!=0:
            x_m=vertices[:,0]*x_side
            x_d=np.where(x_m>x_abs,np.maximum(0,x_m-x_abs),999.0)
            d=y_d+x_d*0.5
        elif x_abs<0:
            z_d=np.maximum(0,-(vertices[:,2]+x_abs))
            d=y_d+z_d*0.6
        else:
            d=y_d
        raw_w[bone]=np.exp(-d**2/0.30**2)
    joints=np.zeros((N,4),dtype=np.uint8)
    weights=np.zeros((N,4),dtype=np.float32)
    for i in range(N):
        scored=[(BONE_INDEX[b],raw_w[b][i]) for b in raw_w if raw_w[b][i]>0.005]
        scored.sort(key=lambda x:-x[1])
        scored=scored[:4]
        total=sum(w for _,w in scored) or 1.0
        for col,(bi,w) in enumerate(scored):
            joints[i,col]=bi; weights[i,col]=w/total
    return joints,weights

# ─── 动画关键帧 ─────────────────────────────────────────────────────
def make_idle_keyframes(n=20,fps=10):
    frames=[]
    for i in range(n):
        t=i/fps
        b=0.02*math.sin(2*math.pi*t*1.5)
        hn=0.03*math.sin(2*math.pi*t*1.5)
        tw=0.15*math.sin(2*math.pi*t*2)
        frames.append({'time':t,'bones':{
            'Root':{'t':[0,0,0],'r':[0,0,0]},
            'Spine':{'t':[0,0,0],'r':[b*0.3,0,0]},
            'Chest':{'t':[0,b,0],'r':[b,0,0]},
            'Neck':{'t':[0,0,0],'r':[-hn,0,0]},
            'Head':{'t':[0,0,0],'r':[-hn*0.5,0,0]},
            'L_Shoulder':{'t':[0,0,0],'r':[0,0, 0.05+b*0.2]},
            'R_Shoulder':{'t':[0,0,0],'r':[0,0,-0.05-b*0.2]},
            'L_Elbow':{'t':[0,0,0],'r':[-0.05,0,0]},
            'R_Elbow':{'t':[0,0,0],'r':[-0.05,0,0]},
            'L_Hand':{'t':[0,0,0],'r':[0,0,0]},
            'R_Hand':{'t':[0,0,0],'r':[0,0,0]},
            'L_Hip':{'t':[0,0,0],'r':[0,0,0]},
            'R_Hip':{'t':[0,0,0],'r':[0,0,0]},
            'L_Knee':{'t':[0,0,0],'r':[0,0,0]},
            'R_Knee':{'t':[0,0,0],'r':[0,0,0]},
            'L_Foot':{'t':[0,0,0],'r':[0,0,0]},
            'R_Foot':{'t':[0,0,0],'r':[0,0,0]},
            'Tail1':{'t':[0,0,0],'r':[0,tw,0]},
            'Tail2':{'t':[0,0,0],'r':[0,tw*1.3,0]},
            'Tail3':{'t':[0,0,0],'r':[0,tw*1.6,0]},
        }})
    return frames

def make_walk_keyframes(n=24,fps=12):
    frames=[]
    for i in range(n):
        t=i/n; ph=t*2*math.pi
        la=0.5*math.sin(ph); ra=-0.5*math.sin(ph)
        ll=-0.4*math.sin(ph); rl=0.4*math.sin(ph)
        lk=max(0,-ll)*0.6; rk=max(0,rl)*0.6
        by=0.04*abs(math.sin(ph))
        bt=0.04*math.sin(ph)
        hn=-0.05*abs(math.sin(ph))
        tw=0.2*math.sin(ph*2)
        frames.append({'time':t*(n/fps),'bones':{
            'Root':{'t':[0,by,0],'r':[0,0,bt]},
            'Spine':{'t':[0,0,0],'r':[0,0,0]},
            'Chest':{'t':[0,0,0],'r':[0,0,0]},
            'Neck':{'t':[0,0,0],'r':[hn,0,0]},
            'Head':{'t':[0,0,0],'r':[hn*0.5,0,0]},
            'L_Shoulder':{'t':[0,0,0],'r':[la*0.3,0,la]},
            'R_Shoulder':{'t':[0,0,0],'r':[ra*0.3,0,ra]},
            'L_Elbow':{'t':[0,0,0],'r':[-la*0.2,0,0]},
            'R_Elbow':{'t':[0,0,0],'r':[-ra*0.2,0,0]},
            'L_Hand':{'t':[0,0,0],'r':[0,0,0]},
            'R_Hand':{'t':[0,0,0],'r':[0,0,0]},
            'L_Hip':{'t':[0,0,0],'r':[0,0,0]},
            'R_Hip':{'t':[0,0,0],'r':[0,0,0]},
            'L_Knee':{'t':[0,0,0],'r':[-lk,0,0]},
            'R_Knee':{'t':[0,0,0],'r':[-rk,0,0]},
            'L_Foot':{'t':[0,0,0],'r':[ll*0.2,0,0]},
            'R_Foot':{'t':[0,0,0],'r':[rl*0.2,0,0]},
            'Tail1':{'t':[0,0,0],'r':[0,tw,0]},
            'Tail2':{'t':[0,0,0],'r':[0,tw*1.3,0]},
            'Tail3':{'t':[0,0,0],'r':[0,tw*1.6,0]},
        }})
    return frames

def make_wave_keyframes(n=20,fps=10):
    frames=[]
    for i in range(n):
        t=i/n; ph=t*2*math.pi
        ra=0.6*math.sin(ph*3)+0.4; re=-0.3*math.sin(ph*3)
        la=0.1*math.sin(ph); le=-0.05
        sy=0.15*math.sin(ph*3); bt=0.05*math.cos(ph*3)
        hy=-0.15*abs(math.sin(ph*3))
        tw=0.25*math.sin(ph*4)
        by=0.02*math.sin(ph*2)
        frames.append({'time':t*(n/fps),'bones':{
            'Root':{'t':[0,by,0],'r':[0,sy,bt]},
            'Spine':{'t':[0,0,0],'r':[0,0,0]},
            'Chest':{'t':[0,0,0],'r':[0,0,0]},
            'Neck':{'t':[0,0,0],'r':[0,hy,0]},
            'Head':{'t':[0,0,0],'r':[0,hy*0.7,0]},
            'L_Shoulder':{'t':[0,0,0],'r':[la*0.2,0,la]},
            'R_Shoulder':{'t':[0,0,0],'r':[ra*0.2,0,ra]},
            'L_Elbow':{'t':[0,0,0],'r':[le,0,0]},
            'R_Elbow':{'t':[0,0,0],'r':[re,0,0]},
            'L_Hand':{'t':[0,0,0],'r':[0,0,0]},
            'R_Hand':{'t':[0,0,0],'r':[0,0,0]},
            'L_Hip':{'t':[0,0,0],'r':[0,0,0]},
            'R_Hip':{'t':[0,0,0],'r':[0,0,0]},
            'L_Knee':{'t':[0,0,0],'r':[0,0,0]},
            'R_Knee':{'t':[0,0,0],'r':[0,0,0]},
            'L_Foot':{'t':[0,0,0],'r':[0,0,0]},
            'R_Foot':{'t':[0,0,0],'r':[0,0,0]},
            'Tail1':{'t':[0,0,0],'r':[0,tw,0]},
            'Tail2':{'t':[0,0,0],'r':[0,tw*1.3,0]},
            'Tail3':{'t':[0,0,0],'r':[0,tw*1.6,0]},
        }})
    return frames

def make_jump_keyframes(n=24,fps=12):
    frames=[]
    for i in range(n):
        t=i/n
        if t<0.2:
            sq=t/0.2; yo=-0.05*sq; sb=sq*0.05; au=sq*0.3
        elif t<0.8:
            air=(t-0.2)/0.6; yo=0.12*math.sin(air*math.pi); sb=0; au=0.4+0.2*math.sin(air*math.pi)
        else:
            ld=(t-0.8)/0.2; yo=-0.02*(1-ld); sb=(1-ld)*0.05; au=0.1*(1-ld)
        frames.append({'time':t*(n/fps),'bones':{
            'Root':{'t':[0,yo,0],'r':[0,0,0]},
            'Spine':{'t':[0,0,0],'r':[sb,0,0]},
            'Chest':{'t':[0,0,0],'r':[-sb*0.5,0,0]},
            'Neck':{'t':[0,0,0],'r':[0,0,0]},
            'Head':{'t':[0,0,0],'r':[0,0,0]},
            'L_Shoulder':{'t':[0,0,0],'r':[-au,0,0.1]},
            'R_Shoulder':{'t':[0,0,0],'r':[-au,0,-0.1]},
            'L_Elbow':{'t':[0,0,0],'r':[-au*0.5,0,0]},
            'R_Elbow':{'t':[0,0,0],'r':[-au*0.5,0,0]},
            'L_Hand':{'t':[0,0,0],'r':[0,0,0]},
            'R_Hand':{'t':[0,0,0],'r':[0,0,0]},
            'L_Hip':{'t':[0,0,0],'r':[sb*0.5,0,0]},
            'R_Hip':{'t':[0,0,0],'r':[sb*0.5,0,0]},
            'L_Knee':{'t':[0,0,0],'r':[-sb*1.5,0,0]},
            'R_Knee':{'t':[0,0,0],'r':[-sb*1.5,0,0]},
            'L_Foot':{'t':[0,0,0],'r':[0,0,0]},
            'R_Foot':{'t':[0,0,0],'r':[0,0,0]},
            'Tail1':{'t':[0,0,0],'r':[0,0.1,0]},
            'Tail2':{'t':[0,0,0],'r':[0,0.15,0]},
            'Tail3':{'t':[0,0,0],'r':[0,0.2,0]},
        }})
    return frames

# ─── 构建 GLB ───────────────────────────────────────────────────────
def build_glb(vertices, indices, colors, joints, weights, animation_data):
    N=len(vertices); SCALE=0.35

    # 1. 二进制数据
    pos=(vertices.astype(np.float32)*SCALE)
    norms=compute_normals(vertices,indices).astype(np.float32)
    c=colors[:,:min(colors.shape[1],4)].astype(np.float32)
    if c.shape[1]==3: c=np.hstack([c,np.ones((N,1),np.float32)])
    jnt=joints.astype(np.uint16)
    wgt=weights.astype(np.float32)
    idx=indices.flatten().astype(np.uint32)

    chunks=[('pos',pos.tobytes()),('norm',norms.tobytes()),
             ('col',c.tobytes()),('jnt',jnt.tobytes()),
             ('wgt',wgt.tobytes()),('idx',idx.tobytes())]

    inv_list=[build_bind_inverse(n,p).flatten().tolist() for n,p in BONE_HIERARCHY]
    inv_b=np.array(inv_list,np.float32).tobytes()
    chunks.append(('inv',inv_b))

    # 字节偏移
    offs={}; cur=0
    for name,data in chunks:
        cur+=(4-cur%4)%4; offs[name]=cur; cur+=len(data)

    # 动画数据
    anim_meta=[]  # (anim_name, time_bytes, time_off, keyframes)
    for anim_name,keyframes in animation_data.items():
        times=[kf['time'] for kf in keyframes]
        t_b=np.array(times,np.float32).tobytes()
        cur+=(4-cur%4)%4; t_off=cur; cur+=len(t_b)
        anim_meta.append((anim_name,t_b,t_off,keyframes))

    total=cur

    # 2. 组装 buffer
    buf=bytearray(total)
    for name,data in chunks:
        buf[offs[name]:offs[name]+len(data)]=data
    for anim_name,t_b,t_off,keyframes in anim_meta:
        buf[t_off:t_off+len(t_b)]=t_b
        for bone_name,_ in BONE_HIERARCHY:
            kfs=[kf['bones'].get(bone_name,{'t':[0,0,0],'r':[0,0,0]}) for kf in keyframes]
            tr_b=np.array([kf['t'] for kf in kfs],np.float32).tobytes()
            cur+=(4-cur%4)%4; tr_off=cur; cur+=len(tr_b); buf[tr_off:tr_off+len(tr_b)]=tr_b
            quats=[euler_to_quat(*kf['r']) for kf in kfs]
            rt_b=np.array(quats,np.float32).tobytes()
            cur+=(4-cur%4)%4; rt_off=cur; cur+=len(rt_b); buf[rt_off:rt_off+len(rt_b)]=rt_b

    pad=(4-len(buf)%4)%4; buf.extend([0]*pad)

    # 3. Accessors + BufferViews
    acc=[]; views=[]
    def mk_view(bo,bl):
        views.append({'buffer':0,'byteOffset':bo,'byteLength':bl}); return len(views)-1
    def mk_acc(arr,comp,typ,vidx,cnt=None):
        cnt=(len(arr) if hasattr(arr,'__len__') else 1) if cnt is None else cnt
        mn=mx=None
        if arr is not None and hasattr(arr,'min'):
            if arr.ndim==1: mn=float(arr.min()); mx=float(arr.max())
            else: mn=arr.min(axis=0).tolist(); mx=arr.max(axis=0).tolist()
        acc.append({'bufferView':vidx,'componentType':comp,'count':cnt,'type':typ,'min':mn,'max':mx})
        return len(acc)-1

    acc_pos =mk_acc(pos,5126,'VEC3',mk_view(offs['pos'],len(chunks[0][1])))
    acc_norm=mk_acc(norms,5126,'VEC3',mk_view(offs['norm'],len(chunks[1][1])))
    acc_col =mk_acc(c,5126,'VEC4',mk_view(offs['col'],len(chunks[2][1])))
    acc_jnt =mk_acc(jnt,5123,'VEC4',mk_view(offs['jnt'],len(chunks[3][1])))
    acc_wgt =mk_acc(wgt,5126,'VEC4',mk_view(offs['wgt'],len(chunks[4][1])))
    acc_idx =mk_acc(idx,5125,'SCALAR',mk_view(offs['idx'],len(chunks[5][1])))
    acc_inv =mk_acc(np.array(inv_list,np.float32),5126,'MAT4',
                     mk_view(offs['inv'],len(inv_b)),cnt=N_BONES)

    # 4. Nodes + Skeleton
    nodes=[]; nm={}
    pending={n:[] for n,_ in BONE_HIERARCHY}
    for bn,pn in BONE_HIERARCHY:
        i=len(nodes); nm[bn]=i
        nodes.append({'name':bn,'translation':list(BONES[bn]),'rotation':[0,0,0,1],'scale':[1,1,1]})
        if pn: pending[pn].append(i)
    for j,(bn,_) in enumerate(BONE_HIERARCHY):
        if pending[bn]: nodes[j]['children']=pending[bn]
    mni=len(nodes)
    nodes.append({'name':'ChibiMesh','mesh':0,'skin':0,'translation':[0,0,0],'rotation':[0,0,0,1],'scale':[1,1,1]})
    nodes[nm['Root']].setdefault('children',[]).append(mni)
    skin={'name':'ChibiSkeleton','inverseBindMatrices':acc_inv,
          'skeleton':nm['Root'],'joints':[nm[n] for n,_ in BONE_HIERARCHY]}

    # 5. Animations
    anims_out=[]
    for anim_name,t_b,t_off,keyframes in anim_meta:
        times=[kf['time'] for kf in keyframes]
        kf_cnt=len(keyframes)
        channels=[]; samplers=[]

        t_vidx=mk_view(t_off,len(t_b))
        t_ac=mk_acc(np.array(times,np.float32),5126,'SCALAR',t_vidx)

        for bone_name,_ in BONE_HIERARCHY:
            node_idx=nm[bone_name]
            kfs=[kf['bones'].get(bone_name,{'t':[0,0,0],'r':[0,0,0]}) for kf in keyframes]

            tr_b=np.array([kf['t'] for kf in kfs],np.float32).tobytes()
            cur+=(4-cur%4)%4; tr_off=cur; cur+=len(tr_b)
            tr_vidx=mk_view(tr_off,len(tr_b))
            tr_ac=mk_acc(np.frombuffer(tr_b,np.float32).reshape(-1,3),5126,'VEC3',tr_vidx)

            quats=[euler_to_quat(*kf['r']) for kf in kfs]
            rt_b=np.array(quats,np.float32).tobytes()
            cur+=(4-cur%4)%4; rt_off=cur; cur+=len(rt_b)
            rt_vidx=mk_view(rt_off,len(rt_b))
            rt_ac=mk_acc(np.frombuffer(rt_b,np.float32).reshape(-1,4),5126,'VEC4',rt_vidx)

            si=len(samplers)
            samplers.append({'input':t_ac,'output':tr_ac,'interpolation':'LINEAR'})
            channels.append({'sampler':si,'target':{'node':node_idx,'path':'translation'}})

            si2=len(samplers)
            samplers.append({'input':t_ac,'output':rt_ac,'interpolation':'LINEAR'})
            channels.append({'sampler':si2,'target':{'node':node_idx,'path':'rotation'}})

        anims_out.append({'name':anim_name,'channels':channels,'samplers':samplers})

    # 6. Assemble GLTF
    prim={'attributes':{'POSITION':acc_pos,'NORMAL':acc_norm,'COLOR_0':acc_col,
                       'JOINTS_0':acc_jnt,'WEIGHTS_0':acc_wgt},
          'indices':acc_idx,'mode':4}
    gltf={'asset':{'version':'2.0','generator':'ChibiSkeleton/1.0'},
          'scene':0,'scenes':[{'name':'ChibiScene','nodes':[nm['Root']]}],
          'nodes':nodes,'meshes':[{'name':'ChibiBody','primitives':[prim]}],
          'skins':[skin],'animations':anims_out,
          'accessors':acc,'bufferViews':views,'buffers':[{'byteLength':len(buf)}]}

    # 7. Write GLB
    jb=json.dumps(gltf,separators=(',',':')).encode('utf-8')
    jp=(4-len(jb)%4)%4; jb+=b' '*jp
    glb=struct.pack('<III',0x46546C67,2,12+8+len(jb)+8+len(buf))
    glb+=struct.pack('<II',len(jb),0x4E4F5347)+jb
    glb+=struct.pack('<II',len(buf),0x004E4942)+bytes(buf)
    return glb

# ─── 主流程 ─────────────────────────────────────────────────────────
def main():
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument('--preset',choices=['default','cat_girl','dark','fairy'],default=None)
    parser.add_argument('--anim',choices=['idle','walk','wave','jump'],default=None)
    parser.add_argument('--out',default=str(OUT_DIR))
    args=parser.parse_args()
    presets=[args.preset] if args.preset else ['default','cat_girl','dark','fairy']
    anims=[args.anim] if args.anim else ['idle','walk','wave','jump']

    anim_fn={'idle':make_idle_keyframes,'walk':make_walk_keyframes,
             'wave':make_wave_keyframes,'jump':make_jump_keyframes}

    for preset in presets:
        glb_path=Path(args.out)/f'{preset}_anim.glb'
        static_glb=Path(args.out)/f'chibi_{preset}.glb'
        print(f'\n▶ {preset}')
        if not static_glb.exists():
            print(f'  ⚠️ {static_glb} 不存在，跳过'); continue

        scene=trimesh.load(str(static_glb))
        for geo in scene.geometry.values():
            verts=geo.vertices.copy()
            idxs=geo.faces.flatten()
            try:
                vcols=(geo.visual.vertex_colors[:,:3]/255.0).astype(np.float32)
            except:
                vcols=np.ones((len(verts),3),np.float32)*0.9
            break
        print(f'  顶点:{len(verts)} 面:{len(idxs)//3}')

        print('  计算蒙皮权重...')
        joints,wts=compute_skin_weights(verts)
        print(f'  平均影响骨骼数:{np.sum(wts>0.001,axis=1).mean():.1f}')

        print(f'  生成动画:{anims}')
        anim_data={an:anim_fn[an]() for an in anims}

        print('  打包 GLB...')
        glb_bytes=build_glb(verts,idxs,vcols,joints,wts,anim_data)
        with open(glb_path,'wb') as f: f.write(glb_bytes)
        print(f'  ✅ {glb_path} ({len(glb_bytes)/1024/1024:.1f}MB)')

    print('\n🎉 全部完成！')

if __name__=='__main__':
    main()

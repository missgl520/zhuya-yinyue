import json, re

for m in ["mtn_01", "mtn_02", "mtn_03"]:
    p = f"f:/zhuyapp/assets/live2d/ren_official/motions/{m}.motion3.json"
    d = json.load(open(p, encoding="utf-8"))
    print(f"\n=== {m} (dur={d.get('Meta',{}).get('Duration')}) ===")
    for c in d.get("Curves", []):
        cid = c.get("Id", "")
        if "Leg" not in cid:
            continue
        segs = c.get("Segments", [])
        # Cubism Segment is array form: [type, t0, v0, (cp...), t1, v1]
        # Extract all value fields (index 2, and 5/8 for bezier)
        vals = []
        for s in segs:
            if isinstance(s, list):
                # Linear [0, t0, v0, t1, v1] -> vals at index 2, 4
                # Bezier [1, t0, v0, c1t, c1v, c2t, c2v, t1, v1] -> vals at 2, 8
                # Stepped [2, t0, v0, t1, v1] -> 2, 4
                if len(s) >= 5:
                    vals.append(s[2])
                    vals.append(s[4])
                if len(s) >= 9:
                    vals.append(s[8])
        if vals:
            print(f"  {cid}: n_seg={len(segs)}  val_min={min(vals):.2f}  val_max={max(vals):.2f}  mean={sum(vals)/len(vals):.2f}  first6={[f'{v:.2f}' for v in vals[:6]]}")
        else:
            print(f"  {cid}: n_seg={len(segs)}  (no value extractable)")

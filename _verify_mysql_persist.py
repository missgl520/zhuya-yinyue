import os, hmac, hashlib, json, time, random, urllib.request

os.environ["ZHUYU_ENC_KEY"] = "VS2rzPsewS3A_lrfGQd4Gh9CHBksq8ngq97lVQ41Ih0="

API_KEY = "1668ce9bea0a9a8bfe32291788941e8359220f16f3dfb96b872f0c686b4eec44"
URL = "https://zhuyu-backend-297911-11-1432495298.sh.run.tcloudbase.com/chat/v2"
DB_URL = "mysql+pymysql://zhuya1:84kvHOCq7tRXg4uG@mysql3.sqlpub.com:3308/zhuya1"
USER_ID = f"persist-test-{random.randint(1000,9999)}"
MSG = "请背诵李白的《静夜思》"

# 1) 发送消息
body = json.dumps({"message": MSG}).encode()
ts = str(int(time.time()))
nonce = "".join(random.choices("abcdef0123456789", k=16))
canonical = f"POST\n/chat/v2\n{ts}\n{nonce}\n{hashlib.sha256(body).hexdigest()}"
sig = hmac.new(API_KEY.encode(), canonical.encode(), hashlib.sha256).hexdigest()
req = urllib.request.Request(URL, data=body, method="POST")
req.add_header("Content-Type", "application/json")
req.add_header("X-Api-Key", API_KEY)
req.add_header("X-Timestamp", ts)
req.add_header("X-Nonce", nonce)
req.add_header("X-Signature", sig)
req.add_header("X-User-Id", USER_ID)

print(f"Sending as {USER_ID}: {MSG}")
chunks = []
try:
    with urllib.request.urlopen(req, timeout=60) as r:
        for line in r:
            chunks.append(line.decode().strip())
except Exception as e:
    print(f"SSE FAIL: {e}")

# 只打印 text 事件
for ln in chunks:
    if ln.startswith("event:text"):
        print(ln)

# 2) 直连 MySQL 验证
from sqlalchemy import create_engine, text
engine = create_engine(DB_URL, pool_pre_ping=True)
with engine.connect() as conn:
    print("\n== memories 表 ==")
    rows = conn.execute(text("SELECT id, user_id, role, LEFT(content,80) as content FROM memories WHERE user_id=:u ORDER BY id DESC LIMIT 3"), {"u": USER_ID}).fetchall()
    if rows:
        for r in rows:
            print(dict(r._mapping))
    else:
        print("无记录（持久化可能失败或表未创建）")

    print("\n== affinity 表 ==")
    aff = conn.execute(text("SELECT * FROM affinity WHERE user_id=:u"), {"u": USER_ID}).fetchone()
    if aff:
        print(dict(aff._mapping))
    else:
        print("无好感度记录")

    print("\n== 表列表 ==")
    tables = conn.execute(text("SHOW TABLES")).fetchall()
    for t in tables:
        print(t[0])

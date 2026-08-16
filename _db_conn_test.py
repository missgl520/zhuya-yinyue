import os, sys
os.environ["ZHUYU_ENC_KEY"] = "VS2rzPsewS3A_lrfGQd4Gh9CHBksq8ngq97lVQ41Ih0="
os.environ["DATABASE_URL"] = "mysql+pymysql://zhuya1:84kvHOCq7tRXg4uG@mysql3.sqlpub.com:3308/zhuya1"

from sqlalchemy import create_engine, text
from config import settings

print(f"DATABASE_URL={settings.DATABASE_URL}")
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
try:
    with engine.connect() as conn:
        result = conn.execute(text("SELECT 1, VERSION()"))
        row = result.fetchone()
        print(f"DB OK: {row}")
except Exception as e:
    print(f"DB FAIL: {type(e).__name__}: {e}")
    sys.exit(1)

#!/usr/bin/env python3
# CI 自我清潔：Xcode 自動簽名每 run 開一張 "Created via API" DEVELOPMENT cert，
# 十幾個 run 就爆 Apple 配額（dev cert 上限 10）→ archive 紅。呢個 script 喺 archive 前清走垃圾。
import sys, time, json, urllib.request, urllib.parse

try:
    import jwt  # PyJWT
except ImportError:
    sys.exit("pyjwt missing")

import base64, os

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
key = base64.b64decode(os.environ["ASC_KEY_P8_B64"]).decode()

def tok():
    return jwt.encode({"iss": ISSUER_ID, "iat": int(time.time()), "exp": int(time.time()) + 900,
                       "aud": "appstoreconnect-v1"}, key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})

def api(method, path):
    req = urllib.request.Request(f"https://api.appstoreconnect.apple.com{path}", method=method,
                                 headers={"Authorization": f"Bearer {tok()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 204:
            return {}
        raise

data = api("GET", "/v1/certificates?limit=100")
junk = [c for c in data.get("data", [])
        if c["attributes"]["certificateType"] == "DEVELOPMENT"
        and c["attributes"].get("displayName", "") == "Created via API"]
print(f"junk CI dev certs: {len(junk)}")
for c in junk:
    api("DELETE", f"/v1/certificates/{c['id']}")
    print("revoked", c["id"])
print("done")

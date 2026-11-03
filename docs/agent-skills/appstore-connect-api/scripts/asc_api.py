#!/usr/bin/env python3
"""ASC API helper — JWT auth + api()/show(). Import from scripts, don't copy-edit.
Usage:
    import sys; sys.path.insert(0, '<this dir>')
    from asc_api import api, show
    s, d = api('GET', '/v1/apps?filter[bundleId]=com.example.app')
Requires PyJWT in the interpreter. Key/iss/kid below are this user's current
values — confirm ~/.hermes/secure/AuthKey_*.p8 still exists before use.
"""
import jwt, time, json, urllib.request, urllib.error

KEY_PATH = '/Users/simon/.hermes/secure/AuthKey_9V552N6G8U.p8'
ISS = '86743a9d-5f0a-46b8-a007-ae7ada62d54a'
KID = '9V552N6G8U'

_key = open(KEY_PATH).read()

def tok():
    return jwt.encode({'iss': ISS, 'iat': int(time.time()), 'exp': int(time.time()) + 1100,
                       'aud': 'appstoreconnect-v1'},
                      _key, algorithm='ES256', headers={'kid': KID, 'typ': 'JWT'})

def api(method, path, body=None):
    req = urllib.request.Request('https://api.appstoreconnect.apple.com' + path,
        data=json.dumps(body).encode() if body else None, method=method,
        headers={'Authorization': 'Bearer ' + tok(), 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.load(r) if r.status != 204 else {}
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read() or '{}')
        except Exception:
            return e.code, {}

def show(status, data, label=''):
    errs = data.get('errors') if isinstance(data, dict) else None
    if errs:
        print(label, status, json.dumps(errs, ensure_ascii=False)[:1500])
    else:
        print(label, status, 'OK')

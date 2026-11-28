# -*- coding: utf-8 -*-
import os,time,json,base64,urllib.request,urllib.error
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
KEYID=os.environ["ASC_KEY_ID"]; ISS=os.environ["ASC_ISSUER_ID"]; P8=os.environ["ASC_KEY_P8"]
def b64u(b): return base64.urlsafe_b64encode(b).rstrip(b'=')
key=serialization.load_pem_private_key(P8.encode(),password=None); now=int(time.time())
si=b64u(json.dumps({"alg":"ES256","kid":KEYID,"typ":"JWT"},separators=(",",":")).encode())+b"."+b64u(json.dumps({"iss":ISS,"iat":now,"exp":now+900,"aud":"appstoreconnect-v1"},separators=(",",":")).encode())
der=key.sign(si,ec.ECDSA(hashes.SHA256())); r,s=decode_dss_signature(der)
TOK=(si+b"."+b64u(r.to_bytes(32,"big")+s.to_bytes(32,"big"))).decode()
def get(path):
    req=urllib.request.Request("https://api.appstoreconnect.apple.com"+path,headers={"Authorization":"Bearer "+TOK})
    try:
        with urllib.request.urlopen(req,timeout=40) as x: return x.status,json.load(x)
    except urllib.error.HTTPError as e: return e.code,e.read().decode("utf-8","ignore")[:200]
    except Exception as e: return -1,str(e)
def decode_id(i):
    try:
        pad=i+"="*(-len(i)%4)
        return json.loads(base64.urlsafe_b64decode(pad.encode()))
    except Exception:
        return {}
for label,aid in [("词桥输入法","6838559017"),("Vocabridge","6838559237")]:
    print("####",label,aid)
    st,v=get("/v1/apps/"+aid+"/appAvailabilityV2?include=territoryAvailabilities&limit=200")
    print("  status",st)
    if st!=200 or not isinstance(v,dict):
        print("  body",str(v)[:200]); continue
    inc=v.get("included",[])
    print("  included count",len(inc),"total_paging",v.get("data",{}).get("relationships",{}).get("territoryAvailabilities",{}).get("meta"))
    avail_true=0; avail_false=0; chn=None
    for it in inc:
        t=decode_id(it.get("id","")).get("t")
        at=it.get("attributes",{})
        av=at.get("available")
        if av is True: avail_true+=1
        elif av is False: avail_false+=1
        if t=="CHN":
            chn={"id":it.get("id"),"attrs":at}
    print("  available_true=",avail_true,"available_false=",avail_false)
    print("  CHN=",json.dumps(chn,ensure_ascii=False))

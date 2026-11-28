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
aid="6838559017"
print("=== TERR probe", time.strftime("%H:%M:%S"),"===")
paths=[
 "/v1/appAvailabilities/"+aid+"/territoryAvailabilities?limit=200",
 "/v1/appAvailabilityV2/"+aid+"/territoryAvailabilities?limit=200",
 "/v1/appAvailabilityV2/"+aid+"/territories?limit=200",
 "/v1/apps/"+aid+"/appAvailabilityV2?include=territoryAvailabilities",
 "/v1/apps/"+aid+"/appAvailabilities?include=territoryAvailabilities",
]
for p in paths:
    st,v=get(p)
    print("PATH",p,"->",st)
    if st==200 and isinstance(v,dict):
        data=v.get("data")
        if isinstance(data,list):
            ids=[]
            for d in data:
                ids.append(d.get("id"))
            print("   list ids n=",len(ids),"CHN_in=",("CHN" in ids),"sample",ids[:10])
        else:
            print("   data=",json.dumps(data,ensure_ascii=False)[:300])
        if v.get("included"):
            inc_ids=[i.get("id") for i in v["included"]]
            print("   included n=",len(inc_ids),"CHN_in=",("CHN" in inc_ids),"sample",inc_ids[:10])
    else:
        print("   body",str(v)[:160])

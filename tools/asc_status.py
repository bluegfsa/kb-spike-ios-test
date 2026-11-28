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
    except urllib.error.HTTPError as e: return e.code,e.read().decode("utf-8","ignore")[:400]
    except Exception as e: return -1,str(e)
APPS=[("词桥输入法","6838559017"),("Vocabridge","6838559237")]
print("=== ASC 详细查询", time.strftime("%Y-%m-%d %H:%M:%S"),"===")
for label,aid in APPS:
    print("####",label,aid)
    stb,bs=get("/v1/builds?filter[app]="+aid+"&sort=-uploadedDate&limit=8")
    if stb==200:
        for bld in bs.get("data",[]):
            ba=bld["attributes"]
            print("  BUILD version=",ba.get("version"),"state=",ba.get("processingState"),
                  "usesNonExemptEncryption=",ba.get("usesNonExemptEncryption"),"uploaded=",ba.get("uploadedDate"))
    else: print("  builds err",stb,bs)
    st,v=get("/v1/apps/"+aid+"/appStoreVersions?limit=5")
    if st==200:
        for it in v.get("data",[]):
            va=it["attributes"]
            print("  VER",va.get("versionString"),"state=",va.get("appStoreState"))
            print("    VER_ATTRS=",json.dumps(va,ensure_ascii=False)[:600])
    else: print("  ver err",st,v)
    got=False
    for avpath in ["/v1/apps/"+aid+"/appAvailabilityV2","/v1/apps/"+aid+"/appAvailabilities"]:
        sta,av=get(avpath)
        print("  AVAIL",avpath,"->",sta)
        if sta==200 and isinstance(av,dict) and av.get("data"):
            d=av["data"]; d=d[0] if isinstance(d,list) else d
            av_id=d.get("id"); print("    avail_id",av_id,"attrs",json.dumps(d.get("attributes",{}),ensure_ascii=False))
            if "V2" in avpath:
                stt,ta=get("/v1/appAvailabilityV2/"+str(av_id)+"/territoryAvailabilities?limit=200")
            else:
                stt,ta=get("/v1/appAvailabilities/"+str(av_id)+"/availableTerritories?limit=200")
            print("    terr status",stt, ("" if stt==200 else json.dumps(ta,ensure_ascii=False)[:200]))
            if stt==200:
                ids=[t.get("id") for t in ta.get("data",[])]
                print("    total_terr=",len(ids),"CHN_in=",("CHN" in ids),"sample=",ids[:8])
            got=True; break
    if not got: print("  AVAIL 未取到（可能不支持 v2，需网页看）")
    sti,inf=get("/v1/apps/"+aid+"/appInfos")
    if sti==200:
        for d in inf.get("data",[]):
            print("  APPINFO id=",d.get("id"),"attrs=",json.dumps(d.get("attributes",{}),ensure_ascii=False)[:300])
    else: print("  appInfos err",sti,inf)

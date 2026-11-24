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
    except urllib.error.HTTPError as e: return e.code,e.read().decode("utf-8","ignore")[:300]
    except Exception as e: return -1,str(e)
APPS=[("词桥输入法","6838559017"),("Vocabridge","6838559237")]
print("=== ASC 状态查询 ", time.strftime("%Y-%m-%d %H:%M:%S"), " ===")
for label,aid in APPS:
    print("---",label,aid)
    st,v=get("/v1/apps/"+aid+"/appStoreVersions?limit=5")
    if st!=200: print("   versions err",st,v); continue
    for it in v.get("data",[]):
        va=it["attributes"]; vid=it["id"]
        print("   VER",va.get("versionString"),"state=",va.get("appStoreState"),"platform=",va.get("platform"))
        st2,b=get("/v1/appStoreVersions/"+vid+"/build")
        if st2==200: ba=b["data"]["attributes"]; print("      build",ba.get("version"),"processing=",ba.get("processingState"))
        else: print("      build none",st2)
        # 若被拒，尝试拉最��一次 reviewSubmission 信息
        if va.get("appStoreState") in ("REJECTED","DEVELOPER_REJECTED","METADATA_REJECTED"):
            st3,rs=get("/v1/apps/"+aid+"/reviewSubmissions?limit=3")
            print("      reviewSubmissions",st3, (json.dumps(rs,)[:400] if st3==200 else str(rs)[:200]))
        # 拉 version 上的审核备注/本地化(可能含被拒信息)
        st4,lz=get("/v1/appStoreVersions/"+vid+"/appStoreVersionLocalizations?limit=10")
        # 不打印敏感，只提示数量
        print("      localizations",st4, ("count="+str(len(lz.get("data",[]))) if st4==200 else ""))
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
print("=== ASC 详细查询", time.strftime("%Y-%m-%d %H:%M:%S"),"===")
for label,aid in APPS:
    print("####",label,aid)
    st,v=get("/v1/apps/"+aid+"/appStoreVersions?limit=5")
    if st!=200: print("  ver err",st,v); continue
    for it in v.get("data",[]):
        va=it["attributes"]; vid=it["id"]
        print("  VER",va.get("versionString"),"state=",va.get("appStoreState"))
        st3,rs=get("/v1/apps/"+aid+"/reviewSubmissions?limit=3")
        if st3==200:
            for rsm in rs.get("data",[]):
                sid=rsm["id"]; print("   submission",sid,"state=",rsm["attributes"].get("state"),"submitted=",rsm["attributes"].get("submittedDate"))
                sti,items=get("/v1/reviewSubmissions/"+sid+"/items?limit=50")
                if sti==200:
                    for itm in items.get("data",[]):
                        print("     ITEM type=",itm.get("type"),"state=",itm.get("attributes",{}).get("state"),"attrs=",json.dumps(itm.get("attributes",{}),ensure_ascii=False)[:300])
                else: print("     items err",sti,items)
        # appStoreReviewDetail（我们填的审核备注，非拒绝原因）
        st5,rd=get("/v1/appStoreVersions/"+vid+"/appStoreReviewDetail")
        if st5==200 and rd.get("data"): print("   reviewDetail notes=", (rd["data"]["attributes"].get("notes") or "")[:120])
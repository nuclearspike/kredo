import json, os, base64, subprocess, time, concurrent.futures as cf, urllib.request, urllib.error
GEN=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.dirname(os.path.dirname(GEN))
OUT=f"{ROOT}/priv/static/images/loans"
os.makedirs(OUT,exist_ok=True)
key=os.environ.get("OPENAI_API_KEY")
assert key, "Set OPENAI_API_KEY — image generation calls the OpenAI API."

REGION={"KE":"East African","UG":"East African","RW":"East African","GT":"Guatemalan","PE":"Peruvian",
 "NI":"Nicaraguan","BO":"Bolivian","EC":"Ecuadorian","SV":"Salvadoran","JO":"Middle Eastern (Jordanian)",
 "SN":"West African (Senegalese)","PH":"Filipino","KH":"Cambodian","VN":"Vietnamese","TJ":"Central Asian (Tajik)","US":"American"}
SCENE={
 "agriculture":"tending crops in a green field with simple farming tools",
 "livestock":"with their livestock (cows, goats or chickens) on a small farm",
 "retail":"behind the counter of a small shop stocked with colorful goods",
 "food":"preparing food at a small street-food stand with fresh ingredients",
 "clothing":"at a sewing machine surrounded by bright fabric in a tailoring workshop",
 "arts":"making handicrafts (weaving, pottery or jewelry) with traditional materials",
 "services":"running a small neighborhood service business (salon, repair or laundry)",
 "manufacturing":"in a small workshop with raw materials and simple machinery",
 "health":"in a small community pharmacy with shelves of medical supplies",
 "education":"in a modest classroom with books and a chalkboard",
 "construction":"at a small building site holding tools, in work clothes",
 "transportation":"beside a motorbike or cart used for deliveries",
 "technology":"at a small mobile-money and phone-repair kiosk",
}
params=json.load(open(f"{ROOT}/priv/repo/loan_data/params.json"))
todo=[p for p in params if not os.path.exists(f"{OUT}/{p['slug']}.jpg")]
print(f"{len(params)} loans, {len(todo)} images to generate")

def gen(p):
    who="a woman" if p["gender"]=="f" else "a man"
    reg=REGION.get(p["country_code"],"")
    prompt=(f"Warm, authentic documentary portrait photograph of {who}, a {reg} small-business owner and "
            f"microloan borrower, {SCENE[p['sector']]}. Their loan is for {p['loan_use_theme']}. "
            f"A unique, specific individual with their own face and clothing. Candid and dignified, real working "
            f"environment, natural daylight, shallow depth of field, photojournalistic. "
            f"No text, no watermark, no logos, no borders.")
    body=json.dumps({"model":"gpt-image-1","prompt":prompt,"size":"1024x1024","quality":"low","n":1}).encode()
    for a in range(6):
        try:
            req=urllib.request.Request("https://api.openai.com/v1/images/generations",data=body,
                headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"})
            with urllib.request.urlopen(req,timeout=180) as r: d=json.load(r)
            png=f"{OUT}/{p['slug']}.png"
            open(png,"wb").write(base64.b64decode(d["data"][0]["b64_json"]))
            subprocess.run(["sips","-s","format","jpeg","-Z","560","-s","formatOptions","82",png,"--out",f"{OUT}/{p['slug']}.jpg"],check=True,capture_output=True)
            os.remove(png)
            return (p["slug"],"ok")
        except urllib.error.HTTPError as e:
            if e.code in (429,500,502,503): time.sleep(6*(a+1)); continue
            return (p["slug"],f"http{e.code}")
        except Exception as e:
            time.sleep(4*(a+1)); last=str(e)[:100]
    return (p["slug"],f"fail:{last}")

ok=0;fail=[]
with cf.ThreadPoolExecutor(max_workers=7) as ex:
    for slug,st in ex.map(gen,todo):
        if st=="ok": ok+=1; (ok%20==0) and print(f"  ...{ok}/{len(todo)}")
        else: fail.append((slug,st))
print(f"DONE: {ok} ok, {len(fail)} failed")
for s,e in fail: print("  FAIL",s,e)

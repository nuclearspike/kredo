import json, os, re, time, concurrent.futures as cf, urllib.request
OUT = os.path.dirname(os.path.abspath(__file__))
# Any OpenAI-compatible chat endpoint works (a local model is plenty).
URL = os.environ.get("LLM_ENDPOINT", "http://127.0.0.1:1234/v1/chat/completions")
MODEL = os.environ.get("LLM_MODEL", "google/gemma-3-4b")
PER_SECTOR = 16

SECTORS = {
 "agriculture": ["drought-resistant seeds and irrigation","fertilizer and improved seed","a treadle water pump","tools for the maize harvest"],
 "livestock": ["two dairy cows","a flock of laying hens","goats to grow the herd","feed and veterinary care"],
 "retail": ["inventory for the corner shop","stock for the market stall","wholesale goods to resell","a display fridge"],
 "food": ["a mobile food cart","baking supplies and an oven","ingredients for catering","a refrigerator for the snack stand"],
 "clothing": ["a new sewing machine","fabric and thread in bulk","an overlock machine","cloth for a uniform order"],
 "arts": ["materials for weaving","clay and a kiln for pottery","beads and tools for jewelry","an upgraded loom"],
 "services": ["salon equipment","tools for a repair stand","a laundry machine","a barber chair and clippers"],
 "manufacturing": ["raw materials for the workshop","a welding machine","molds for the soap business","packaging equipment"],
 "health": ["stock for the community pharmacy","clinic supplies","a medicine refrigerator","first-aid inventory"],
 "education": ["school fees for the term","books and supplies","a computer for tutoring","desks for the classroom"],
 "construction": ["bricks and cement","tools for the building crew","materials to finish a roof","a concrete mixer"],
 "transportation": ["a delivery motorbike","tuk-tuk repairs","a cargo bicycle","fuel and spares for a taxi"],
 "technology": ["a phone-repair toolkit","stock for a mobile-money kiosk","a printer for the internet cafe","solar chargers to resell"],
}

def gen(args):
    sector, theme = args
    prompt = ("Output ONLY one JSON object, no markdown, no preamble. A demo microloan in the "
        f"{sector} sector, for: {theme}. Keys exactly: en,es,de,fr,nl. Each maps to an object with keys "
        "exactly: title, short, story. title <=6 words and may contain the placeholder {name}. "
        "short is one phrase. story is 1-2 sentences and mentions {name}. Keep it short. Quality is "
        "irrelevant but each field MUST be written in its own language.")
    body = json.dumps({"model":MODEL,"temperature":0.95,"max_tokens":700,
        "messages":[{"role":"user","content":prompt}]}).encode()
    for attempt in range(4):
        try:
            req=urllib.request.Request(URL, data=body, headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req, timeout=120) as r: d=json.load(r)
            txt=d["choices"][0]["message"]["content"]
            c=json.loads(re.search(r'\{.*\}',txt,re.S).group(0))
            if all(l in c and all(f in c[l] and c[l][f] for f in ("title","short","story")) for l in ("en","es","de","fr","nl")):
                return (sector, c)
        except Exception:
            time.sleep(2*(attempt+1))
    return (sector, None)

tasks=[(s, themes[i%len(themes)]) for i in range(PER_SECTOR) for s,themes in SECTORS.items()]
pool={s:[] for s in SECTORS}
# resume
if os.path.exists(f"{OUT}/pool.json"):
    try: pool={**pool, **json.load(open(f"{OUT}/pool.json"))}
    except: pass
need=[t for t in tasks]  # regenerate fully unless enough
have=sum(len(v) for v in pool.values())
print(f"{len(tasks)} templates target, {have} already")
done=have
with cf.ThreadPoolExecutor(max_workers=5) as ex:
    for sector,c in ex.map(gen, need):
        done+=1
        if c: pool[sector].append(c)
        if done%40==0:
            json.dump(pool, open(f"{OUT}/pool.json","w"), ensure_ascii=False)
            print(f"  ...{done} ({sum(len(v) for v in pool.values())} ok)")
json.dump(pool, open(f"{OUT}/pool.json","w"), ensure_ascii=False)
print("DONE", {s:len(v) for s,v in pool.items()}, "total", sum(len(v) for v in pool.values()))

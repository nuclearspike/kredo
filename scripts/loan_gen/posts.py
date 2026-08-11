import json, os, time, urllib.request, urllib.error
GEN=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.dirname(os.path.dirname(GEN))
DATA=os.path.join(ROOT, "priv", "repo", "loan_data")
key=os.environ.get("OPENAI_API_KEY")
assert key, "Set OPENAI_API_KEY — the content-refresh tooling calls the OpenAI API."
TEAMS=[
 ("the-coffee-fund","a lending team that supports coffee farmers and cooperatives","en",
  {"en":11,"es":3,"fr":1,"de":1}),
 ("tejedoras-unidas-supporters","un equipo de prestamistas que apoya a tejedoras y artesanas textiles (comunidad hispanohablante)","es",
  {"es":11,"en":2,"de":1,"nl":1,"fr":1}),
 ("climate-resilience-circle","a lending team that backs farmers and entrepreneurs building climate resilience","en",
  {"en":11,"es":2,"fr":1,"nl":1,"de":1}),
]
def gen(slug,desc,default,mix):
    locs=", ".join(f"{n} in {l}" for l,n in mix.items())
    p=(f"Generate short, warm, varied encouragement message-board posts for {desc}. "
       f"Return STRICT JSON: an object with key 'posts' = a list of objects each with 'locale' and 'body'. "
       f"Write exactly these counts by language: {locs}. Each body is 1-2 sentences, friendly and human, "
       f"as if written by different lenders cheering on borrowers — vary the voice, no names, no markdown, no hashtags. "
       f"Each 'locale' is the ISO code (en/es/de/fr/nl) matching its body.")
    body=json.dumps({"model":"gpt-5-mini","response_format":{"type":"json_object"},
        "messages":[{"role":"user","content":p}],"max_completion_tokens":3000}).encode()
    for a in range(4):
        try:
            req=urllib.request.Request("https://api.openai.com/v1/chat/completions",data=body,
                headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"})
            with urllib.request.urlopen(req,timeout=120) as r: d=json.load(r)
            return json.loads(d["choices"][0]["message"]["content"]).get("posts",[])
        except Exception as e: time.sleep(4*(a+1)); last=str(e)[:120]
    print("FAIL",slug,last); return []
out={}
for slug,desc,default,mix in TEAMS:
    out[slug]=gen(slug,desc,default,mix)
    print(slug,len(out[slug]),"posts")
json.dump(out,open(f"{DATA}/team_posts.json","w"),ensure_ascii=False,indent=1)
print("done")

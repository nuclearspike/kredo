import json, os, time, concurrent.futures as cf, urllib.request, urllib.error
GEN=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.dirname(os.path.dirname(GEN))
DATA=os.path.join(ROOT, "priv", "repo", "loan_data")
key=os.environ.get("OPENAI_API_KEY")
assert key, "Set OPENAI_API_KEY — the content-refresh tooling calls the OpenAI API."
params=json.load(open(f"{DATA}/params.json"))
LOCS=["en","es","de","fr","nl"]
FIELDS=["title","short_description","borrower_story","loan_use","repayment_summary","risk_summary_public"]
outpath=f"{DATA}/content.json"
done={}
if os.path.exists(outpath):
    try: done=json.load(open(outpath))
    except: done={}
todo=[l for l in params if l["slug"] not in done]
print(f"{len(params)} loans, {len(done)} already done, {len(todo)} to generate")

LNAME={"en":"English","es":"Spanish","de":"German","fr":"French","nl":"Dutch"}
def prompt(l):
    g="woman" if l["gender"]=="f" else "man"
    return (f"You write listing copy for a Kiva-style microlending platform. Return STRICT JSON only.\n"
      f"Borrower: {l['name']} (a {g}) in {l['country_name']}. Sector: {l['sector']}. "
      f"Loan purpose: {l['loan_use_theme']}. Amount: ${l['amount_cents']//100} over {l['term_months']} months. "
      f"Trust model: {l['trust_model'].replace('_',' ')}.\n\n"
      f"Produce a JSON object with keys exactly: en, es, de, fr, nl. Each maps to an object with keys exactly: "
      f"title, short_description, borrower_story, loan_use, repayment_summary, risk_summary_public.\n"
      f"- title: specific, <=55 chars, no quotes.\n"
      f"- short_description: one sentence, what the loan buys.\n"
      f"- borrower_story: 2-3 warm, specific, dignified sentences, third person, about this person and their business.\n"
      f"- loan_use: one concrete sentence on the use of funds.\n"
      f"- repayment_summary: e.g. 'Monthly repayments over {l['term_months']} months.'\n"
      f"- risk_summary_public: one honest sentence about backing/risk. Never claim guaranteed repayment.\n"
      f"The {LNAME[l['source_locale']]} version is primary; the other four are faithful, natural translations of the SAME content. "
      f"Culturally respectful, no English left in non-English fields.")

def call(l):
    body=json.dumps({"model":"gpt-5-mini","response_format":{"type":"json_object"},
        "messages":[{"role":"user","content":prompt(l)}],"max_completion_tokens":4000}).encode()
    for attempt in range(5):
        try:
            req=urllib.request.Request("https://api.openai.com/v1/chat/completions",data=body,
                headers={"Authorization":f"Bearer {key}","Content-Type":"application/json"})
            with urllib.request.urlopen(req,timeout=120) as r:
                d=json.load(r)
            c=json.loads(d["choices"][0]["message"]["content"])
            # validate; fill missing locale from en, missing field from theme
            if "en" not in c: raise ValueError("no en")
            for loc in LOCS:
                if loc not in c: c[loc]=dict(c["en"])
                for fld in FIELDS:
                    if not c[loc].get(fld): c[loc][fld]=c["en"].get(fld,"")
            return (l["slug"],c,None)
        except urllib.error.HTTPError as e:
            if e.code in (429,500,502,503): time.sleep(5*(attempt+1)); continue
            return (l["slug"],None,f"http{e.code}:{e.read()[:140]}")
        except Exception as e:
            time.sleep(3*(attempt+1)); last=str(e)[:140]
    return (l["slug"],None,f"fail:{last}")

ok=len(done);fail=[];i=0
with cf.ThreadPoolExecutor(max_workers=12) as ex:
    for slug,c,err in ex.map(call,todo):
        i+=1
        if c: done[slug]=c; ok+=1
        else: fail.append((slug,err))
        if i%20==0:
            json.dump(done,open(outpath,"w"),ensure_ascii=False)
            print(f"  ...{i}/{len(todo)} ({ok} ok, {len(fail)} fail)")
json.dump(done,open(outpath,"w"),ensure_ascii=False)
print(f"DONE content: {ok}/{len(params)} ok, {len(fail)} failed")
for s,e in fail[:20]: print("  FAIL",s,e)

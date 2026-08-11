#!/usr/bin/env python3
# N MORE historical loans: copies of existing loans (reuse borrowers + pooled
# sidecar text), ~98% completed / 2% defaulted, dated further in the past
# (2013-2022). Only loans + loans_lc are produced (lean). Load with load_1m.sh.
#
#   python3 build_1m.py --count 1000000   # then: ./load_1m.sh
import json, os, csv, random, argparse, subprocess, datetime as dt

ap = argparse.ArgumentParser(description="Generate lean historical loan CSVs")
ap.add_argument("--count", type=int, default=1_000_000)
ap.add_argument("--seed", type=int, default=424242)
ap.add_argument("--db", default=os.environ.get("KREDO_DB", "kiva_dev"),
                help="database for id maxima + borrower reuse ('' = built-in defaults + borrowers_export.csv)")
args = ap.parse_args()
random.seed(args.seed)
GEN = os.path.dirname(os.path.abspath(__file__))
CSV = f"{GEN}/csv"
os.makedirs(CSV, exist_ok=True)

def psql_rows(q):
    r = subprocess.run(["psql", args.db, "-tA", "-F", "\t", "-c", q],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f"psql {args.db} failed: {r.stderr.strip()}\n"
                         "Run after `mix ecto.setup`, or pass --db ''.")
    return [line.split("\t") for line in r.stdout.strip().splitlines() if line]

N=args.count
B_LOAN=2_000_000; B_LC=10_000_000
if args.db:
    B_LOAN = int(psql_rows("select coalesce(max(id),0)+1 from loans")[0][0])
    B_LC = int(psql_rows("select coalesce(max(id),0)+1 from loans_lc")[0][0])
LOCS=["en","es","de","fr","nl"]
AMOUNTS=[25000,40000,50000,75000,100000,120000,150000,200000,250000,300000,400000,500000]
TERMS=[6,8,10,12,12,14,18,24,36]
TRUST=["partner_facilitated"]*5+["trustee_backed","direct","social_underwritten"]
REPAY={"en":"Monthly repayments over {n} months.","es":"Pagos mensuales durante {n} meses.","de":"Monatliche Rückzahlungen über {n} Monate.","fr":"Remboursements mensuels sur {n} mois.","nl":"Maandelijkse aflossingen over {n} maanden."}
RISK={"en":"Loans are not guaranteed and carry a risk of default.","es":"Los préstamos no están garantizados y conllevan riesgo de impago.","de":"Kredite sind nicht garantiert und bergen ein Ausfallrisiko.","fr":"Les prêts ne sont pas garantis et comportent un risque de défaut.","nl":"Leningen zijn niet gegarandeerd en brengen een risico op wanbetaling met zich mee."}

# pooled sidecar text (208 templates)
pool=json.load(open(f"{GEN}/pool.json"))
TPL=[t for v in pool.values() for t in v]
# existing borrowers to reuse: id, partner, country, sector, locale, name
BORR=[]
if args.db:
    q = ("select b.id, b.partner_id, b.country_code, b.sector_id, b.preferred_locale_code, "
         "coalesce(lc.display_name,'') from borrowers b "
         "left join borrowers_lc lc on lc.borrower_id = b.id and lc.is_source "
         "where b.partner_id is not null and b.sector_id is not null")
    BORR=[(int(r[0]), int(r[1]), r[2], int(r[3]), r[4], r[5]) for r in psql_rows(q)]
else:
    for row in csv.reader(open(f"{GEN}/borrowers_export.csv")):
        BORR.append((int(row[0]), int(row[1]), row[2], int(row[3]), row[4], row[5]))
if not BORR:
    raise SystemExit("no borrowers to reuse — seed the world first (mix ecto.setup, "
                     "optionally build_csv.py + load.sh), or run without --db to use borrowers_export.csv")
print(f"{len(TPL)} templates, {len(BORR)} borrowers to reuse")

START=dt.datetime(2013,1,1); SPAN=(dt.datetime(2022,12,31)-START).days
def rdt(): return START+dt.timedelta(days=random.randint(0,SPAN), seconds=random.randint(0,86399))
def ts(d): return d.strftime("%Y-%m-%d %H:%M:%S")

fl=open(f"{CSV}/loans_1m.csv","w",newline=""); wl=csv.writer(fl)
fc=open(f"{CSV}/loans_lc_1m.csv","w",newline=""); wc=csv.writer(fc)
lc_id=B_LC
for i in range(N):
    lid=B_LOAN+i; d=rdt()
    bid,partner,country,sector,loc_src,name=random.choice(BORR)
    first=name.split()[0] if name else ""
    t=random.choice(TPL); sub=lambda s:s.replace("{name}",first)
    status="defaulted" if random.random()<0.02 else "completed"
    amount=random.choice(AMOUNTS); term=random.choice(TERMS)
    disb=ts(d+dt.timedelta(days=random.randint(10,60)))
    wl.writerow([lid,f"h{lid}",status,partner,bid,country,sector,"",random.choice(TRUST),amount,amount,"USD","post_disbursed",disb,"","",term,"monthly",loc_src,ts(d),ts(d),""])
    for loc in LOCS:
        is_src=(loc==loc_src)
        st="published" if is_src else ("approved" if random.random()<0.85 else "machine")
        wc.writerow([lc_id,lid,sub(t[loc]["title"]),t[loc]["short"],sub(t[loc]["story"]),t[loc]["short"],REPAY[loc].format(n=term),RISK[loc],loc,"t" if is_src else "f",loc_src,st,"",1,"",ts(d),ts(d)]); lc_id+=1
    if (i+1)%200000==0: print(f"  ...{i+1} loans")
fl.close(); fc.close()
print(f"DONE. loans {B_LOAN}..{B_LOAN+N-1}, loans_lc {B_LC}..{lc_id-1}")

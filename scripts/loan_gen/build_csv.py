#!/usr/bin/env python3
# Builds FK-consistent CSVs for N loans + M users + accompanying records
# (schedules, lendings, borrower updates, notifications, audit samples).
# Pure python + deterministic under --seed. Explicit IDs are allocated above the
# current database maxima (read via psql) so the CSVs bulk-load cleanly and the
# script can be re-run as the database grows.
#
#   python3 build_csv.py --loans 250000 --users 50000   # then: ./load.sh
#
# Pass --db '' to skip psql and use built-in defaults that match a fresh
# `mix ecto.setup` world.
import json, os, csv, random, argparse, subprocess, datetime as dt

ap = argparse.ArgumentParser(description="Generate demo-scale loan CSVs")
ap.add_argument("--loans", type=int, default=100_000)
ap.add_argument("--users", type=int, default=50_000)
ap.add_argument("--seed", type=int, default=20260627)
ap.add_argument("--db", default=os.environ.get("KREDO_DB", "kiva_dev"),
                help="database for id maxima + slug->id maps ('' = built-in defaults)")
args = ap.parse_args()
random.seed(args.seed)
GEN = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(GEN))
CSV = f"{GEN}/csv"
os.makedirs(CSV, exist_ok=True)

N_LOANS = args.loans
N_USERS = args.users
PW="$2b$12$kVsa9fFh9TRSmyG1W2PMAevFLdunYZVaL35hPi9lUbdf.yaN6TqCe"  # bcrypt("password")

def psql_rows(q):
    r = subprocess.run(["psql", args.db, "-tA", "-F", "\t", "-c", q],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f"psql {args.db} failed: {r.stderr.strip()}\n"
                         "Run after `mix ecto.setup`, or pass --db '' for built-in defaults.")
    return [line.split("\t") for line in r.stdout.strip().splitlines() if line]

# Built-in defaults matching a fresh `mix ecto.setup` world (overridden from --db).
PARTNER={"BO":13,"EC":8,"GT":1,"JO":4,"KE":2,"KH":11,"NI":14,"PE":12,"PH":15,"RW":7,"SN":6,"TJ":10,"UG":9,"VN":5}
SECTOR={"arts":1,"agriculture":2,"food":3,"clothing":6,"construction":7,"education":8,"health":10,"livestock":11,"manufacturing":12,"retail":13,"services":14,"technology":15,"transportation":16}
TEAMS=[1,2,3]
DEMO_LENDER_ID=2  # the seeded demo lender (Morgan)
# id bases (above current max of the fresh seed world)
B={"user":16,"borrower":204,"borrower_lc":2016,"loan":205,"loan_lc":1016,"sched":192,"item":2733,"lend":20000000,"upd":20000000,"upd_lc":20000000,"notif":20000000,"audit":20000000}

if args.db:
    PARTNER = {cc: int(i) for cc, i in psql_rows("select country_code, min(id) from partners group by country_code")}
    SECTOR = {k: int(i) for k, i in psql_rows("select key, id from sectors")}
    TEAMS = [int(r[0]) for r in psql_rows("select id from lending_teams order by id")] or TEAMS
    demo = psql_rows("select id from users where email in ('lender@kredo.test','lender@kiva.org') order by id limit 1")
    DEMO_LENDER_ID = int(demo[0][0]) if demo else None
    _tables={"user":"users","borrower":"borrowers","borrower_lc":"borrowers_lc","loan":"loans",
             "loan_lc":"loans_lc","sched":"repayment_schedules","item":"repayment_schedule_items",
             "lend":"lendings","upd":"borrower_updates","upd_lc":"borrower_updates_lc",
             "notif":"notifications","audit":"audit_events"}
    B = {k: int(psql_rows(f"select coalesce(max(id),0)+1 from {t}")[0][0]) for k, t in _tables.items()}

LOAN_IMGS=sorted(os.listdir(f"{ROOT}/priv/static/images/loans"))  # cycle existing 200
LOCS=["en","es","de","fr","nl"]
assert PARTNER and SECTOR and LOAN_IMGS, "empty partner/sector/image sets — run after `mix ecto.setup`"

COUNTRIES=[
 ("KE","en",["Amina","Grace","Mary","Faith","Esther","Wanjiru","Halima","Njeri","Zawadi","Ruth"],["Joseph","Daniel","Peter","Samuel","John","Kamau","Otieno","Mwangi","Baraka","Juma"],["Okello","Wanjiru","Otieno","Mwangi","Achieng","Kiprono","Were","Njoroge"]),
 ("GT","es",["Rosa","Maria","Juana","Lucia","Carmen","Ana","Floridalma","Petrona","Manuela","Tomasa"],["Carlos","Jose","Diego","Pedro","Manuel","Mateo","Baltazar","Tomas","Felipe","Marcos"],["Alvarez","Garcia","Lopez","Mendez","Chavez","Coc","Tzul","Xochil"]),
 ("PE","es",["Lucia","Rosa","Carmen","Flor","Yolanda","Nancy","Gladys","Marisol"],["Juan","Luis","Jorge","Edgar","Wilmer","Mario","Hernan","Percy"],["Quispe","Mamani","Huaman","Flores","Condori","Vargas","Ccopa","Chambi"]),
 ("JO","en",["Mariam","Fatima","Layla","Noor","Huda","Rania","Salma","Dina"],["Ahmad","Omar","Yusuf","Khaled","Sami","Tariq","Bilal","Hani"],["Haddad","Khalil","Mansour","Nasser","Odeh","Saleh","Qasim","Awad"]),
 ("UG","en",["Sarah","Joyce","Betty","Agnes","Rebecca","Florence","Justine","Harriet"],["Joseph","Moses","David","Patrick","Isaac","Emmanuel","Bosco","Geoffrey"],["Nakato","Okwir","Tumusiime","Nabirye","Mugisha","Acen","Wasswa","Auma"]),
 ("PH","en",["Maria","Liza","Jenny","Rosa","Grace","Imelda","Cristina","Divina"],["Jun","Mark","Noli","Ramon","Jerome","Edgar","Boy","Dante"],["Santos","Reyes","Cruz","Bautista","Garcia","Mendoza","Aquino","Dela Cruz"]),
 ("KH","en",["Sokha","Channary","Bopha","Sreypov","Kunthea","Mealea","Davy","Phalla"],["Dara","Vibol","Sokun","Rith","Pisey","Chanthou","Veasna","Samnang"],["Sok","Chan","Pich","Heng","Kim","Meas","Chea","Prak"]),
 ("NI","es",["Maria","Marta","Yesenia","Brenda","Maritza","Xiomara","Heyling","Scarleth"],["Jose","Carlos","Wilber","Denis","Santos","Reynaldo","Elvin","Norlan"],["Lopez","Hernandez","Gutierrez","Perez","Cruz","Rivas","Sequeira","Lacayo"]),
 ("SN","fr",["Awa","Fatou","Aissatou","Khady","Mariama","Ndeye","Coumba","Sokhna"],["Mamadou","Ousmane","Ibrahima","Cheikh","Modou","Abdou","Pape","Moussa"],["Diop","Ndiaye","Fall","Sow","Ba","Sarr","Gueye","Diallo"]),
 ("VN","en",["Lan","Mai","Huong","Thuy","Hoa","Linh","Trang","Nga"],["Minh","Tuan","Hung","Nam","Phuc","Khoa","Long","Quan"],["Nguyen","Tran","Le","Pham","Vo","Dang","Bui","Do"]),
 ("BO","es",["Juana","Gregoria","Filomena","Rosa","Modesta","Eulalia","Justina","Basilia"],["Mario","Julio","Felix","Genaro","Eulogio","Saturnino","Hugo","Marcelo"],["Mamani","Quispe","Condori","Choque","Apaza","Colque","Calle","Huanca"]),
 ("EC","es",["Mercedes","Narcisa","Blanca","Rocio","Targelia","Zoila","Transito"],["Segundo","Angel","Klever","Manuel","Wilson","Holger","Cesar"],["Yupanqui","Cabrera","Tenesaca","Guaman","Morocho","Chimbo","Pilco"]),
 ("RW","en",["Claudine","Immaculee","Josiane","Vestine","Chantal","Liberata","Esperance"],["Emmanuel","Jean","Eric","Theogene","Innocent","Fidele","Damascene"],["Uwase","Mukamana","Niyonzima","Habimana","Ingabire","Nshimiyimana","Bizimana"]),
 ("TJ","en",["Gulnora","Farzona","Zarina","Nigina","Madina","Sitora","Manija"],["Firdavs","Jamshed","Bakhtiyor","Rustam","Daler","Shavkat","Umed"],["Karimov","Sharipov","Rahmonov","Nazarov","Yusupov","Saidov","Aliev"]),
]

SECTOR_KEYS=list(SECTOR.keys())
AMOUNTS=[25000,40000,50000,60000,75000,90000,100000,120000,150000,175000,200000,250000,300000,400000,500000]
TERMS=[6,8,10,12,12,14,18,24,36]
TRUST=["partner_facilitated"]*5+["trustee_backed","direct","social_underwritten"]
REPAY={"en":"Monthly repayments over {n} months.","es":"Pagos mensuales durante {n} meses.","de":"Monatliche Rückzahlungen über {n} Monate.","fr":"Remboursements mensuels sur {n} mois.","nl":"Maandelijkse aflossingen over {n} maanden."}
RISK={"en":"Loans are not guaranteed and carry a risk of default.","es":"Los préstamos no están garantizados y conllevan riesgo de impago.","de":"Kredite sind nicht garantiert und bergen ein Ausfallrisiko.","fr":"Les prêts ne sont pas garantis et comportent un risque de défaut.","nl":"Leningen zijn niet gegarandeerd en brengen een risico op wanbetaling met zich mee."}
UPD={"en":"Thank you for your support! The business is going well.","es":"¡Gracias por su apoyo! El negocio va bien.","de":"Danke für Ihre Unterstützung! Das Geschäft läuft gut.","fr":"Merci de votre soutien ! L'activité se porte bien.","nl":"Bedankt voor uw steun! Het gaat goed met de zaak."}

pool=json.load(open(f"{GEN}/pool.json"))
allt=[t for v in pool.values() for t in v]
def tpl(sector):
    lst=pool.get(sector) or allt
    return random.choice(lst)

START=dt.datetime(2023,6,1); SPAN=(dt.datetime(2026,6,20)-START).days
def rand_dt(): return START+dt.timedelta(days=random.randint(0,SPAN), seconds=random.randint(0,86399))
def ts(d): return d.strftime("%Y-%m-%d %H:%M:%S")
def da(d): return d.strftime("%Y-%m-%d")

STATUS_W=[("fundraising",3950),("completed",55000),("repaying",26000),("delinquent",6000),
          ("defaulted",5000),("funded",2000),("draft",2050)]
statuses=random.choices([s for s,_ in STATUS_W], weights=[w for _,w in STATUS_W], k=N_LOANS)

_names=["users","borrowers","borrowers_lc","loans","loans_lc","repayment_schedules","repayment_schedule_items","lendings","borrower_updates","borrower_updates_lc","notifications","audit_events"]
FILES={n: open(f"{CSV}/{n}.csv","w",newline="") for n in _names}
W={n: csv.writer(FILES[n]) for n in _names}

def tstatus(is_src):
    if is_src: return "published"
    r=random.random(); return "approved" if r<0.8 else ("machine" if r<0.93 else "needs_review")

# ---- users (50K lenders) ----
locs_cycle=LOCS
for i in range(N_USERS):
    uid=B["user"]+i; d=rand_dt()
    W["users"].writerow([uid, f"lender{uid}@kredo.test", PW, f"Lender {uid}", "lender", LOCS[i%5], ts(d), ts(d), "", f"/images/lenders/l{i%4+1}.jpg"])
user_ids=list(range(B["user"], B["user"]+N_USERS))+([DEMO_LENDER_ID] if DEMO_LENDER_ID else [])  # + the seeded demo lender

upd_id=B["upd"]; updlc_id=B["upd_lc"]; notif_id=B["notif"]; audit_id=B["audit"]
item_id=B["item"]; lend_id=B["lend"]; sched_id=B["sched"]

# Only fabricate loans for countries whose partner exists in the target world.
COUNTRIES=[c for c in COUNTRIES if c[0] in PARTNER]
assert COUNTRIES, "no COUNTRIES overlap the partners in the database"

for i in range(N_LOANS):
    lid=B["loan"]+i; bid=B["borrower"]+i; d=rand_dt()
    cc,src,fn,mn,sn=random.choice(COUNTRIES)
    gender=random.choice("fffm"); first=random.choice(fn if gender=="f" else mn); name=f"{first} {random.choice(sn)}"
    sector=random.choice(SECTOR_KEYS); t=tpl(sector)
    amount=random.choice(AMOUNTS); term=random.choice(TERMS); state=statuses[i]
    trust=random.choice(TRUST); img=LOAN_IMGS[i%len(LOAN_IMGS)]
    sub=lambda s: s.replace("{name}", first)

    # borrower + 5 lc
    W["borrowers"].writerow([bid,"",f"b{bid}",cc,src,PARTNER[cc],SECTOR[sector],"",f"/images/loans/{img}",ts(d),ts(d)])
    for j,loc in enumerate(LOCS):
        is_src=(loc==src)
        W["borrowers_lc"].writerow([B["borrower_lc"]+i*5+j,bid,name,sub(t[loc]["story"]),t[loc]["short"],loc,"t" if is_src else "f",src,tstatus(is_src),"",1,"",ts(d),ts(d)])

    # state -> financials/schedule
    # Lending moves in whole $25 units (schema check constraints) — floor the
    # partial total to a unit so a fundraising loan never snaps to fully funded.
    if state=="draft": funded=0
    elif state=="fundraising": funded=(int(amount*random.uniform(0.08,0.92))//2500)*2500
    else: funded=amount
    disbursed = state in ("repaying","completed","delinquent","defaulted")
    dstatus="post_disbursed" if disbursed else "pre_disbursed"
    disbursed_at = ts(d-dt.timedelta(days=random.randint(20,300))) if disbursed else ""
    if state=="fundraising":
        fr_s=ts(d-dt.timedelta(days=random.randint(1,20))); fr_e=ts(d+dt.timedelta(days=random.randint(5,40)))
    else: fr_s=fr_e=""
    W["loans"].writerow([lid,f"l{lid}",state,PARTNER[cc],bid,cc,SECTOR[sector],"",trust,amount,funded,"USD",dstatus,disbursed_at,fr_s,fr_e,term,"monthly",src,ts(d),ts(d),""])
    for j,loc in enumerate(LOCS):
        is_src=(loc==src)
        W["loans_lc"].writerow([B["loan_lc"]+i*5+j,lid,sub(t[loc]["title"]),t[loc]["short"],sub(t[loc]["story"]),t[loc]["short"],REPAY[loc].format(n=term),RISK[loc],loc,"t" if is_src else "f",src,tstatus(is_src),"",1,"",ts(d),ts(d)])

    # schedule + items (non-draft)
    if state!="draft":
        if state in ("repaying",): off=-max(2,term//2); paid=round(term*random.uniform(.3,.6))
        elif state=="completed": off=-(term+2); paid=term
        elif state=="delinquent": off=-max(3,int(term*.65)); paid=round(term*random.uniform(.2,.4))
        elif state=="defaulted": off=-max(4,int(term*.85)); paid=round(term*random.uniform(.05,.2))
        else: off=1; paid=0  # funded/fundraising
        starts=(d+dt.timedelta(days=off*30)).date()
        monthly=max(1000,amount//term)
        W["repayment_schedules"].writerow([sched_id,lid,"",da(starts),term,"monthly",ts(d),ts(d)])
        for m in range(1,term+1):
            due=starts+dt.timedelta(days=30*m); is_paid=m<=paid
            W["repayment_schedule_items"].writerow([item_id,sched_id,da(due),monthly,"paid" if is_paid else "scheduled",da(due) if is_paid else "",ts(d),ts(d)])
            item_id+=1
        sched_id+=1

    # lendings (funded loans) — each lend is a positive whole-$25 amount and the
    # per-loan lends sum exactly to the funded total (schema check constraints).
    if funded>0:
        units=funded//2500
        n=min(max(1,min(20,units//3)), units)
        per=units//n
        for k in range(n):
            u = units-per*(n-1) if k==n-1 else per
            uid = DEMO_LENDER_ID if (DEMO_LENDER_ID and k==0 and i%90==0) else random.choice(user_ids)
            team = random.choice(TEAMS) if random.random()<0.3 else ""
            W["lendings"].writerow([lend_id,uid,lid,team,u*2500,ts(d+dt.timedelta(days=random.randint(0,5)))]); lend_id+=1

    # borrower update (subset of disbursed)
    if disbursed and random.random()<0.3:
        W["borrower_updates"].writerow([upd_id,lid,bid,"","update",src,ts(d),ts(d)])
        for j,loc in enumerate(LOCS):
            is_src=(loc==src)
            W["borrower_updates_lc"].writerow([updlc_id,upd_id,UPD[loc],loc,"t" if is_src else "f",src,tstatus(is_src),"",1,"",ts(d),ts(d)]); updlc_id+=1
        upd_id+=1

    if (i+1)%20000==0: print(f"  ...{i+1} loans")

# ---- modest notifications + audit samples (scales with --loans, capped) ----
N_EXTRAS=min(100_000, N_LOANS)
NTYPES=[("loan_funded","Fully funded!","A loan you supported is now fully funded.","/portfolio"),("repayment","Repayment received","Your balance to relend grew.","/portfolio"),("disbursal","Disbursed","The funds reached the borrower.","/portfolio")]
for k in range(N_EXTRAS):
    nt=random.choice(NTYPES); d=rand_dt(); uid=random.choice(user_ids)
    W["notifications"].writerow([notif_id,uid,nt[0],nt[1],nt[2],nt[3],ts(d) if random.random()<0.5 else "",ts(d)]); notif_id+=1
AEV=["command.fund_loan","loan.repayment_recorded","loan.disbursed","command.post_team_message","loan.lent"]
for k in range(N_EXTRAS):
    d=rand_dt(); uid=random.choice(user_ids); ev=random.choice(AEV); lid=B["loan"]+random.randrange(N_LOANS)
    W["audit_events"].writerow([audit_id,uid,"lender",ev,"loan",str(lid),f"{ev} on loan {lid}","{}",ts(d)]); audit_id+=1

for fh in FILES.values(): fh.close()
print("DONE. max ids:", {"loan":B["loan"]+N_LOANS-1,"lend":lend_id-1,"item":item_id-1,"sched":sched_id-1,"upd":upd_id-1,"notif":notif_id-1,"audit":audit_id-1})

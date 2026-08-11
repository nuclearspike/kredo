import json, os, random, re, hashlib
random.seed(42)
# Writes params.json where the seeds read it (priv/repo/loan_data/).
GEN = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(GEN))
OUT = os.path.join(ROOT, "priv", "repo", "loan_data")

# country: code, name, source locale, flag, female names, male names, surnames, MFI
COUNTRIES=[
 ("KE","Kenya","en","🇰🇪",["Amina","Grace","Mary","Faith","Esther","Wanjiru","Halima","Njeri"],["Joseph","Daniel","Peter","Samuel","John","Kamau","Otieno","Mwangi"],["Okello","Wanjiru","Otieno","Mwangi","Achieng","Kiprono"],("green-fields-microfinance","Green Fields Microfinance")),
 ("GT","Guatemala","es","🇬🇹",["Rosa","María","Juana","Lucía","Carmen","Ana","Floridalma","Petrona"],["Carlos","José","Diego","Pedro","Manuel","Mateo","Baltazar","Tomás"],["Álvarez","García","López","Méndez","Chávez","Coc"],("community-loom-cooperative","Community Loom Cooperative")),
 ("PE","Peru","es","🇵🇪",["Lucía","Rosa","Carmen","Flor","Yolanda","Nancy","Gladys"],["Juan","Luis","Jorge","Edgar","Wilmer","Mario","Hernán"],["Quispe","Mamani","Huamán","Flores","Condori","Vargas"],("andes-microfinanzas","Andes Microfinanzas")),
 ("JO","Jordan","en","🇯🇴",["Mariam","Fatima","Layla","Noor","Huda","Rania","Salma"],["Ahmad","Omar","Yusuf","Khaled","Sami","Tariq","Bilal"],["Haddad","Khalil","Mansour","Nasser","Odeh","Saleh"],("levant-community-fund","Levant Community Fund")),
 ("UG","Uganda","en","🇺🇬",["Sarah","Joyce","Betty","Agnes","Rebecca","Florence","Justine"],["Joseph","Moses","David","Patrick","Isaac","Emmanuel","Bosco"],["Nakato","Okwir","Tumusiime","Nabirye","Mugisha","Acen"],("pearl-of-africa-sacco","Pearl of Africa SACCO")),
 ("PH","Philippines","en","🇵🇭",["Maria","Liza","Jenny","Rosa","Grace","Imelda","Cristina"],["Jun","Mark","Noli","Ramon","Jerome","Edgar","Boy"],["Santos","Reyes","Cruz","Bautista","Garcia","Mendoza"],("bayanihan-lending-group","Bayanihan Lending Group")),
 ("KH","Cambodia","en","🇰🇭",["Sokha","Channary","Bopha","Sreypov","Kunthea","Mealea"],["Dara","Vibol","Sokun","Rith","Pisey","Chanthou"],["Sok","Chan","Pich","Heng","Kim","Meas"],("angkor-community-finance","Angkor Community Finance")),
 ("NI","Nicaragua","es","🇳🇮",["María","Marta","Yesenia","Brenda","Maritza","Xiomara"],["José","Carlos","Wilber","Denis","Santos","Reynaldo"],["López","Hernández","Gutiérrez","Pérez","Cruz","Rivas"],("nueva-esperanza-cooperativa","Nueva Esperanza Cooperativa")),
 ("SN","Senegal","fr","🇸🇳",["Awa","Fatou","Aïssatou","Khady","Mariama","Ndeye"],["Mamadou","Ousmane","Ibrahima","Cheikh","Modou","Abdou"],["Diop","Ndiaye","Fall","Sow","Ba","Sarr"],("teranga-microcredit","Teranga Microcrédit")),
 ("VN","Vietnam","en","🇻🇳",["Lan","Mai","Huong","Thuy","Hoa","Linh"],["Minh","Tuan","Hung","Nam","Phuc","Khoa"],["Nguyen","Tran","Le","Pham","Vo","Dang"],("mekong-delta-fund","Mekong Delta Fund")),
 ("BO","Bolivia","es","🇧🇴",["Juana","Gregoria","Filomena","Rosa","Modesta","Eulalia"],["Mario","Julio","Felix","Genaro","Eulogio","Saturnino"],["Mamani","Quispe","Condori","Choque","Apaza","Colque"],("altiplano-microfinanzas","Altiplano Microfinanzas")),
 ("EC","Ecuador","es","🇪🇨",["Mercedes","Narcisa","Blanca","Rocío","Targelia"],["Segundo","Ángel","Klever","Manuel","Wilson"],["Yupanqui","Cabrera","Tenesaca","Guamán","Morocho"],("mitad-del-mundo-credito","Mitad del Mundo Crédito")),
 ("RW","Rwanda","en","🇷🇼",["Claudine","Immaculée","Josiane","Vestine","Chantal"],["Emmanuel","Jean","Eric","Théogène","Innocent"],["Uwase","Mukamana","Niyonzima","Habimana","Ingabire"],("urumuri-savings-group","Urumuri Savings Group")),
 ("TJ","Tajikistan","en","🇹🇯",["Gulnora","Farzona","Zarina","Nigina","Madina"],["Firdavs","Jamshed","Bakhtiyor","Sino","Rustam","Daler"],["Karimov","Sharipov","Rahmonov","Nazarov","Yusupova"],("pamir-finance-group","Pamir Finance Group")),
]

# sector key, activity key, image-sector, gendered loan-use themes
SECTORS=[
 ("agriculture","farming",["drought-resistant seeds and irrigation","fertilizer and improved seed","a treadle water pump","tools for the maize harvest","seedlings for a new plot"]),
 ("livestock","animal-husbandry",["two dairy cows","a flock of laying hens","goats to grow the herd","feed and veterinary care","a pig and breeding stock"]),
 ("retail","general-store",["inventory for the corner shop","stock for the market stall","wholesale goods to resell","a display fridge for cold drinks","more shelves and product"]),
 ("food","food-production",["a mobile food cart","baking supplies and an oven","ingredients for the catering orders","a second rice cooker and tables","a refrigerator for the snack stand"]),
 ("clothing","tailoring",["a new sewing machine","fabric and thread in bulk","an overlock machine","cloth for a school-uniform order","a mannequin and display rack"]),
 ("arts","handicrafts",["materials for weaving","clay and a kiln for pottery","beads and tools for jewelry","an upgraded loom","leather and dyes for bags"]),
 ("services","services",["salon equipment and supplies","tools for the phone-repair stand","a commercial laundry machine","a barber chair and clippers","a generator for the workshop"]),
 ("manufacturing","small-manufacturing",["raw materials for the workshop","a welding machine","molds for the soap business","packaging and labels","a grinder for the mill"]),
 ("health","health",["stock for the community pharmacy","supplies for the clinic","a refrigerator for medicines","first-aid and hygiene inventory","a blood-pressure kit and scales"]),
 ("education","education",["school fees for the term","books and supplies for the class","a computer for the tutoring center","desks for the learning space","exam materials for students"]),
 ("construction","construction",["bricks and cement","tools for the building crew","materials to finish a roof","a concrete mixer","timber and fittings"]),
 ("transportation","transport",["a motorbike for deliveries","repairs for the tuk-tuk","a bicycle cargo cart","fuel and spares for the shared taxi","a trailer for hauling goods"]),
 ("technology","technology",["a phone-repair toolkit","stock for the mobile-money kiosk","a printer for the internet cafe","solar chargers to resell","a laptop for the digital-services stand"]),
]

TRUST=["partner_facilitated","partner_facilitated","partner_facilitated","partner_facilitated","trustee_backed","direct","social_underwritten"]

# state distribution -> 200
STATES=( ["fundraising"]*55 + ["funded"]*10 + ["repaying"]*75 + ["completed"]*18
       + ["delinquent"]*22 + ["defaulted"]*8 + ["draft"]*12 )
random.shuffle(STATES)
assert len(STATES)==200, len(STATES)

def slugify(s): return re.sub(r'[^a-z0-9]+','-',s.lower()).strip('-')

def tstatus():
    r=random.random()
    if r<0.78: return "approved"
    if r<0.93: return "machine"
    return "needs_review"

loans=[]
used=set()
for i in range(200):
    c=random.choice(COUNTRIES)
    code,name,loc,flag,fn,mn,sn,mfi=c
    gender=random.choice(["f","f","f","m"])  # ~75% women, mirrors Kiva
    first=random.choice(fn if gender=="f" else mn)
    full=f"{first} {random.choice(sn)}"
    sec=random.choice(SECTORS)
    skey,activity,uses=sec
    use=random.choice(uses)
    state=STATES[i]
    amount=random.choice([25000,40000,50000,60000,75000,90000,100000,120000,150000,175000,200000,250000])
    term=random.choice([6,8,10,12,12,14,18,24])
    variant=(int(hashlib.md5(full.encode()).hexdigest(),16)%2)+1
    image=f"{skey}_{gender}_{variant}.jpg"
    base=f"{slugify(first)}-{skey}"
    slug=base; n=2
    while slug in used: slug=f"{base}-{n}"; n+=1
    used.add(slug)

    if state=="draft": funded_pct=0
    elif state=="fundraising": funded_pct=random.randint(8,92)
    else: funded_pct=100

    disbursed = state in ("repaying","completed","delinquent","defaulted")
    if state=="repaying": paid=round(term*random.uniform(0.30,0.60)); off=-max(2,round(term*0.5)); overdue=False
    elif state=="completed": paid=term; off=-(term+2); overdue=False
    elif state=="delinquent": paid=round(term*random.uniform(0.20,0.40)); off=-max(3,round(term*0.65)); overdue=True
    elif state=="defaulted": paid=round(term*random.uniform(0.05,0.20)); off=-max(4,round(term*0.85)); overdue=True
    elif state=="funded": paid=0; off=1; overdue=False
    else: paid=0; off=1; overdue=False  # fundraising

    lenders = max(1, round(amount*funded_pct/100/random.choice([2500,5000,7500,10000]))) if funded_pct>0 else 0
    lenders=min(lenders, 30)

    loans.append(dict(slug=slug, country_code=code, country_name=name, source_locale=loc, flag=flag,
        gender=gender, name=full, sector=skey, activity=activity, loan_use_theme=use,
        amount_cents=amount, term_months=term, state=state, funded_pct=funded_pct,
        disbursed=disbursed, paid_count=paid, start_offset_months=off, overdue=overdue,
        image=image, trust_model=random.choice(TRUST), partner_slug=mfi[0], partner_name=mfi[1],
        lender_count=lenders, ts_nonsource=tstatus()))

with open(f"{OUT}/params.json","w") as f: json.dump(loans,f,ensure_ascii=False,indent=1)

from collections import Counter
print("total:",len(loans))
print("states:",dict(Counter(l['state'] for l in loans)))
print("countries:",dict(Counter(l['country_code'] for l in loans)))
print("sectors:",dict(Counter(l['sector'] for l in loans)))
print("gender:",dict(Counter(l['gender'] for l in loans)))
print("images needed:",len(set(l['image'] for l in loans)))
print("sample:",json.dumps(loans[0],ensure_ascii=False))

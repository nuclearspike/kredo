# Kiva Future Demo seed data.
#
# Idempotent: safe to run repeatedly (`mix run priv/repo/seeds.exs` or
# `mix ecto.reset`). Fake/demo data only — no real PII, no real money.

alias Kiva.Repo
alias Kiva.Localization.Locale
alias Kiva.Accounts
alias Kiva.Accounts.{Role, Permission, PermissionGroup, User}

import Ecto.Query

IO.puts("\n== Seeding locales ==")

locales = [
  %{code: "en", english_name: "English", native_name: "English", fallback_code: nil},
  %{code: "de", english_name: "German", native_name: "Deutsch", fallback_code: "en"},
  %{code: "es", english_name: "Spanish", native_name: "Español", fallback_code: "en"},
  %{code: "fr", english_name: "French", native_name: "Français", fallback_code: "en"},
  %{code: "nl", english_name: "Dutch", native_name: "Nederlands", fallback_code: "en"}
]

for attrs <- locales do
  %Locale{}
  |> Locale.changeset(attrs)
  |> Repo.insert!(
    on_conflict: {:replace, [:english_name, :native_name, :fallback_code, :enabled, :updated_at]},
    conflict_target: :code
  )
end

IO.puts("== Seeding roles ==")

roles = [
  {"borrower", "Borrower"},
  {"lender", "Lender"},
  {"partner", "Partner"},
  {"staff", "Staff"},
  {"admin", "Administrator"}
]

for {key, label} <- roles do
  Repo.insert!(%Role{key: key, label: label}, on_conflict: :nothing, conflict_target: :key)
end

IO.puts("== Seeding permissions ==")

permissions = [
  {"view_loans", "View loans", "low"},
  {"set_locale", "Change locale", "low"},
  {"fund_loan", "Fund a loan", "medium"},
  {"create_lending_team", "Create a lending team", "medium"},
  {"write_encouragement", "Write encouragement", "medium"},
  {"create_loan_application", "Create loan application", "medium"},
  {"submit_loan_for_review", "Submit loan for review", "high"},
  {"approve_translation", "Approve translation", "medium"},
  {"moderate_messages", "Moderate messages", "medium"},
  {"approve_loan_listing", "Approve loan listing", "high"},
  {"manage_permissions", "Manage permissions", "high"}
]

for {key, label, risk} <- permissions do
  Repo.insert!(%Permission{key: key, label: label, risk_level: risk},
    on_conflict: {:replace, [:label, :risk_level, :updated_at]},
    conflict_target: :key
  )
end

perm_id = Map.new(Repo.all(Permission), &{&1.key, &1.id})

IO.puts("== Seeding permission groups ==")

groups = [
  {"borrower_default", "Borrower default", ["view_loans", "set_locale"]},
  {"lender_default", "Lender default",
   ["view_loans", "set_locale", "fund_loan", "create_lending_team", "write_encouragement"]},
  {"partner_default", "Partner default",
   ["view_loans", "set_locale", "create_loan_application", "submit_loan_for_review"]},
  {"staff_default", "Staff default",
   [
     "view_loans",
     "set_locale",
     "approve_translation",
     "moderate_messages",
     "approve_loan_listing"
   ]},
  {"admin_default", "Admin default", Enum.map(permissions, fn {k, _, _} -> k end)}
]

for {key, label, perm_keys} <- groups do
  group =
    Repo.insert!(%PermissionGroup{key: key, label: label},
      on_conflict: {:replace, [:label, :updated_at]},
      conflict_target: :key
    )

  rows =
    for pk <- perm_keys, do: %{permission_group_id: group.id, permission_id: perm_id[pk]}

  Repo.insert_all("permission_group_permissions", rows,
    on_conflict: :nothing,
    conflict_target: [:permission_group_id, :permission_id]
  )
end

group_id = Map.new(Repo.all(PermissionGroup), &{&1.key, &1.id})

# One-time migration for pre-rebrand databases: demo accounts moved from the
# legacy demo domains to @kredo.test. Idempotent; no-op on fresh databases.
legacy_domains = ["@" <> "kiva.org", "@" <> "demo.kiva"]
legacy_q = from(u in User, where: like(u.email, "%@kiva.org") or like(u.email, "%@demo.kiva"))

for u <- Repo.all(legacy_q) do
  new_email =
    Enum.reduce(legacy_domains, u.email, &String.replace(&2, &1, "@kredo.test"))

  unless Repo.get_by(User, email: new_email) do
    u |> Ecto.Changeset.change(email: new_email) |> Repo.update!()
  end
end

IO.puts("== Seeding demo users ==")

users = [
  %{
    email: "borrower@kredo.test",
    password: "password",
    role: "borrower",
    default_locale_code: "es",
    display_name: "Rosa Alvarez",
    avatar_url: "/images/borrowers/rosa.jpg"
  },
  %{
    email: "lender@kredo.test",
    password: "password",
    role: "lender",
    default_locale_code: "en",
    display_name: "Morgan Lee",
    avatar_url: "/images/lenders/l2.jpg"
  },
  %{
    email: "partner@kredo.test",
    password: "password",
    role: "partner",
    default_locale_code: "es",
    display_name: "Ana Morales",
    avatar_url: "/images/lenders/l1.jpg"
  },
  %{
    email: "admin@kredo.test",
    password: "password",
    role: "admin",
    default_locale_code: "en",
    display_name: "Jordan Staff",
    avatar_url: "/images/lenders/l3.jpg"
  }
]

for attrs <- users do
  user =
    case Accounts.get_user_by_email(attrs.email) do
      nil ->
        {:ok, u} = Accounts.register_user(attrs)
        u

      existing ->
        existing
    end

  gid = group_id["#{user.role}_default"]

  if gid do
    Repo.insert_all("user_permission_groups", [%{user_id: user.id, permission_group_id: gid}],
      on_conflict: :nothing,
      conflict_target: [:user_id, :permission_group_id]
    )
  end
end

# --- Developer portal demo (the lender doubles as a developer) ---
IO.puts("== Seeding developer portal demo ==")

if demo_dev = Accounts.get_user_by_email("lender@kredo.test") do
  {:ok, demo_dev} = Accounts.enable_developer(demo_dev)

  demo_app =
    Kiva.Developers.upsert_app(demo_dev, "app_demo_kivalens", "secret_demo_kivalens_2026", %{
      "name" => "KivaLens Demo",
      "description" => "Sample application for trying the Kiva Future APIs.",
      "website" => "https://example.com",
      "redirect_uris" => ["http://localhost:4100/oauth/callback"]
    })

  demo_key = "kva_live_demokey0001_demosecrettoken000000"
  Kiva.Developers.upsert_api_key(demo_app, demo_key, "demo")

  IO.puts("""
    developer login   : lender@kredo.test / password
    app_id (client_id): #{demo_app.app_id}
    client_secret     : secret_demo_kivalens_2026
    API key           : #{demo_key}
  """)
end

IO.puts("== Seeding a permission outlier (demo) ==")

lender_u = Kiva.Accounts.get_user_by_email("lender@kredo.test")
admin_u = Kiva.Accounts.get_user_by_email("admin@kredo.test")

if lender_u && admin_u do
  Kiva.Permissions.grant_direct(
    lender_u.id,
    "approve_loan_listing",
    admin_u.id,
    "Temporary elevated access (demo outlier)"
  )
end

IO.puts("== Seeding taxonomy ==")

sector_defs = [
  {"arts", %{"en" => "Arts", "es" => "Artes", "fr" => "Arts", "de" => "Kunst", "nl" => "Kunst"}},
  {"agriculture",
   %{
     "en" => "Agriculture",
     "es" => "Agricultura",
     "fr" => "Agriculture",
     "de" => "Landwirtschaft",
     "nl" => "Landbouw"
   }},
  {"food",
   %{
     "en" => "Food",
     "es" => "Alimentación",
     "fr" => "Alimentation",
     "de" => "Lebensmittel",
     "nl" => "Voeding"
   }}
]

sector_id =
  for {key, names} <- sector_defs, into: %{} do
    s = Kiva.Taxonomy.upsert_sector(key)

    for {loc, name} <- names do
      Kiva.Taxonomy.upsert_sector_lc(%{
        sector_id: s.id,
        locale_code: loc,
        name: name,
        is_source: loc == "en",
        source_locale_code: "en",
        translation_status: "published"
      })
    end

    {key, s.id}
  end

activity_defs = [
  {"textiles", "arts",
   %{
     "en" => "Textiles",
     "es" => "Textiles",
     "fr" => "Textile",
     "de" => "Textilien",
     "nl" => "Textiel"
   }},
  {"farming", "agriculture",
   %{
     "en" => "Farming",
     "es" => "Agricultura",
     "fr" => "Agriculture",
     "de" => "Landwirtschaft",
     "nl" => "Landbouw"
   }},
  {"bakery", "food",
   %{
     "en" => "Bakery",
     "es" => "Panadería",
     "fr" => "Boulangerie",
     "de" => "Bäckerei",
     "nl" => "Bakkerij"
   }}
]

activity_id =
  for {key, skey, names} <- activity_defs, into: %{} do
    a = Kiva.Taxonomy.upsert_activity(key, sector_id[skey])

    for {loc, name} <- names do
      Kiva.Taxonomy.upsert_activity_lc(%{
        activity_id: a.id,
        locale_code: loc,
        name: name,
        is_source: loc == "en",
        source_locale_code: "en",
        translation_status: "published"
      })
    end

    {key, a.id}
  end

IO.puts("== Seeding partners ==")

partner_defs = [
  %{
    slug: "community-loom-cooperative",
    country_code: "GT",
    trust_model: "partner_facilitated",
    image_url: "/images/partners/community-loom.jpg",
    lc: %{
      "en" =>
        {"Community Loom Cooperative",
         "Supports artisan weavers and small rural textile businesses.",
         "A Guatemalan cooperative helping artisan weavers access working capital and reach larger markets."},
      "es" =>
        {"Cooperativa Telar Comunitario",
         "Apoya a tejedoras artesanas y pequeños negocios textiles rurales.",
         "Una cooperativa guatemalteca que ayuda a las tejedoras artesanas a acceder a capital de trabajo y llegar a mercados más grandes."},
      "de" =>
        {"Community Loom Cooperative",
         "Unterstützt kunsthandwerkliche Weber:innen und kleine ländliche Textilbetriebe.",
         "Eine guatemaltekische Kooperative, die kunsthandwerklichen Weber:innen hilft, Betriebskapital zu erhalten und größere Märkte zu erreichen."},
      "fr" =>
        {"Community Loom Cooperative",
         "Soutient les tisserands artisanaux et les petites entreprises textiles rurales.",
         "Une coopérative guatémaltèque qui aide les tisserands artisanaux à accéder à un fonds de roulement et à atteindre de plus grands marchés."},
      "nl" =>
        {"Community Loom Cooperative",
         "Ondersteunt ambachtelijke wevers en kleine landelijke textielbedrijven.",
         "Een Guatemalteekse coöperatie die ambachtelijke wevers helpt werkkapitaal te verkrijgen en grotere markten te bereiken."}
    }
  },
  %{
    slug: "green-fields-microfinance",
    country_code: "KE",
    trust_model: "partner_facilitated",
    image_url: "/images/partners/green-fields.jpg",
    lc: %{
      "en" =>
        {"Green Fields Microfinance", "Supports smallholder farmers and climate resilience.",
         "A Kenyan microfinance partner focused on smallholder farmers adapting to a changing climate."},
      "es" =>
        {"Green Fields Microfinance",
         "Apoya a los pequeños agricultores y la resiliencia climática.",
         "Un socio keniano de microfinanzas centrado en pequeños agricultores que se adaptan a un clima cambiante."},
      "de" =>
        {"Green Fields Microfinance",
         "Unterstützt Kleinbäuerinnen und Kleinbauern sowie die Klimaresilienz.",
         "Ein kenianischer Mikrofinanzpartner mit Fokus auf Kleinbäuerinnen und Kleinbauern, die sich an ein sich wandelndes Klima anpassen."},
      "fr" =>
        {"Green Fields Microfinance",
         "Soutient les petits exploitants agricoles et la résilience climatique.",
         "Un partenaire kenyan de microfinance axé sur les petits exploitants qui s'adaptent à un climat changeant."},
      "nl" =>
        {"Green Fields Microfinance", "Ondersteunt kleine boeren en klimaatbestendigheid.",
         "Een Keniaanse microfinancieringspartner gericht op kleine boeren die zich aanpassen aan een veranderend klimaat."}
    }
  },
  %{
    slug: "austin-community-trust-hub",
    country_code: "US",
    trust_model: "trustee_backed",
    image_url: "/images/partners/austin.jpg",
    lc: %{
      "en" =>
        {"Austin Community Trust Hub",
         "Supports underestimated local entrepreneurs through social underwriting.",
         "A US trustee hub backing local entrepreneurs through endorsements and social underwriting."},
      "es" =>
        {"Austin Community Trust Hub",
         "Apoya a emprendedores locales subestimados mediante aval social.",
         "Un centro de fideicomisarios de EE. UU. que respalda a emprendedores locales mediante avales y garantía social."},
      "de" =>
        {"Austin Community Trust Hub",
         "Unterstützt unterschätzte lokale Unternehmer:innen durch soziale Bürgschaft.",
         "Ein US-Treuhandzentrum, das lokale Unternehmer:innen durch Empfehlungen und soziale Bürgschaft unterstützt."},
      "fr" =>
        {"Austin Community Trust Hub",
         "Soutient les entrepreneurs locaux sous-estimés grâce à la caution sociale.",
         "Un centre de fiduciaires américain qui soutient les entrepreneurs locaux par des recommandations et une caution sociale."},
      "nl" =>
        {"Austin Community Trust Hub",
         "Ondersteunt ondergewaardeerde lokale ondernemers via sociale borgstelling.",
         "Een Amerikaans trustee-centrum dat lokale ondernemers steunt via aanbevelingen en sociale borgstelling."}
    }
  }
]

partner_id =
  for p <- partner_defs, into: %{} do
    partner =
      Kiva.Partners.upsert_partner(%{
        slug: p.slug,
        country_code: p.country_code,
        trust_model: p.trust_model,
        status: "active",
        image_url: p[:image_url],
        default_locale_code: "en"
      })

    for {loc, {name, summary, profile}} <- p.lc do
      Kiva.Partners.upsert_partner_lc(%{
        partner_id: partner.id,
        locale_code: loc,
        is_source: loc == "en",
        source_locale_code: "en",
        name: name,
        summary: summary,
        profile: profile,
        translation_status: if(loc == "en", do: "published", else: "approved")
      })
    end

    {p.slug, partner.id}
  end

IO.puts("== Seeding borrowers ==")

borrower_user = Kiva.Accounts.get_user_by_email("borrower@kredo.test")

borrower_defs = [
  %{
    public_id: "rosa-alvarez",
    country_code: "GT",
    preferred_locale_code: "es",
    image_url: "/images/borrowers/rosa.jpg",
    gender: "female",
    partner: "community-loom-cooperative",
    sector: "arts",
    activity: "textiles",
    user_id: borrower_user && borrower_user.id,
    lc: %{
      "es" => {"Rosa Alvarez", "Tejedora artesana en Guatemala.", "Taller de tejido de Rosa"},
      "en" => {"Rosa Alvarez", "An artisan weaver in Guatemala.", "Rosa's Weaving Studio"}
    }
  },
  %{
    public_id: "amina-okello",
    country_code: "KE",
    preferred_locale_code: "en",
    image_url: "/images/borrowers/amina.jpg",
    gender: "female",
    partner: "green-fields-microfinance",
    sector: "agriculture",
    activity: "farming",
    user_id: nil,
    lc: %{
      "en" => {"Amina Okello", "Leads a seed cooperative in Kenya.", "Amina's Seed Cooperative"}
    }
  },
  %{
    public_id: "sofia-martinez",
    country_code: "US",
    preferred_locale_code: "es",
    image_url: "/images/borrowers/sofia.jpg",
    gender: "female",
    partner: "austin-community-trust-hub",
    sector: "food",
    activity: "bakery",
    user_id: nil,
    lc: %{
      "es" => {"Sofía Martínez", "Vende pan en Austin.", "Carrito de panadería de Sofía"},
      "en" => {"Sofia Martinez", "Sells bread in Austin.", "Sofia's Bakery Cart"}
    }
  }
]

borrower_id =
  for b <- borrower_defs, into: %{} do
    borrower =
      case Kiva.Repo.get_by(Kiva.Borrowers.Borrower, public_id: b.public_id) do
        nil ->
          {:ok, created} =
            %Kiva.Borrowers.Borrower{}
            |> Kiva.Borrowers.Borrower.changeset(%{
              public_id: b.public_id,
              country_code: b.country_code,
              preferred_locale_code: b.preferred_locale_code,
              image_url: b[:image_url],
              gender: b[:gender],
              partner_id: partner_id[b.partner],
              sector_id: sector_id[b.sector],
              activity_id: activity_id[b.activity],
              user_id: b.user_id
            })
            |> Kiva.Repo.insert()

          created

        existing ->
          existing
      end

    for {loc, {name, bio, biz}} <- b.lc do
      Kiva.Repo.insert!(
        Kiva.Borrowers.BorrowerLc.changeset(%Kiva.Borrowers.BorrowerLc{}, %{
          borrower_id: borrower.id,
          locale_code: loc,
          is_source: loc == b.preferred_locale_code,
          source_locale_code: b.preferred_locale_code,
          display_name: name,
          public_bio: bio,
          business_summary: biz,
          translation_status: "published"
        }),
        on_conflict: {:replace, [:display_name, :public_bio, :business_summary]},
        conflict_target: [:borrower_id, :locale_code, :version]
      )
    end

    {b.public_id, borrower.id}
  end

IO.puts("== Seeding loans ==")

loan_defs = [
  %{
    slug: "rosa-weaving-second-loan",
    borrower: "rosa-alvarez",
    partner: "community-loom-cooperative",
    country_code: "GT",
    sector: "arts",
    activity: "textiles",
    trust_model: "partner_facilitated",
    disbursal_status: "pre_disbursed",
    amount: 95_000,
    funded: 72_500,
    term: 8,
    source: "es",
    lc: %{
      "es" =>
        {"Segundo préstamo para el taller de Rosa",
         "Comprar hilo de algodón y tintes naturales para un pedido mayor.",
         "Rosa teje textiles tradicionales en Guatemala. Con este segundo préstamo ampliará su taller para cumplir un pedido más grande.",
         "Comprar hilo de algodón y tintes naturales.", "Pagos mensuales durante 8 meses.",
         "Préstamo facilitado por un socio local con buen historial de reembolso."},
      "en" =>
        {"Rosa's second weaving loan", "Buy cotton thread and natural dyes for a larger order.",
         "Rosa weaves traditional textiles in Guatemala. This second loan helps her expand her studio to fill a larger order.",
         "Buy cotton thread and natural dyes.", "Monthly repayments over 8 months.",
         "Partner-facilitated loan with a strong repayment history."},
      "de" =>
        {"Rosas zweiter Webkredit",
         "Baumwollgarn und natürliche Farbstoffe für einen größeren Auftrag kaufen.",
         "Rosa webt traditionelle Textilien in Guatemala. Dieser zweite Kredit hilft ihr, ihre Werkstatt zu erweitern, um einen größeren Auftrag zu erfüllen.",
         "Baumwollgarn und natürliche Farbstoffe kaufen.",
         "Monatliche Rückzahlungen über 8 Monate.",
         "Von einem Partner vermittelter Kredit mit solider Rückzahlungshistorie."},
      "fr" =>
        {"Le deuxième prêt de tissage de Rosa",
         "Acheter du fil de coton et des teintures naturelles pour une commande plus importante.",
         "Rosa tisse des textiles traditionnels au Guatemala. Ce deuxième prêt l'aide à agrandir son atelier pour honorer une commande plus importante.",
         "Acheter du fil de coton et des teintures naturelles.",
         "Remboursements mensuels sur 8 mois.",
         "Prêt facilité par un partenaire, avec un solide historique de remboursement."},
      "nl" =>
        {"Rosa's tweede weeflening",
         "Koop katoendraad en natuurlijke kleurstoffen voor een grotere bestelling.",
         "Rosa weeft traditioneel textiel in Guatemala. Deze tweede lening helpt haar haar atelier uit te breiden voor een grotere bestelling.",
         "Koop katoendraad en natuurlijke kleurstoffen.",
         "Maandelijkse aflossingen over 8 maanden.",
         "Door een partner gefaciliteerde lening met een sterke aflossingsgeschiedenis."}
    }
  },
  %{
    slug: "amina-climate-seeds",
    borrower: "amina-okello",
    partner: "green-fields-microfinance",
    country_code: "KE",
    sector: "agriculture",
    activity: "farming",
    trust_model: "partner_facilitated",
    disbursal_status: "pre_disbursed",
    amount: 120_000,
    funded: 117_500,
    term: 10,
    source: "en",
    lc: %{
      "en" =>
        {"Drought-resistant seeds for Amina's farm",
         "Purchase drought-resistant seeds and irrigation supplies.",
         "Amina leads a seed cooperative in Kenya adapting to a drier climate. This loan funds resilient seed stock.",
         "Purchase drought-resistant seeds and irrigation supplies.",
         "Monthly repayments over 10 months.",
         "Partner-facilitated; the field partner supports climate resilience."},
      "es" =>
        {"Semillas resistentes a la sequía para la granja de Amina",
         "Comprar semillas resistentes a la sequía y riego.",
         "Amina dirige una cooperativa de semillas en Kenia que se adapta a un clima más seco. Este préstamo financia semillas resistentes.",
         "Comprar semillas resistentes a la sequía y suministros de riego.",
         "Pagos mensuales durante 10 meses.",
         "Facilitado por un socio; el socio local apoya la resiliencia climática."},
      "de" =>
        {"Dürreresistentes Saatgut für Aminas Farm",
         "Dürreresistentes Saatgut und Bewässerungsmaterial kaufen.",
         "Amina leitet in Kenia eine Saatgutkooperative, die sich an ein trockeneres Klima anpasst. Dieser Kredit finanziert widerstandsfähiges Saatgut.",
         "Dürreresistentes Saatgut und Bewässerungsmaterial kaufen.",
         "Monatliche Rückzahlungen über 10 Monate.",
         "Von einem Partner vermittelt; der lokale Partner fördert die Klimaresilienz."},
      "fr" =>
        {"Des semences résistantes à la sécheresse pour la ferme d'Amina",
         "Acheter des semences résistantes à la sécheresse et du matériel d'irrigation.",
         "Amina dirige une coopérative de semences au Kenya qui s'adapte à un climat plus sec. Ce prêt finance des stocks de semences résistantes.",
         "Acheter des semences résistantes à la sécheresse et du matériel d'irrigation.",
         "Remboursements mensuels sur 10 mois.",
         "Facilité par un partenaire ; le partenaire de terrain soutient la résilience climatique."},
      "nl" =>
        {"Droogtebestendige zaden voor Amina's boerderij",
         "Koop droogtebestendige zaden en irrigatiemateriaal.",
         "Amina leidt een zadencoöperatie in Kenia die zich aanpast aan een droger klimaat. Deze lening financiert veerkrachtige zadenvoorraden.",
         "Koop droogtebestendige zaden en irrigatiemateriaal.",
         "Maandelijkse aflossingen over 10 maanden.",
         "Door een partner gefaciliteerd; de veldpartner ondersteunt klimaatbestendigheid."}
    }
  },
  %{
    slug: "sofia-bakery-cart",
    borrower: "sofia-martinez",
    partner: "austin-community-trust-hub",
    country_code: "US",
    sector: "food",
    activity: "bakery",
    trust_model: "trustee_backed",
    disbursal_status: "direct_disbursal_pending",
    amount: 300_000,
    funded: 60_000,
    term: 18,
    source: "es",
    lc: %{
      "es" =>
        {"Carrito de panadería para Sofía", "Comprar un carrito de panadería móvil y permisos.",
         "Sofía vende pan en Austin y quiere un carrito móvil para llegar a más clientes.",
         "Comprar carrito de panadería y permisos.", "Pagos mensuales durante 18 meses.",
         "Préstamo directo respaldado por aval social de un fideicomisario."},
      "en" =>
        {"A bakery cart for Sofia", "Buy a mobile bakery cart and permits.",
         "Sofia sells bread in Austin and wants a mobile cart to reach more customers.",
         "Buy a bakery cart and permits.", "Monthly repayments over 18 months.",
         "Direct loan backed by a trustee's social underwriting."},
      "de" =>
        {"Ein Backwagen für Sofia", "Einen mobilen Backwagen und Genehmigungen kaufen.",
         "Sofia verkauft Brot in Austin und möchte einen mobilen Wagen, um mehr Kundschaft zu erreichen.",
         "Einen Backwagen und Genehmigungen kaufen.", "Monatliche Rückzahlungen über 18 Monate.",
         "Direktkredit, abgesichert durch die soziale Bürgschaft eines Treuhänders."},
      "fr" =>
        {"Un chariot de boulangerie pour Sofia",
         "Acheter un chariot de boulangerie mobile et les permis nécessaires.",
         "Sofia vend du pain à Austin et souhaite un chariot mobile pour toucher plus de clients.",
         "Acheter un chariot de boulangerie et les permis nécessaires.",
         "Remboursements mensuels sur 18 mois.",
         "Prêt direct garanti par la caution sociale d'un fiduciaire."},
      "nl" =>
        {"Een broodkar voor Sofia", "Koop een mobiele broodkar en vergunningen.",
         "Sofia verkoopt brood in Austin en wil een mobiele kar om meer klanten te bereiken.",
         "Koop een broodkar en vergunningen.", "Maandelijkse aflossingen over 18 maanden.",
         "Directe lening, gedekt door de sociale borgstelling van een trustee."}
    }
  }
]

for l <- loan_defs do
  loan =
    Kiva.Lending.upsert_loan(%{
      slug: l.slug,
      status: "fundraising",
      partner_id: partner_id[l.partner],
      borrower_id: borrower_id[l.borrower],
      country_code: l.country_code,
      sector_id: sector_id[l.sector],
      activity_id: activity_id[l.activity],
      trust_model: l.trust_model,
      disbursal_status: l.disbursal_status,
      loan_amount_cents: l.amount,
      funded_amount_cents: l.funded,
      currency_code: "USD",
      repayment_term_months: l.term,
      source_locale_code: l.source
    })

  for {loc, {title, short, story, use, repay, risk}} <- l.lc do
    Kiva.Lending.upsert_loan_lc(%{
      loan_id: loan.id,
      locale_code: loc,
      is_source: loc == l.source,
      source_locale_code: l.source,
      title: title,
      short_description: short,
      borrower_story: story,
      loan_use: use,
      repayment_summary: repay,
      risk_summary_public: risk,
      translation_status: if(loc == l.source, do: "published", else: "approved")
    })
  end

  # Idempotent repayment schedule
  if is_nil(Kiva.Repo.preload(loan, :repayment_schedule).repayment_schedule) do
    Kiva.Lending.create_repayment_schedule(loan.id, ~D[2026-07-01], l.term, div(l.amount, l.term))
  end
end

IO.puts("== Linking partner user to org ==")

with %{} = pu <- Kiva.Accounts.get_user_by_email("partner@kredo.test"),
     org_id when not is_nil(org_id) <- partner_id["community-loom-cooperative"] do
  Kiva.Accounts.set_managed_partner(pu, org_id)
end

IO.puts("== Seeding fundraising deadlines (urgency) ==")

for {slug, days} <- [
      {"rosa-weaving-second-loan", 22},
      {"amina-climate-seeds", 6},
      {"sofia-bakery-cart", 40}
    ] do
  case Kiva.Repo.get_by(Kiva.Lending.Loan, slug: slug) do
    nil ->
      :ok

    loan ->
      ends =
        DateTime.utc_now() |> DateTime.add(days * 86_400, :second) |> DateTime.truncate(:second)

      loan |> Ecto.Changeset.change(fundraising_ends_at: ends) |> Kiva.Repo.update!()
  end
end

IO.puts("== Seeding lending teams ==")

team_now = DateTime.utc_now() |> DateTime.truncate(:second)
lender = Kiva.Accounts.get_user_by_email("lender@kredo.test")

team_defs = [
  %{
    slug: "the-coffee-fund",
    source: "en",
    visibility: "public",
    image_url: "/images/teams/coffee.jpg",
    lc: %{
      "en" =>
        {"The Coffee Fund", "Coworkers turning coffee money into working capital.",
         "A team of coworkers pooling small amounts to fund entrepreneurs around the world."}
    }
  },
  %{
    slug: "tejedoras-unidas-supporters",
    source: "es",
    visibility: "public",
    image_url: "/images/teams/weaving.jpg",
    lc: %{
      "es" =>
        {"Tejedoras Unidas Supporters",
         "Apoyando a mujeres artesanas y pequeñas empresas textiles.",
         "Un equipo que apoya a tejedoras artesanas en Guatemala."}
    }
  },
  %{
    slug: "climate-resilience-circle",
    source: "en",
    visibility: "public",
    image_url: "/images/teams/climate.jpg",
    lc: %{
      "en" =>
        {"Climate Resilience Circle", "Loans for farmers adapting to a changing planet.",
         "Backing smallholder farmers building climate resilience."}
    }
  }
]

team_ids =
  for t <- team_defs, into: %{} do
    team =
      Kiva.Teams.upsert_team(%{
        slug: t.slug,
        owner_user_id: lender && lender.id,
        visibility: t.visibility,
        image_url: t.image_url,
        image_source: "external_url",
        default_locale_code: t.source,
        member_count: 1,
        total_lent_cents: 0
      })

    for {loc, {name, tagline, desc}} <- t.lc do
      Kiva.Teams.upsert_team_lc(%{
        lending_team_id: team.id,
        locale_code: loc,
        is_source: loc == t.source,
        source_locale_code: t.source,
        name: name,
        tagline: tagline,
        description: desc,
        translation_status: "published"
      })
    end

    if lender do
      Kiva.Repo.insert_all(
        "lending_team_memberships",
        [
          %{
            lending_team_id: team.id,
            user_id: lender.id,
            role: "owner",
            inserted_at: team_now,
            updated_at: team_now
          }
        ],
        on_conflict: :nothing,
        conflict_target: [:lending_team_id, :user_id]
      )
    end

    {t.slug, team.id}
  end

coffee_id = team_ids["the-coffee-fund"]

if lender && coffee_id &&
     not Kiva.Repo.exists?(from p in "team_posts", where: p.lending_team_id == ^coffee_id) do
  Kiva.Teams.add_post(
    coffee_id,
    lender,
    "Welcome to The Coffee Fund! Let's turn our daily coffee into working capital for entrepreneurs.",
    "en"
  )
end

if lender && not Kiva.Repo.exists?(from l in "lendings", where: l.user_id == ^lender.id) do
  case Kiva.Repo.get_by(Kiva.Lending.Loan, slug: "rosa-weaving-second-loan") do
    nil -> :ok
    rosa -> Kiva.Portfolio.lend(lender, rosa.id, 2500, coffee_id)
  end
end

IO.puts("== Seeding repayment progress (close the loop) ==")

case Kiva.Repo.get_by(Kiva.Lending.Loan, slug: "rosa-weaving-second-loan") do
  nil ->
    :ok

  rosa ->
    loan = Kiva.Repo.preload(rosa, repayment_schedule: :items)

    paid =
      loan.repayment_schedule && Enum.count(loan.repayment_schedule.items, &(&1.status == "paid"))

    if loan.repayment_schedule && paid == 0 do
      Kiva.Lending.record_repayment(rosa.id)
      Kiva.Lending.record_repayment(rosa.id)
    end
end

IO.puts("== Seeding encouragement message ==")

if lender do
  case Kiva.Repo.get_by(Kiva.Lending.Loan, slug: "rosa-weaving-second-loan") do
    nil ->
      :ok

    rosa ->
      unless Kiva.Repo.exists?(from m in "encouragement_messages", where: m.loan_id == ^rosa.id) do
        Kiva.Messaging.create_encouragement(
          lender,
          rosa.id,
          "Your weaving work is beautiful. I hope this loan helps you fill the new order and grow with confidence.",
          "en"
        )
      end
  end
end

IO.puts("== Seeding trust network ==")

case Kiva.Repo.get_by(Kiva.Lending.Loan, slug: "sofia-bakery-cart") do
  nil ->
    :ok

  sofia ->
    trustee =
      Kiva.Trust.upsert_trustee("maria-trustee", "US", %{
        "en" =>
          {"María (Community Trustee)",
           "A neighborhood trustee who vouches for local entrepreneurs."},
        "es" =>
          {"María (Fideicomisaria comunitaria)",
           "Una fideicomisaria del barrio que avala a emprendedores locales."},
        "de" =>
          {"María (Gemeinschafts-Treuhänderin)",
           "Eine Treuhänderin aus der Nachbarschaft, die für lokale Unternehmer:innen bürgt."},
        "fr" =>
          {"María (Fiduciaire communautaire)",
           "Une fiduciaire du quartier qui se porte garante des entrepreneurs locaux."},
        "nl" =>
          {"María (Gemeenschapstrustee)",
           "Een trustee uit de buurt die borg staat voor lokale ondernemers."}
      })

    unless Kiva.Repo.exists?(from e in "trust_endorsements", where: e.loan_id == ^sofia.id) do
      Kiva.Trust.add_endorsement(sofia.id, trustee.id, sofia.borrower_id, "en", %{
        "en" =>
          "I have known Sofía for years; she is reliable and her bakery is loved in the neighborhood.",
        "es" =>
          "Conozco a Sofía desde hace años; es confiable y su panadería es muy querida en el barrio.",
        "de" =>
          "Ich kenne Sofía seit Jahren; sie ist zuverlässig und ihre Bäckerei ist in der Nachbarschaft beliebt.",
        "fr" =>
          "Je connais Sofía depuis des années ; elle est fiable et sa boulangerie est appréciée dans le quartier.",
        "nl" =>
          "Ik ken Sofía al jaren; ze is betrouwbaar en haar bakkerij is geliefd in de buurt."
      })

      Kiva.Trust.add_check(
        sofia.id,
        sofia.borrower_id,
        "identity",
        "passed",
        "Government ID verified"
      )

      Kiva.Trust.add_check(
        sofia.id,
        sofia.borrower_id,
        "watchlist",
        "passed",
        "No watchlist matches"
      )

      Kiva.Trust.add_check(
        sofia.id,
        sofia.borrower_id,
        "business_viability",
        "passed",
        "Bakery cart business plan reviewed"
      )

      Kiva.Trust.attest(sofia.id, "sofia-bakery-cart:trustee_backed:3000")
    end
end

IO.puts("== Seeding localized FAQ ==")

now = DateTime.utc_now() |> DateTime.truncate(:second)

faqs = [
  %{
    slug: "how-lending-works",
    category: "Basics",
    position: 0,
    source_locale: "en",
    translations: %{
      "en" =>
        {"How does lending work?",
         "Lenders contribute to a loan in small increments. When a loan is fully funded, the field partner disburses it. As the borrower repays, lenders are repaid.",
         "published", true},
      "es" =>
        {"¿Cómo funciona el préstamo?",
         "Los prestamistas contribuyen a un préstamo en pequeños incrementos. Cuando un préstamo se financia por completo, el socio local lo desembolsa. A medida que el prestatario paga, se reembolsa a los prestamistas.",
         "approved", false},
      "de" =>
        {"Wie funktioniert das Verleihen?",
         "Kreditgeber:innen tragen in kleinen Schritten zu einem Kredit bei. Sobald ein Kredit vollständig finanziert ist, zahlt der lokale Partner ihn aus. Während der Kreditnehmer zurückzahlt, werden die Kreditgeber:innen zurückbezahlt.",
         "approved", false},
      "fr" =>
        {"Comment fonctionne le prêt ?",
         "Les prêteurs contribuent à un prêt par petits montants. Lorsqu'un prêt est entièrement financé, le partenaire de terrain le décaisse. À mesure que l'emprunteur rembourse, les prêteurs sont remboursés.",
         "approved", false},
      "nl" =>
        {"Hoe werkt uitlenen?",
         "Geldverstrekkers dragen in kleine stappen bij aan een lening. Wanneer een lening volledig is gefinancierd, betaalt de veldpartner deze uit. Naarmate de lener terugbetaalt, worden de geldverstrekkers terugbetaald.",
         "approved", false}
    }
  },
  %{
    slug: "do-lenders-earn-interest",
    category: "Basics",
    position: 1,
    source_locale: "en",
    translations: %{
      "en" =>
        {"Do I earn interest on what I lend?",
         "No. Lending here pays you 0% — the most that can come back is exactly what you lent, and defaults mean it is often less. The borrower does pay interest, but it goes to the local field partner that vets the borrower, disburses the money, and collects repayments; none of it reaches you. What you get back is your money, ready to lend again, and the impact it had.",
         "published", true},
      "es" =>
        {"¿Gano intereses por lo que presto?",
         "No. Prestar aquí te paga un 0%: lo máximo que puede volver es exactamente lo que prestaste, y por los impagos suele ser menos. El prestatario sí paga intereses, pero van al socio local que lo evalúa, desembolsa el dinero y cobra los pagos; nada llega a ti. Lo que recuperas es tu dinero, listo para prestar de nuevo, y el impacto que tuvo.",
         "approved", false},
      "de" =>
        {"Erhalte ich Zinsen auf mein verliehenes Geld?",
         "Nein. Verleihen bringt Ihnen hier 0 % — zurückkommen kann höchstens genau das, was Sie verliehen haben, und durch Ausfälle ist es oft weniger. Der Kreditnehmer zahlt zwar Zinsen, doch die gehen an den lokalen Partner, der ihn prüft, das Geld auszahlt und die Rückzahlungen einsammelt; nichts davon erreicht Sie. Zurück erhalten Sie Ihr Geld, bereit zum erneuten Verleihen, und die Wirkung, die es hatte.",
         "approved", false},
      "fr" =>
        {"Est-ce que je gagne des intérêts sur mes prêts ?",
         "Non. Prêter ici vous rapporte 0 % : au mieux, vous récupérez exactement ce que vous avez prêté, et les défauts de paiement font que c'est souvent moins. L'emprunteur paie bien des intérêts, mais ils reviennent au partenaire local qui l'évalue, décaisse l'argent et collecte les remboursements ; rien ne vous parvient. Ce que vous récupérez, c'est votre argent, prêt à être reprêté, et l'impact qu'il a eu.",
         "approved", false},
      "nl" =>
        {"Verdien ik rente over wat ik uitleen?",
         "Nee. Uitlenen levert u hier 0% op — het meeste dat kan terugkomen is precies wat u hebt uitgeleend, en door wanbetaling is het vaak minder. De lener betaalt wel rente, maar die gaat naar de lokale partner die hem beoordeelt, het geld uitbetaalt en de aflossingen int; niets daarvan bereikt u. Wat u terugkrijgt is uw geld, klaar om opnieuw uit te lenen, en de impact die het had.",
         "approved", false}
    }
  },
  %{
    slug: "how-repayment-works",
    category: "Basics",
    position: 2,
    source_locale: "en",
    translations: %{
      "en" =>
        {"How does repayment work?",
         "Borrowers repay on a fixed schedule. Repayments flow back to lenders, who can withdraw their funds or re-lend them.",
         "published", true},
      "fr" =>
        {"Comment fonctionne le remboursement ?",
         "Les emprunteurs remboursent selon un calendrier fixe. Les remboursements reviennent aux prêteurs, qui peuvent retirer leurs fonds ou les reprêter.",
         "approved", false},
      "es" =>
        {"¿Cómo funciona el reembolso?",
         "Los prestatarios pagan según un calendario fijo. Los reembolsos regresan a los prestamistas, que pueden retirar sus fondos o volver a prestarlos.",
         "approved", false},
      "de" =>
        {"Wie funktioniert die Rückzahlung?",
         "Kreditnehmer:innen zahlen nach einem festen Zeitplan zurück. Die Rückzahlungen fließen an die Kreditgeber:innen zurück, die ihr Geld abheben oder erneut verleihen können.",
         "approved", false},
      "nl" =>
        {"Hoe werkt terugbetaling?",
         "Leners betalen volgens een vast schema terug. Terugbetalingen vloeien terug naar de geldverstrekkers, die hun geld kunnen opnemen of opnieuw kunnen uitlenen.",
         "approved", false}
    }
  },
  %{
    slug: "partner-vs-direct",
    category: "Trust",
    position: 3,
    source_locale: "en",
    translations: %{
      "en" =>
        {"Partner-facilitated vs direct loans?",
         "Partner-facilitated loans are managed by a local field partner who disburses and collects repayment. Direct loans go straight to a borrower, backed by social underwriting and trustees.",
         "published", true},
      "es" =>
        {"¿Préstamos facilitados por un socio o directos?",
         "Los préstamos facilitados por un socio los gestiona un socio local que desembolsa y cobra el reembolso. Los préstamos directos van directamente a un prestatario, respaldados por aval social y fideicomisarios.",
         "approved", false},
      "de" =>
        {"Von einem Partner vermittelte vs. direkte Kredite?",
         "Von einem Partner vermittelte Kredite werden von einem lokalen Partner verwaltet, der sie auszahlt und die Rückzahlung einzieht. Direkte Kredite gehen unmittelbar an eine Kreditnehmer:in, abgesichert durch soziale Bürgschaft und Treuhänder:innen.",
         "approved", false},
      "fr" =>
        {"Prêts facilités par un partenaire ou directs ?",
         "Les prêts facilités par un partenaire sont gérés par un partenaire de terrain local qui décaisse et collecte le remboursement. Les prêts directs vont directement à un emprunteur, soutenus par une caution sociale et des fiduciaires.",
         "approved", false},
      "nl" =>
        {"Door een partner gefaciliteerde versus directe leningen?",
         "Door een partner gefaciliteerde leningen worden beheerd door een lokale veldpartner die uitbetaalt en de terugbetaling int. Directe leningen gaan rechtstreeks naar een lener, gedekt door sociale borgstelling en trustees.",
         "approved", false}
    }
  }
]

for f <- faqs do
  faq =
    case Kiva.Content.get_faq_by_slug(f.slug) do
      nil ->
        {:ok, created} =
          Kiva.Content.create_faq(%{
            slug: f.slug,
            category: f.category,
            position: f.position,
            source_locale_code: f.source_locale
          })

        created

      existing ->
        # Reconcile ordering/category so re-running the seeds after an FAQ is
        # inserted or reordered leaves the list in the authored order.
        existing
        |> Ecto.Changeset.change(category: f.category, position: f.position)
        |> Repo.update!()
    end

  for {locale, {q, a, status, is_source}} <- f.translations do
    Kiva.Content.upsert_faq_lc(%{
      faq_entry_id: faq.id,
      locale_code: locale,
      is_source: is_source,
      source_locale_code: f.source_locale,
      question: q,
      answer: a,
      translation_status: status,
      version: 1,
      published_at: if(status in ["published", "approved"], do: now)
    })
  end
end

IO.puts(
  "\nSeed complete: #{Repo.aggregate(from(u in "users"), :count)} users, " <>
    "#{length(locales)} locales, #{length(permissions)} permissions.\n"
)

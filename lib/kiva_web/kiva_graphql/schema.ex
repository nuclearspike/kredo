defmodule KivaWeb.KivaGraphql.Schema do
  @moduledoc """
  Modern Kiva-compatible GraphQL surface, mirroring `api.kiva.org/graphql`.

  Everything loan-related lives under the `lend` namespace; the loan type is the
  `LoanBasic` interface resolved to `LoanPartner` / `LoanDirect`. Lists use Kiva's
  `{ totalCount, values }` collection shape (limit/offset), not Relay cursors.
  Backed by `Kiva.Lending` + the shared `KivaWeb.KivaCompat.Mapping` adapter.
  """
  use Absinthe.Schema

  alias KivaWeb.KivaGraphql.Resolvers
  alias KivaWeb.KivaCompat.Mapping

  # --- Custom scalars ------------------------------------------------------

  scalar :money,
    description: "Monetary amount serialized as a 2-decimal string, e.g. \"1200.00\"." do
    serialize(fn cents -> Mapping.money_string(cents) end)
    parse(fn _ -> :error end)
  end

  scalar :date, description: "ISO-8601 date/time." do
    serialize(fn v -> Mapping.iso8601(v) end)
    parse(fn _ -> :error end)
  end

  scalar :url do
    serialize(fn v -> v end)
    parse(fn _ -> :error end)
  end

  # --- Enums ---------------------------------------------------------------

  # Kiva uses lowercase/camelCase enum values (not GraphQL's ALL_CAPS default), so
  # every value gets an explicit `name:` to match the real API byte-for-byte.
  enum :loan_status_enum do
    value(:fundraising, name: "fundraising")
    value(:funded, name: "funded")
    value(:raised, name: "raised")
    value(:paying_back, name: "payingBack")
    value(:ended, name: "ended")
    value(:defaulted, name: "defaulted")
    value(:refunded, name: "refunded")
    value(:expired, name: "expired")
    value(:inactive, name: "inactive")
  end

  enum :loan_search_status_enum do
    value(:fundraising, name: "fundraising")
    value(:funded, name: "funded")
    value(:all, name: "all")
  end

  enum :gender_enum do
    value(:male, name: "male")
    value(:female, name: "female")
    value(:nonbinary, name: "nonbinary")
    value(:unspecified, name: "unspecified")
  end

  enum :distribution_model_enum do
    value(:field_partner, name: "fieldPartner")
    value(:direct, name: "direct")
    value(:both, name: "both")
  end

  enum :anonymization_level_enum do
    value(:none, name: "none")
    value(:public, name: "public")
    value(:full, name: "full")
    value(:pii, name: "pii")
  end

  enum :loan_search_sort_by_enum do
    value(:amount_left, name: "amountLeft")
    value(:expiring_soon, name: "expiringSoon")
    value(:loan_amount, name: "loanAmount")
    value(:loan_amount_desc, name: "loanAmountDesc")
    value(:newest, name: "newest")
    value(:popularity, name: "popularity")
    value(:random, name: "random")
    value(:repayment_term, name: "repaymentTerm")
  end

  # --- Inputs --------------------------------------------------------------

  input_object :min_max_range_input do
    field :min, :float
    field :max, :float
  end

  input_object :loan_search_filters_input do
    field :country, list_of(:string)
    field :theme, list_of(:string)
    field :sector, list_of(:integer)
    field :activity, list_of(:integer)
    field :partner, list_of(:integer)
    field :loan_ids, list_of(:integer)
    field :status, :loan_search_status_enum
    field :gender, :gender_enum
    field :distribution_model, :distribution_model_enum
    field :is_group, :boolean
    field :expiring_soon, :boolean
    field :risk_rating, :min_max_range_input
    field :lender_term, :min_max_range_input
  end

  # --- Supporting object types --------------------------------------------

  object :image do
    field :id, :integer
    field :url, :url
    field :hash, :string
    field :width, :integer
    field :height, :integer
  end

  object :country do
    field :id, :integer
    field :name, :string
    field :iso_code, :string
    field :region, :string
  end

  object :geocode do
    field :city, :string
    field :state, :string
    field :postal_code, :string
    field :latitude, :float
    field :longitude, :float
    field :country, :country
  end

  object :sector do
    field :id, :integer
    field :name, :string
  end

  object :activity do
    field :id, :integer
    field :name, :string
  end

  object :loan_fundraising_info do
    field :id, :id
    field :funded_amount, :money
    field :reserved_amount, :money
    field :is_expiring_soon, :boolean
  end

  object :borrower do
    field :first_name, :string
    field :last_name, :string
    field :gender, :gender_enum
    field :pictured, :boolean
  end

  object :repayment_expected do
    field :due_date, :date
    field :amount, :money
  end

  object :loan_term do
    field :currency, :string
    field :currency_full_name, :string
    field :disbursal_amount, :money
    field :disbursal_date, :date
    field :loan_amount, :money
    field :lender_repayment_term, :integer
    field :loss_liability_nonpayment, :string
    field :loss_liability_currency_exchange, :string
    field :expected_payments, list_of(:repayment_expected)
  end

  object :partner do
    field :id, :integer
    field :name, :string
    field :status, :string
  end

  # --- Authenticated `my` subtree -----------------------------------------

  object :user_account do
    field :id, :integer
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    field :public_id, :string
    field :public, :boolean
    field :balance, :money
    field :promo_balance, :money
  end

  object :lender do
    field :id, :integer
    field :name, :string
    field :public_id, :string
    field :image, :image
    field :loan_count, :integer
    field :invitee_count, :integer
    field :member_since, :date
  end

  object :team do
    field :id, :integer
    field :name, :string
    field :member_count, :integer
  end

  object :team_lender do
    field :id, :integer
    field :team, :team
    field :is_captain, :boolean
    field :amount_lent, :money
  end

  object :team_lender_collection do
    field :total_count, :integer
    field :values, list_of(:team_lender)
  end

  object :my do
    field :id, :integer
    field :user_account, :user_account, resolve: &Resolvers.my_user_account/3
    field :lender, :lender, resolve: &Resolvers.my_lender/3

    field :loans, :loan_basic_collection do
      arg(:limit, :integer)
      arg(:offset, :integer)
      resolve(&Resolvers.my_loans/3)
    end

    field :teams, :team_lender_collection, resolve: &Resolvers.my_teams/3
    field :is_admin, :boolean, resolve: fn u, _, _ -> {:ok, u.role == "admin"} end
    field :is_borrower, :boolean, resolve: fn u, _, _ -> {:ok, u.role == "borrower"} end
  end

  # --- The LoanBasic interface + concrete types ---------------------------

  interface :loan_basic do
    field :id, :integer
    field :name, :string
    field :full_name, :string
    field :use, :string
    field :status, :loan_status_enum
    field :status_label, :string
    field :loan_amount, :money
    field :paid_amount, :money
    field :loan_fundraising_info, :loan_fundraising_info
    field :image, :image
    field :geocode, :geocode
    field :sector, :sector
    field :activity, :activity
    field :gender, :gender_enum
    field :borrower_count, :integer
    field :lender_count, :integer
    field :borrowers, list_of(:borrower)
    field :description, :string
    field :description_in_original_language, :string
    field :distribution_model, :distribution_model_enum
    field :delinquent, :boolean
    field :anonymization_level, :anonymization_level_enum
    field :repayment_interval, :string
    field :lender_repayment_term, :integer
    field :tags, list_of(:string)
    field :disbursal_date, :date
    field :fundraising_date, :date
    field :planned_expiration_date, :date
    field :raised_date, :date
    field :terms, :loan_term

    resolve_type(fn
      %{_distribution: :direct}, _ -> :loan_direct
      _, _ -> :loan_partner
    end)
  end

  object :loan_partner do
    interface(:loan_basic)
    import_fields(:loan_basic)
    field :partner_id, :integer
    field :partner_name, :string
    field :partner, :partner
    field :themes, list_of(:string)
    field :journal_count, :integer
  end

  object :loan_direct do
    interface(:loan_basic)
    import_fields(:loan_basic)
    field :trustee_id, :integer
    field :trustee_name, :string
    field :business_name, :string
    field :business_description, :string
  end

  object :loan_basic_collection do
    field :total_count, :integer
    field :values, list_of(:loan_basic)
  end

  # --- Shop / basket / checkout -------------------------------------------

  input_object :loan_reservation_input do
    field :loan_id, non_null(:integer)
    field :amount_cents, :integer
    @desc "Dollar amount as a string, e.g. \"25.00\" (alternative to amountCents)."
    field :price, :string
  end

  object :loan_reservation do
    field :id, :integer
    field :loan_id, :integer
    field :price, :money
    field :share_amount, :money
  end

  object :basket_item do
    field :loan_id, :integer
    field :amount, :money
  end

  object :manifest do
    field :items, list_of(:basket_item)
    field :total, :money
  end

  object :shop do
    field :basket, :manifest, resolve: &Resolvers.basket/3
  end

  object :shop_mutation do
    @desc "Create a basket; returns the basket id."
    field :create_basket, :string, resolve: &Resolvers.create_basket/3

    @desc "Add/update a loan reservation in the basket (== add to basket)."
    field :update_loan_reservation, :loan_reservation do
      arg(:loan_reservation, non_null(:loan_reservation_input))
      resolve(&Resolvers.update_loan_reservation/3)
    end

    @desc "Check out the basket (records lendings); returns a checkout id."
    field :checkout, :integer do
      arg(:visitor_id, :string)
      resolve(&Resolvers.checkout/3)
    end
  end

  # --- The `lend` namespace + root query ----------------------------------

  object :lend do
    field :loan, :loan_basic do
      arg(:id, :integer)
      resolve(&Resolvers.lend_loan/3)
    end

    field :loans, :loan_basic_collection do
      arg(:filters, :loan_search_filters_input)
      arg(:sort_by, :loan_search_sort_by_enum)
      arg(:query_string, :string)
      arg(:limit, :integer)
      arg(:offset, :integer)
      resolve(&Resolvers.lend_loans/3)
    end

    field :sector, list_of(:sector), resolve: &Resolvers.sectors/3
    field :activity, list_of(:activity), resolve: &Resolvers.activities/3
  end

  query do
    @desc "The public lending surface (loan search + individual loans)."
    field :lend, :lend, resolve: &Resolvers.lend/3

    @desc "The authenticated user's own account, lender profile, loans, and teams."
    field :my, :my, resolve: &Resolvers.my/3

    @desc "Basket reads for the authenticated lender."
    field :shop, :shop do
      arg(:basket_id, :string)
      resolve(&Resolvers.shop_query/3)
    end
  end

  mutation do
    @desc "Basket / checkout mutations for the authenticated lender."
    field :shop, :shop_mutation do
      arg(:basket_id, :string)
      resolve(&Resolvers.shop_mutation/3)
    end
  end
end

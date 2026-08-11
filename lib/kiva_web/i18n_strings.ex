defmodule KivaWeb.I18nStrings do
  @moduledoc """
  Registry of strings that are translated at RUNTIME (via `Gettext.gettext/2` in
  view helpers / notifications) rather than at a literal `gettext("...")` call site.
  `mix gettext.extract` cannot see those, so we list them here as real `gettext`
  macro calls. This function is never used for output — it exists purely so the
  extractor captures these msgids, which then get translated in every locale.
  """
  use Gettext, backend: KivaWeb.Gettext

  def registered do
    [
      # --- Countries ---
      gettext("Guatemala"),
      gettext("Kenya"),
      gettext("United States"),
      gettext("Netherlands"),
      gettext("Peru"),
      gettext("Jordan"),
      gettext("Uganda"),
      gettext("Philippines"),
      gettext("Cambodia"),
      gettext("Nicaragua"),
      gettext("Senegal"),
      gettext("Vietnam"),
      gettext("Bolivia"),
      gettext("Ecuador"),
      gettext("Rwanda"),
      gettext("Tajikistan"),

      # --- Loan status (friendly card labels + raw + browse filter pills) ---
      gettext("Funded"),
      gettext("Repaying"),
      gettext("Repaid in full"),
      gettext("Behind on payments"),
      gettext("Defaulted"),
      gettext("Draft"),
      gettext("delinquent"),
      gettext("defaulted"),
      gettext("repaying"),
      gettext("funded disbursed"),
      gettext("Status"),
      gettext("Fundraising"),
      gettext("Completed"),
      gettext("Delinquent"),
      gettext("All"),

      # --- Actor role labels ---
      gettext("Lender"),
      gettext("Borrower"),
      gettext("Partner"),
      gettext("Staff"),
      gettext("Admin"),
      gettext("Visitor"),

      # --- Trust model labels ---
      gettext("Partner-facilitated"),
      gettext("Direct"),
      gettext("Trustee-backed"),
      gettext("Social underwriting"),
      gettext("Blockchain-attested"),
      gettext("Hybrid"),

      # --- Trust model explanations ---
      gettext("Managed by a local field partner who disburses funds and collects repayment."),
      gettext("Made directly to the borrower with social underwriting."),
      gettext("Backed by a community trustee who vouches for the borrower."),
      gettext("Approved through community endorsements rather than formal credit history."),
      gettext("Loan integrity recorded with a tamper-evident attestation."),
      gettext("Combines partner facilitation with community trust signals."),

      # --- Disbursal labels ---
      gettext("Pre-disbursed"),
      gettext("Post-disbursed"),
      gettext("Awaiting disbursal"),
      gettext("Disbursed"),

      # --- Status labels (humanized underscores) ---
      gettext("draft"),
      gettext("submitted to staff"),
      gettext("staff review"),
      gettext("changes requested"),
      gettext("fundraising"),
      gettext("funded"),
      gettext("completed"),
      gettext("scheduled"),
      gettext("paid"),
      gettext("pending"),
      gettext("approved"),
      gettext("blocked"),
      gettext("flagged"),
      gettext("rejected"),
      gettext("machine"),
      gettext("needs review"),
      gettext("active"),
      gettext("suspended"),
      gettext("passed"),
      gettext("failed"),
      gettext("endorsed"),

      # --- Notification titles + bodies (rendered by type) ---
      gettext("Fully funded! 🎉"),
      gettext("A loan you supported is now fully funded."),
      gettext("Your loan reached the borrower 💸"),
      gettext("The funds you helped provide were disbursed."),
      gettext("Repayment received"),
      gettext("A loan you supported received a repayment — your balance to relend grew."),
      gettext("Outcome on a loan you supported 🌱"),
      gettext("Update on a loan you supported"),
      gettext("Your loan is live! 🎉"),
      gettext("Your loan was approved and is now fundraising."),
      gettext("Changes requested on your loan"),
      gettext("Staff requested changes before this loan can be published.")
    ]
  end
end

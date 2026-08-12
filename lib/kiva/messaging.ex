defmodule Kiva.Messaging do
  @moduledoc """
  Cross-language lender → borrower encouragement. On submit: moderate, then
  persist — approved messages publish the source and machine-translate into the
  borrower's preferred language; blocked/flagged messages are HELD (source kept in
  `draft` with the AI reason) for staff review rather than discarded. Staff can
  override via `approve_message/1` (deliver) or `reject_message/1` (uphold). Every
  outcome records an audit event. Borrowers read only approved messages in their
  own language with a clear machine/human badge.
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Resolver
  alias Kiva.{Moderation, Translation, Audit}
  alias Kiva.Lending.Loan
  alias Kiva.Messaging.{EncouragementMessage, EncouragementMessageLc}

  @doc "Returns {:ok, msg} | {:rejected, reason} | {:rewrite, suggestion}."
  def create_encouragement(sender, loan_id, body, source_locale) do
    loan = Repo.get!(Loan, loan_id) |> Repo.preload(:borrower)
    src = source_locale || "en"

    case Moderation.moderate(body || "") do
      {:rejected, reason} ->
        hold(
          loan,
          sender,
          body,
          src,
          "blocked",
          reason,
          "message.rejected",
          "Encouragement blocked: #{reason}"
        )

        {:rejected, reason}

      {:rewrite, suggestion} ->
        hold(
          loan,
          sender,
          body,
          src,
          "flagged",
          suggestion,
          "message.flagged",
          "Encouragement flagged for review: #{suggestion}"
        )

        {:rewrite, suggestion}

      :approved ->
        msg = insert_message(loan, sender, src, "approved", nil)
        put_lc(msg.id, src, src, true, body, "published")
        translate_to_borrower(msg, loan, body, src)

        Audit.record(%{
          event_type: "message.approved",
          actor_user_id: uid(sender),
          target_type: "loan",
          target_id: to_string(loan_id),
          summary: "Encouragement approved and translated"
        })

        {:ok, msg}
    end
  end

  # A held (blocked/flagged) message is now PERSISTED with its source body so staff
  # can review and override it — not silently discarded.
  defp hold(loan, sender, body, src, status, reason, event_type, summary) do
    msg = insert_message(loan, sender, src, status, reason)
    put_lc(msg.id, src, src, true, body, "draft")

    Audit.record(%{
      event_type: event_type,
      actor_user_id: uid(sender),
      target_type: "loan",
      target_id: to_string(loan.id),
      summary: summary
    })

    msg
  end

  defp insert_message(loan, sender, src, status, reason) do
    {:ok, msg} =
      %EncouragementMessage{}
      |> EncouragementMessage.changeset(%{
        loan_id: loan.id,
        borrower_id: loan.borrower_id,
        sender_user_id: uid(sender),
        moderation_status: status,
        moderation_reason: reason,
        source_locale_code: src
      })
      |> Repo.insert()

    msg
  end

  defp translate_to_borrower(_msg, _loan, nil, _src), do: :ok

  defp translate_to_borrower(msg, loan, body, src) do
    borrower_locale = loan.borrower && loan.borrower.preferred_locale_code

    if borrower_locale && borrower_locale != src do
      put_lc(
        msg.id,
        borrower_locale,
        src,
        false,
        Translation.machine_translate(body, src, borrower_locale),
        "machine"
      )
    end
  end

  @doc """
  Whether a message is still held for a moderation decision: `:held` while it is
  blocked or flagged, `:decided` once staff have approved or upheld the block.
  """
  def moderation_state(message_id) do
    case Repo.get(EncouragementMessage, message_id) do
      nil -> :missing
      %{moderation_status: s} when s in ~w(blocked flagged) -> :held
      _ -> :decided
    end
  end

  @doc "Held encouragement messages (blocked/flagged) awaiting a staff moderation decision."
  def list_moderation_queue(_locale) do
    EncouragementMessage
    |> where([m], m.moderation_status in ["blocked", "flagged"])
    |> order_by([m], desc: m.inserted_at)
    |> preload(:translations)
    |> Repo.all()
    |> Enum.map(fn m ->
      src_lc = Enum.find(m.translations, & &1.is_source)

      %{
        message: m,
        body: src_lc && src_lc.body,
        reason: m.moderation_reason,
        status: m.moderation_status
      }
    end)
  end

  @doc "Staff override: approve a held message — promote the source, translate, and deliver to the borrower."
  def approve_message(msg_id) do
    msg =
      Repo.get!(EncouragementMessage, msg_id) |> Repo.preload([:translations, loan: :borrower])

    src_lc = Enum.find(msg.translations, & &1.is_source)

    if src_lc do
      src_lc
      |> EncouragementMessageLc.changeset(%{translation_status: "published"})
      |> Repo.update!()

      translate_to_borrower(msg, msg.loan, src_lc.body, msg.source_locale_code)
    end

    msg =
      msg |> EncouragementMessage.changeset(%{moderation_status: "approved"}) |> Repo.update!()

    Audit.record(%{
      event_type: "message.override_approved",
      target_type: "loan",
      target_id: to_string(msg.loan_id),
      summary: "Staff approved a held encouragement message"
    })

    {:ok, msg}
  end

  @doc "Staff override: reject a held message (it stays hidden from the borrower)."
  def reject_message(msg_id) do
    msg =
      Repo.get!(EncouragementMessage, msg_id)
      |> EncouragementMessage.changeset(%{moderation_status: "rejected"})
      |> Repo.update!()

    Audit.record(%{
      event_type: "message.override_rejected",
      target_type: "loan",
      target_id: to_string(msg.loan_id),
      summary: "Staff rejected a held encouragement message"
    })

    {:ok, msg}
  end

  def list_for_borrower(borrower_id, locale) do
    EncouragementMessage
    |> where([m], m.borrower_id == ^borrower_id and m.moderation_status == "approved")
    |> order_by([m], desc: m.inserted_at)
    |> preload(:translations)
    |> Repo.all()
    |> Enum.map(&localize(&1, locale))
  end

  def list_for_loan(loan_id, locale) do
    EncouragementMessage
    |> where([m], m.loan_id == ^loan_id and m.moderation_status == "approved")
    |> order_by([m], desc: m.inserted_at)
    |> preload(:translations)
    |> Repo.all()
    |> Enum.map(&localize(&1, locale))
  end

  defp localize(%EncouragementMessage{} = m, locale) do
    res = Resolver.resolve_public(m.translations, locale)

    %{
      message: m,
      body: res.row && res.row.body,
      resolved_locale: res.locale,
      fallback_used: res.fallback_used,
      status: res.row && res.row.translation_status
    }
  end

  defp put_lc(msg_id, locale, src, is_source, body, status) do
    %EncouragementMessageLc{}
    |> EncouragementMessageLc.changeset(%{
      encouragement_message_id: msg_id,
      locale_code: locale,
      source_locale_code: src,
      is_source: is_source,
      body: body,
      translation_status: status
    })
    |> Repo.insert!()
  end

  defp uid(%{id: id}), do: id
  defp uid(_), do: nil
end

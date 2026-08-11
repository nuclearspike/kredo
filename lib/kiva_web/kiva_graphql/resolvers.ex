defmodule KivaWeb.KivaGraphql.Resolvers do
  @moduledoc "Resolvers for the modern Kiva-compatible GraphQL schema (`lend.*`)."
  alias Kiva.{Lending, Taxonomy}
  alias KivaWeb.KivaCompat.Mapping
  alias KivaWeb.KivaGraphql.LoanShape

  def lend(_, _, _), do: {:ok, %{}}

  def lend_loan(_, %{id: id}, %{context: ctx}) do
    case Lending.kiva_get_loan(id) do
      nil ->
        {:ok, nil}

      loan ->
        {:ok, LoanShape.to_map(loan, locale(ctx), %{loan.id => Lending.lender_count(loan.id)})}
    end
  end

  def lend_loan(_, _, _), do: {:ok, nil}

  def lend_loans(_, args, %{context: ctx}) do
    f = args[:filters] || %{}
    locale = locale(ctx)

    opts = %{
      statuses: f[:status] && Mapping.search_statuses(to_string(f[:status])),
      gender: f[:gender] && Mapping.gender_filter(to_string(f[:gender])),
      sector: first(f[:sector]),
      country_codes: f[:country] || [],
      partner_ids: f[:partner] || [],
      q: args[:query_string],
      sort_by: sort_by(args[:sort_by]),
      limit: clamp(args[:limit]),
      offset: max(args[:offset] || 0, 0)
    }

    {loans, total} = Lending.kiva_search(opts)
    counts = Lending.lender_count_map(Enum.map(loans, & &1.id))
    values = Enum.map(loans, &LoanShape.to_map(&1, locale, counts))
    {:ok, %{total_count: total, values: values}}
  end

  def sectors(_, _, %{context: ctx}), do: {:ok, Taxonomy.list_sectors(locale(ctx))}
  def activities(_, _, %{context: ctx}), do: {:ok, Taxonomy.list_activities(locale(ctx))}

  # --- Authenticated `my` subtree -----------------------------------------

  def my(_, _, %{context: %{current_user: %{} = u}}), do: {:ok, u}
  def my(_, _, _), do: {:ok, nil}

  def my_user_account(u, _, _), do: {:ok, user_account(u)}
  def my_lender(u, _, _), do: {:ok, lender(u)}

  def my_loans(u, args, %{context: ctx}) do
    {loans, total} =
      Lending.kiva_lender_loans(u.id, clamp(args[:limit]), max(args[:offset] || 0, 0))

    counts = Lending.lender_count_map(Enum.map(loans, & &1.id))

    {:ok,
     %{total_count: total, values: Enum.map(loans, &LoanShape.to_map(&1, locale(ctx), counts))}}
  end

  def my_teams(u, _, %{context: ctx}) do
    locale = locale(ctx)

    values =
      u.id
      |> Kiva.Teams.kiva_user_teams()
      |> Enum.map(fn t ->
        %{id: t.id, team: team_shape(t, locale), is_captain: nil, amount_lent: nil}
      end)

    {:ok, %{total_count: length(values), values: values}}
  end

  defp user_account(u) do
    {first, last} = split_name(u.display_name)

    %{
      id: u.id,
      first_name: first,
      last_name: last,
      email: u.email,
      public_id: "u#{u.id}",
      public: true,
      balance: 0,
      promo_balance: 0
    }
  end

  defp lender(u) do
    %{
      id: u.id,
      name: u.display_name,
      public_id: "u#{u.id}",
      image: lender_image(u),
      loan_count: Lending.kiva_lender_loan_count(u.id),
      invitee_count: 0,
      member_since: u.inserted_at
    }
  end

  defp lender_image(%{avatar_url: url}) when is_binary(url),
    do: %{id: :erlang.phash2(url, 1_000_000_000), url: url, hash: nil, width: nil, height: nil}

  defp lender_image(_), do: nil

  defp team_shape(t, locale) do
    name =
      case Mapping.resolve(t.translations, locale) do
        %{name: n} when is_binary(n) -> n
        _ -> t.slug
      end

    %{id: t.id, name: name, member_count: t.member_count}
  end

  defp split_name(nil), do: {nil, nil}

  defp split_name(full) do
    case String.split(full, " ", parts: 2) do
      [a, b] -> {a, b}
      [a] -> {a, nil}
    end
  end

  # --- Shop / basket / checkout (mutations) -------------------------------

  @doc "`Mutation.shop` namespace — requires an authenticated lender."
  def shop_mutation(_, _, %{context: %{current_user: %{role: "lender"} = u}}), do: {:ok, u}
  def shop_mutation(_, _, %{context: %{current_user: %{}}}), do: {:error, "lender role required"}
  def shop_mutation(_, _, _), do: {:error, "authentication required"}

  def create_basket(u, _, _), do: {:ok, "basket-#{u.id}"}

  def update_loan_reservation(u, %{loan_reservation: r}, _) do
    loan_id = r[:loan_id]
    amount = reservation_cents(r)

    case Kiva.Commands.execute("add_loan_to_basket", u, %{
           "loan_id" => loan_id,
           "amount_cents" => amount
         }) do
      {:ok, _} -> {:ok, %{id: loan_id, loan_id: loan_id, price: amount, share_amount: amount}}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  def update_loan_reservation(_, _, _), do: {:error, "loanReservation required"}

  def checkout(u, _args, _) do
    case Kiva.Basket.checkout(u) do
      %{skipped: []} ->
        {:ok, :erlang.unique_integer([:positive])}

      %{lent: lent, skipped: skipped} ->
        {:error,
         "checked out #{length(lent)} item(s); #{length(skipped)} kept in the basket (loan no longer fundraising)"}
    end
  end

  @doc "`Query.shop` namespace (basket reads)."
  def shop_query(_, _, %{context: %{current_user: %{} = u}}), do: {:ok, u}
  def shop_query(_, _, _), do: {:ok, nil}

  def basket(u, _, _) do
    items =
      Enum.map(Kiva.Basket.raw_items(u.id), &%{loan_id: &1.loan_id, amount: &1.amount_cents})

    {:ok, %{items: items, total: Kiva.Basket.total_cents(u.id)}}
  end

  defp reservation_cents(r) do
    cond do
      is_integer(r[:amount_cents]) -> r[:amount_cents]
      is_binary(r[:price]) -> price_to_cents(r[:price])
      true -> 2500
    end
  end

  defp price_to_cents(price) do
    case Float.parse(price) do
      {f, _} -> round(f * 100)
      :error -> 2500
    end
  end

  defp locale(ctx), do: (ctx && ctx[:locale]) || "en"

  defp first(nil), do: nil
  defp first([h | _]), do: h
  defp first(_), do: nil

  defp clamp(nil), do: 20
  defp clamp(n) when is_integer(n), do: n |> max(1) |> min(100)

  # GraphQL LoanSearchSortByEnum (atoms) -> our kiva_search sort strings.
  defp sort_by(:amount_left), do: "amount_remaining"
  defp sort_by(:expiring_soon), do: "expiration"
  defp sort_by(:loan_amount), do: "loan_amount"
  defp sort_by(:loan_amount_desc), do: "loan_amount"
  defp sort_by(:popularity), do: "popularity"
  defp sort_by(:random), do: "random"
  defp sort_by(:repayment_term), do: "repayment_term"
  defp sort_by(_), do: "newest"
end

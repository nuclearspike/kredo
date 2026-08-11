defmodule Kiva.TeamsTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Teams, Accounts, Portfolio}
  alias Kiva.Localization.TranslationRequest

  setup do
    {:ok, lender} =
      Accounts.register_user(%{email: "t@kredo.test", password: "password", role: "lender"})

    %{lender: lender}
  end

  test "create_team builds team + source LC + owner membership + translation requests", %{
    lender: lender
  } do
    team =
      Teams.create_team(lender, %{
        "name" => "The Coffee Fund",
        "source_locale_code" => "en",
        "visibility" => "public",
        "tagline" => "coffee to capital"
      })

    assert team.slug == "the-coffee-fund"
    assert team.member_count == 1

    localized = Teams.get_localized_team(team.slug, "en")
    assert localized.name == "The Coffee Fund"
    assert localized.member_count == 1

    # 4 translation requests (5 supported - en source)
    assert Repo.aggregate(
             from(r in TranslationRequest, where: r.entity_type == "lending_team"),
             :count
           ) == 4
  end

  test "list_user_teams returns teams the user belongs to", %{lender: lender} do
    team =
      Teams.create_team(lender, %{
        "name" => "My Team",
        "source_locale_code" => "en",
        "visibility" => "public"
      })

    assert [%{id: id, name: "My Team"}] = Teams.list_user_teams(lender.id, "en")
    assert id == team.id
  end

  test "team_lending_summary surfaces lendings attributed to the team", %{lender: lender} do
    team =
      Teams.create_team(lender, %{
        "name" => "Lender Team",
        "source_locale_code" => "en",
        "visibility" => "public"
      })

    loan = loan_fixture().loan
    Portfolio.lend(lender, loan.id, 2500, team.id)

    summary = Teams.team_lending_summary(team.id, "en")
    assert summary.count == 1
    assert [%{title: "Weaving loan"}] = summary.recent
  end

  test "team page falls back when locale missing", %{lender: lender} do
    team =
      Teams.create_team(lender, %{
        "name" => "Solo EN Team",
        "source_locale_code" => "en",
        "visibility" => "public"
      })

    de = Teams.get_localized_team(team.slug, "de")
    assert de.fallback_used
    assert de.resolved_locale == "en"
    assert de.name == "Solo EN Team"
  end

  test "message board: post and on-demand translate", %{lender: lender} do
    team =
      Teams.create_team(lender, %{
        "name" => "Board Team",
        "source_locale_code" => "en",
        "visibility" => "public"
      })

    post = Teams.add_post(team.id, lender, "Great work on this loan!", "en")

    de = Teams.get_localized_team(team.slug, "de")
    [p] = de.posts
    assert p.fallback_used

    {:ok, _row} = Teams.ensure_post_translation(post.id, "de")
    de2 = Teams.get_localized_team(team.slug, "de")
    [p2] = de2.posts
    refute p2.fallback_used
    assert p2.status == "machine"
    assert p2.body =~ "[de←en]"
  end
end

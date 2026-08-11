defmodule Kiva.CommandsTest do
  use Kiva.DataCase, async: true

  alias Kiva.{Commands, Accounts, Audit}
  alias Kiva.Localization.Locale

  setup do
    for code <- ~w(en es) do
      Repo.insert!(%Locale{code: code, english_name: code, native_name: code})
    end

    {:ok, lender} =
      Accounts.register_user(%{email: "l@kredo.test", password: "password", role: "lender"})

    %{lender: lender}
  end

  test "for_actor scopes commands by role" do
    assert Map.has_key?(Commands.for_actor("lender"), "create_lending_team")
    refute Map.has_key?(Commands.for_actor("lender"), "revoke_permission")
    assert Map.has_key?(Commands.for_actor("admin"), "revoke_permission")
  end

  test "preview enforces role" do
    assert {:error, {:forbidden, "create_lending_team", "borrower"}} =
             Commands.preview("create_lending_team", %{role: "borrower"}, %{
               "name" => "x",
               "source_locale_code" => "en",
               "visibility" => "public"
             })
  end

  test "preview reports missing required inputs" do
    assert {:error, {:missing_inputs, missing}} =
             Commands.preview("create_lending_team", %{role: "lender"}, %{})

    assert "name" in missing
  end

  test "execute set_locale updates the user preference and writes an audit event", %{
    lender: lender
  } do
    assert {:ok, %{locale: "es"}} =
             Commands.execute("set_locale", lender, %{"locale_code" => "es"})

    assert Accounts.get_user(lender.id).default_locale_code == "es"
    assert Enum.any?(Audit.list_events(), &(&1.event_type == "command.set_locale"))
  end

  test "unimplemented commands preview but do not execute" do
    params = %{"name" => "Coffee Fund", "source_locale_code" => "en", "visibility" => "public"}
    assert {:ok, preview} = Commands.preview("create_lending_team", %{role: "lender"}, params)
    assert preview.risk == "medium"

    assert {:error, {:not_implemented, "create_lending_team"}} =
             Commands.execute("create_lending_team", %{role: "lender", id: nil}, params)
  end
end

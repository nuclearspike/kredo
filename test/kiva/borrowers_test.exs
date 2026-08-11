defmodule Kiva.BorrowersTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Borrowers, Commands, Accounts, Repo}

  test "create_borrower onboards a borrower with a source LC row and photo" do
    %{partner: partner} = partner_user_fixture()

    borrower =
      Borrowers.create_borrower(partner.id, %{
        "name" => "New Person",
        "country_code" => "GT",
        "image_url" => "/img/x.jpg",
        "public_bio" => "A weaver"
      })

    assert borrower.partner_id == partner.id
    assert borrower.image_url == "/img/x.jpg"
    assert Borrowers.display_name(Repo.preload(borrower, :translations), "en") == "New Person"
  end

  test "create_borrower runs through the registry (partner only)" do
    %{user: partner_user} = partner_user_fixture()

    assert {:ok, %{target_type: "borrower"}} =
             Commands.execute("create_borrower", partner_user, %{
               "name" => "Cmd Person",
               "country_code" => "KE"
             })

    {:ok, lender} =
      Accounts.register_user(%{
        email: "bl-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: "lender"
      })

    assert {:error, {:forbidden, "create_borrower", "lender"}} =
             Commands.execute("create_borrower", lender, %{"name" => "X"})
  end
end

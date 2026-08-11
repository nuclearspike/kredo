defmodule Kiva.AccountsTest do
  use Kiva.DataCase, async: true

  alias Kiva.Accounts
  alias Kiva.Accounts.User

  describe "register_user/1" do
    test "hashes the password and clears the virtual field" do
      {:ok, %User{} = user} =
        Accounts.register_user(%{email: "A@Kredo.test", password: "password", role: "lender"})

      assert user.email == "a@kredo.test"
      assert is_binary(user.encrypted_password)
      assert user.encrypted_password != "password"
      assert is_nil(user.password)
    end

    test "rejects invalid role" do
      assert {:error, cs} =
               Accounts.register_user(%{
                 email: "b@kredo.test",
                 password: "password",
                 role: "wizard"
               })

      assert %{role: [_]} = errors_on(cs)
    end

    test "enforces unique email" do
      attrs = %{email: "dup@kredo.test", password: "password", role: "lender"}
      assert {:ok, _} = Accounts.register_user(attrs)
      assert {:error, cs} = Accounts.register_user(attrs)
      assert %{email: [_]} = errors_on(cs)
    end
  end

  describe "get_user_by_email_and_password/2" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          email: "login@kredo.test",
          password: "password",
          role: "borrower"
        })

      %{user: user}
    end

    test "returns the user with correct credentials", %{user: user} do
      assert %User{id: id} =
               Accounts.get_user_by_email_and_password("login@kredo.test", "password")

      assert id == user.id
    end

    test "returns nil with wrong password" do
      refute Accounts.get_user_by_email_and_password("login@kredo.test", "nope")
    end

    test "returns nil for unknown email" do
      refute Accounts.get_user_by_email_and_password("ghost@kredo.test", "password")
    end
  end
end

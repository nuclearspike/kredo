defmodule Kiva.ModerationQueueTest do
  @moduledoc "A4 — held-message moderation queue + staff override."
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Messaging, Commands, Accounts}

  setup do
    loan = loan_fixture().loan

    {:ok, lender} =
      Accounts.register_user(%{email: "mq-l@kredo.test", password: "password", role: "lender"})

    {:ok, staff} =
      Accounts.register_user(%{email: "mq-s@kredo.test", password: "password", role: "staff"})

    %{loan: loan, lender: lender, staff: staff}
  end

  test "a blocked message is held (persisted) for review, not silently discarded", %{
    loan: loan,
    lender: lender
  } do
    assert {:rejected, _} =
             Messaging.create_encouragement(lender, loan.id, "you scam loser", "en")

    assert [%{status: "blocked", body: "you scam loser"} | _] =
             Messaging.list_moderation_queue("en")
  end

  test "staff approve_message override delivers it to the borrower", %{
    loan: loan,
    lender: lender,
    staff: staff
  } do
    {:rejected, _} = Messaging.create_encouragement(lender, loan.id, "you scam loser", "en")
    [%{message: msg}] = Messaging.list_moderation_queue("en")

    {:ok, _} = Commands.execute("approve_message", staff, %{"message_id" => to_string(msg.id)})

    assert Messaging.list_moderation_queue("en") == []
    assert [_] = Messaging.list_for_borrower(loan.borrower_id, "en")
  end

  test "staff reject_message upholds the block", %{loan: loan, lender: lender, staff: staff} do
    {:rejected, _} = Messaging.create_encouragement(lender, loan.id, "you scam loser", "en")
    [%{message: msg}] = Messaging.list_moderation_queue("en")

    {:ok, _} = Commands.execute("reject_message", staff, %{"message_id" => to_string(msg.id)})

    assert Messaging.list_moderation_queue("en") == []
    assert Messaging.list_for_borrower(loan.borrower_id, "en") == []
  end
end

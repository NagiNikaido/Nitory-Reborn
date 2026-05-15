defmodule Nitory.EventTest do
  use ExUnit.Case, async: true

  alias Nitory.Event
  alias Nitory.Events.Echo
  alias Nitory.Events.IncomingMessage.{GroupMessage, PrivateMessage}
  alias Nitory.Events.MetaEvent.{Heartbeat, Lifecycle}
  alias Nitory.Events.Notice.{GroupAdmin, GroupBan, GroupIncrease, FriendAdd}
  alias Nitory.Events.Request.{FriendRequest, GroupRequest}

  describe "cast meta_event" do
    test "heartbeat" do
      payload = %{
        "post_type" => "meta_event",
        "meta_event_type" => "heartbeat",
        "time" => 1_680_000_000,
        "self_id" => 12345,
        "interval" => 5_000,
        "status" => %{"online" => true, "good" => true}
      }

      assert {:ok, %Heartbeat{interval: 5_000, status: %{good: true}}} =
               Event.cast(payload)
    end

    test "lifecycle" do
      payload = %{
        "post_type" => "meta_event",
        "meta_event_type" => "lifecycle",
        "time" => 1_680_000_000,
        "self_id" => 12345,
        "sub_type" => "connect"
      }

      assert {:ok, %Lifecycle{sub_type: :connect}} = Event.cast(payload)
    end
  end

  describe "cast message" do
    test "private message" do
      payload = %{
        "post_type" => "message",
        "message_type" => "private",
        "time" => 1_680_000_000,
        "self_id" => 12345,
        "message_id" => 100,
        "user_id" => 67890,
        "message" => "hello",
        "sender" => %{"user_id" => 67890, "nickname" => "TestUser"},
        "sub_type" => "friend"
      }

      assert {:ok, %PrivateMessage{user_id: 67890, message: "hello"}} = Event.cast(payload)
    end

    test "group message" do
      payload = %{
        "post_type" => "message",
        "message_type" => "group",
        "time" => 1_680_000_000,
        "self_id" => 12345,
        "message_id" => 200,
        "user_id" => 111,
        "group_id" => 999,
        "message" => "hi",
        "sender" => %{"user_id" => 111, "nickname" => "GUser"},
        "sub_type" => "normal"
      }

      assert {:ok, %GroupMessage{group_id: 999, message: "hi"}} = Event.cast(payload)
    end
  end

  describe "cast notice" do
    test "group_admin" do
      payload = %{
        "post_type" => "notice",
        "notice_type" => "group_admin",
        "time" => 1_680_000_000,
        "self_id" => 12345,
        "group_id" => 999,
        "user_id" => 111,
        "sub_type" => "set"
      }

      assert {:ok, %GroupAdmin{group_id: 999, sub_type: :set}} = Event.cast(payload)
    end

    test "group_ban" do
      payload = %{
        "post_type" => "notice",
        "notice_type" => "group_ban",
        "time" => 1_680_000_000,
        "self_id" => 12345,
        "group_id" => 999,
        "operator_id" => 111,
        "user_id" => 222,
        "duration" => 600,
        "sub_type" => "ban"
      }

      assert {:ok, %GroupBan{user_id: 222, duration: 600}} = Event.cast(payload)
    end

    test "group_increase" do
      payload = %{
        "post_type" => "notice",
        "notice_type" => "group_increase",
        "time" => 1_680_000_000,
        "self_id" => 12345,
        "group_id" => 999,
        "user_id" => 333,
        "operator_id" => 111,
        "sub_type" => "invite"
      }

      assert {:ok, %GroupIncrease{sub_type: :invite}} = Event.cast(payload)
    end

    test "friend_add" do
      payload = %{
        "post_type" => "notice",
        "notice_type" => "friend_add",
        "time" => 1_680_000_000,
        "self_id" => 12345,
        "user_id" => 444
      }

      assert {:ok, %FriendAdd{user_id: 444}} = Event.cast(payload)
    end
  end

  describe "cast request" do
    test "friend request" do
      payload = %{
        "post_type" => "request",
        "request_type" => "friend",
        "time" => 1_680_000_000,
        "self_id" => 12345,
        "user_id" => 555,
        "comment" => "Hello!",
        "flag" => "abc123"
      }

      assert {:ok, %FriendRequest{user_id: 555, comment: "Hello!"}} = Event.cast(payload)
    end

    test "group request" do
      payload = %{
        "post_type" => "request",
        "request_type" => "group",
        "time" => 1_680_000_000,
        "self_id" => 12345,
        "user_id" => 666,
        "comment" => "pls",
        "flag" => "def456",
        "sub_type" => "invite"
      }

      assert {:ok, %GroupRequest{sub_type: :invite}} = Event.cast(payload)
    end
  end

  describe "cast echo" do
    test "echo response" do
      payload = %{
        "echo" => "42",
        "status" => "ok",
        "retcode" => 0,
        "data" => %{"message_id" => 777}
      }

      assert {:ok, %Echo{echo: "42", retcode: 0}} = Event.cast(payload)
    end
  end

  describe "cast errors" do
    test "unknown post_type" do
      assert {:error, _} = Event.cast(%{"post_type" => "unknown"})
    end

    test "unknown meta_event_type" do
      assert {:error, _} =
               Event.cast(%{"post_type" => "meta_event", "meta_event_type" => "unknown"})
    end
  end
end

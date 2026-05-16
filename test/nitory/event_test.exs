defmodule Nitory.EventTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Nitory.Event
  alias Nitory.Events.Echo
  alias Nitory.Events.IncomingMessage.{GroupMessage, PrivateMessage}
  alias Nitory.Events.MetaEvent.{Heartbeat, Lifecycle}
  alias Nitory.Events.Notice.{GroupAdmin, GroupBan, GroupDecrease, GroupIncrease, GroupRecall, GroupUpload, FriendAdd, FriendRecall}
  alias Nitory.Events.Request.{FriendRequest, GroupRequest}

  describe "cast meta_event" do
    test "heartbeat" do
      payload = %{
        "post_type" => "meta_event",
        "meta_event_type" => "heartbeat",
        "time" => 1_680_000_000,
        "self_id" => 12_345,
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
        "self_id" => 12_345,
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
        "self_id" => 12_345,
        "message_id" => 100,
        "user_id" => 67_890,
        "message" => "hello",
        "sender" => %{"user_id" => 67_890, "nickname" => "TestUser"},
        "sub_type" => "friend"
      }

      assert {:ok, %PrivateMessage{user_id: 67_890, message: "hello"}} = Event.cast(payload)
    end

    test "group message" do
      payload = %{
        "post_type" => "message",
        "message_type" => "group",
        "time" => 1_680_000_000,
        "self_id" => 12_345,
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
        "self_id" => 12_345,
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
        "self_id" => 12_345,
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
        "self_id" => 12_345,
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
        "self_id" => 12_345,
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
        "self_id" => 12_345,
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
        "self_id" => 12_345,
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

  describe "doctests" do
    doctest Nitory.Events.Echo
    doctest Nitory.Events.IncomingMessage.PrivateMessage
    doctest Nitory.Events.IncomingMessage.GroupMessage
    doctest Nitory.Events.MetaEvent.Heartbeat
    doctest Nitory.Events.MetaEvent.Lifecycle
    doctest Nitory.Events.Request.FriendRequest
    doctest Nitory.Events.Request.GroupRequest
    doctest Nitory.Events.Notice.FriendRecall
    doctest Nitory.Events.Notice.FriendAdd
    doctest Nitory.Events.Notice.GroupRecall
    doctest Nitory.Events.Notice.GroupBan
    doctest Nitory.Events.Notice.GroupIncrease
    doctest Nitory.Events.Notice.GroupDecrease
    doctest Nitory.Events.Notice.GroupAdmin
    doctest Nitory.Events.Notice.GroupUpload

  end
  describe "property-based tests" do
    test "Echo cast + dump roundtrips" do
      check all(
              status <- member_of(["ok", "fail"]),
              retcode <- integer(0..999),
              echo <- string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, ev} = Echo.cast(%{"status" => status, "retcode" => retcode, "echo" => echo})
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.status == String.to_existing_atom(status)
        assert dump.echo == echo
      end
    end

    test "PrivateMessage cast + dump roundtrips" do
      check all(
              user_id <- integer(100_000..999_999),
              message_id <- integer(1..999_999),
              nick <- string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, ev} = PrivateMessage.cast(%{
          "time" => 1, "self_id" => 1,
          "post_type" => "message", "message_type" => "private",
          "sub_type" => "friend", "message_id" => message_id,
          "user_id" => user_id, "message" => "hi",
          "sender" => %{"user_id" => user_id, "nickname" => nick}
        })
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.user_id == user_id
      end
    end

    test "GroupMessage cast + dump roundtrips" do
      check all(
              user_id <- integer(100_000..999_999),
              group_id <- integer(100_000..999_999),
              message_id <- integer(1..999_999),
              nick <- string(:alphanumeric, min_length: 1),
              role <- member_of(["owner", "admin", "member"])
            ) do
        assert {:ok, ev} = GroupMessage.cast(%{
          "time" => 1, "self_id" => 1,
          "post_type" => "message", "message_type" => "group",
          "sub_type" => "normal", "message_id" => message_id,
          "user_id" => user_id, "group_id" => group_id, "message" => "hi",
          "sender" => %{"user_id" => user_id, "nickname" => nick, "role" => role}
        })
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.group_id == group_id
        assert dump.sender.role == String.to_existing_atom(role)
      end
    end

    test "Heartbeat cast + dump roundtrips" do
      check all(
              interval <- integer(1_000..60_000),
              online <- boolean()
            ) do
        assert {:ok, ev} = Heartbeat.cast(%{
          "time" => 1, "self_id" => 1,
          "post_type" => "meta_event", "meta_event_type" => "heartbeat",
          "status" => %{"online" => online, "good" => true},
          "interval" => interval
        })
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.interval == interval
      end
    end

    test "Lifecycle cast + dump roundtrips" do
      check all(
              sub_type <- member_of(["enable", "disable", "connect"])
            ) do
        assert {:ok, ev} = Lifecycle.cast(%{
          "time" => 1, "self_id" => 1,
          "post_type" => "meta_event", "meta_event_type" => "lifecycle",
          "sub_type" => sub_type
        })
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.sub_type == String.to_existing_atom(sub_type)
      end
    end

    test "FriendRequest cast + dump roundtrips" do
      check all(
              user_id <- integer(100_000..999_999),
              comment <- string(:alphanumeric, min_length: 1),
              flag <- string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, ev} = FriendRequest.cast(%{
          "time" => 1, "self_id" => 1,
          "post_type" => "request", "request_type" => "friend",
          "user_id" => user_id, "comment" => comment, "flag" => flag
        })
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.user_id == user_id
      end
    end

    test "GroupRequest cast + dump roundtrips" do
      check all(
              user_id <- integer(100_000..999_999),
              sub_type <- member_of(["add", "invite"]),
              comment <- string(:alphanumeric, min_length: 1),
              flag <- string(:alphanumeric, min_length: 1)
            ) do
        assert {:ok, ev} = GroupRequest.cast(%{
          "time" => 1, "self_id" => 1,
          "post_type" => "request", "request_type" => "group",
          "sub_type" => sub_type, "user_id" => user_id,
          "comment" => comment, "flag" => flag
        })
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.sub_type == String.to_existing_atom(sub_type)
      end
    end

    test "GroupAdmin cast + dump roundtrips" do
      check all(sub_type <- member_of(["set", "unset"])) do
        assert {:ok, ev} = GroupAdmin.cast(%{"time" => 1, "self_id" => 1, "post_type" => "notice", "notice_type" => "group_admin", "sub_type" => sub_type, "group_id" => 1, "user_id" => 1})
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.sub_type == String.to_existing_atom(sub_type)
      end
    end

    test "GroupDecrease cast + dump roundtrips" do
      check all(sub_type <- member_of(["leave", "kick", "kick_me", "disband"])) do
        assert {:ok, ev} = GroupDecrease.cast(%{"time" => 1, "self_id" => 1, "post_type" => "notice", "notice_type" => "group_decrease", "sub_type" => sub_type, "group_id" => 1, "user_id" => 1, "operator_id" => 1})
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.sub_type == String.to_existing_atom(sub_type)
      end
    end

    test "GroupIncrease cast + dump roundtrips" do
      check all(sub_type <- member_of(["approve", "invite"])) do
        assert {:ok, ev} = GroupIncrease.cast(%{"time" => 1, "self_id" => 1, "post_type" => "notice", "notice_type" => "group_increase", "sub_type" => sub_type, "group_id" => 1, "user_id" => 1, "operator_id" => 1})
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.sub_type == String.to_existing_atom(sub_type)
      end
    end

    test "GroupBan cast + dump roundtrips" do
      check all(
              sub_type <- member_of(["ban", "lift_ban"]),
              duration <- integer(0..86_400)
            ) do
        assert {:ok, ev} = GroupBan.cast(%{"time" => 1, "self_id" => 1, "post_type" => "notice", "notice_type" => "group_ban", "sub_type" => sub_type, "group_id" => 1, "user_id" => 1, "operator_id" => 1, "duration" => duration})
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.duration == duration
      end
    end

    test "GroupRecall cast + dump roundtrips" do
      check all(message_id <- integer(1..999_999)) do
        assert {:ok, ev} = GroupRecall.cast(%{"time" => 1, "self_id" => 1, "post_type" => "notice", "notice_type" => "group_recall", "group_id" => 1, "user_id" => 1, "operator_id" => 1, "message_id" => message_id})
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.message_id == message_id
      end
    end

    test "GroupUpload cast + dump roundtrips" do
      check all(file_name <- string(:alphanumeric, min_length: 1)) do
        assert {:ok, ev} = GroupUpload.cast(%{"time" => 1, "self_id" => 1, "post_type" => "notice", "notice_type" => "group_upload", "group_id" => 1, "user_id" => 1, "file" => %{"id" => "f1", "name" => file_name, "size" => 100, "busid" => 0}})
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.file.name == file_name
      end
    end

    test "FriendAdd cast + dump roundtrips" do
      check all(user_id <- integer(100_000..999_999)) do
        assert {:ok, ev} = FriendAdd.cast(%{"time" => 1, "self_id" => 1, "post_type" => "notice", "notice_type" => "friend_add", "user_id" => user_id})
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.user_id == user_id
      end
    end

    test "FriendRecall cast + dump roundtrips" do
      check all(message_id <- integer(1..999_999)) do
        assert {:ok, ev} = FriendRecall.cast(%{"time" => 1, "self_id" => 1, "post_type" => "notice", "notice_type" => "friend_recall", "user_id" => 1, "message_id" => message_id})
        dump = Nitory.Helper.LeafSchema.dump(ev)
        assert dump.message_id == message_id
      end
    end
  end
end

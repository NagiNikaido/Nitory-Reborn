defmodule Nitory.SessionManagerTest do
  use Nitory.DataCase

  setup do
    if pid = Process.whereis(Nitory.ApiSlot) do
      Process.exit(pid, :normal)
    end

    unless Process.whereis(Nitory.SessionManager) do
      start_link_supervised!(Nitory.SessionManager)
    end

    Phoenix.PubSub.subscribe(Nitory.PubSub, "socket")
    :ok
  end

  describe "private messages" do
    test "friend private message creates session and dispatches" do
      msg = ~s'{
        "time": 1718000000,
        "post_type": "message",
        "message_type": "private",
        "sub_type": "friend",
        "message_id": 1001,
        "user_id": 234567890,
        "message": [
          { "type": "text", "data": { "text": "你好" } }
        ],
        "raw_message": "你好",
        "font": 0,
        "sender": {
          "user_id": 234567890,
          "nickname": "小明",
          "sex": "male",
          "age": 18
        },
        "self_id": 123456789
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      assert_receive {:receive_from_session, "private:234567890"}
    end

    test "group temp private message with target_id" do
      msg = ~s'{
        "time": 1718000002,
        "post_type": "message",
        "message_type": "private",
        "sub_type": "group",
        "message_id": 1002,
        "user_id": 234567891,
        "target_id": 987654321,
        "temp_source": 0,
        "message": [
          { "type": "text", "data": { "text": "临时会话消息" } }
        ],
        "raw_message": "临时会话消息",
        "font": 0,
        "sender": {
          "user_id": 234567891,
          "nickname": "小红",
          "sex": "female"
        },
        "self_id": 123456789
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      assert_receive {:receive_from_session, "private:234567891"}
    end
  end

  describe "group messages" do
    test "normal group message creates session and dispatches" do
      msg = ~s'{
        "time": 1718000003,
        "post_type": "message",
        "message_type": "group",
        "sub_type": "normal",
        "message_id": 2001,
        "user_id": 345678901,
        "group_id": 987654321,
        "message": [
          { "type": "text", "data": { "text": "大家好" } }
        ],
        "raw_message": "大家好",
        "font": 0,
        "sender": {
          "user_id": 345678901,
          "nickname": "群友A",
          "sex": "female",
          "card": "管理员",
          "role": "admin"
        },
        "self_id": 123456789
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      assert_receive {:receive_from_session, "group:987654321"}
    end

    test "group message with at-mention" do
      msg = ~s'{
        "time": 1718000004,
        "post_type": "message",
        "message_type": "group",
        "sub_type": "normal",
        "message_id": 2002,
        "user_id": 345678902,
        "group_id": 987654321,
        "message": [
          { "type": "at", "data": { "qq": 123456789 } },
          { "type": "text", "data": { "text": "你好！" } }
        ],
        "raw_message": "[CQ:at,qq=123456789]你好！",
        "font": 0,
        "sender": {
          "user_id": 345678902,
          "nickname": "群友B",
          "sex": "male",
          "role": "member"
        },
        "self_id": 123456789
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      assert_receive {:receive_from_session, "group:987654321"}
    end
  end

  describe "meta events" do
    test "heartbeat event is acknowledged" do
      msg = ~s'{
        "time": 1718000100,
        "post_type": "meta_event",
        "meta_event_type": "heartbeat",
        "self_id": 123456789,
        "interval": 5000,
        "status": {
          "online": true,
          "good": true
        }
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      refute_receive {:receive_from_session, _}, 200
    end

    test "lifecycle connect event is acknowledged" do
      msg = ~s'{
        "time": 1718000200,
        "post_type": "meta_event",
        "meta_event_type": "lifecycle",
        "self_id": 123456789,
        "sub_type": "connect"
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      refute_receive {:receive_from_session, _}, 200
    end
  end

  describe "notice events" do
    test "group increase notice is handled" do
      msg = ~s'{
        "time": 1718000300,
        "post_type": "notice",
        "notice_type": "group_increase",
        "self_id": 123456789,
        "group_id": 987654321,
        "user_id": 111222333,
        "operator_id": 345678901,
        "sub_type": "invite"
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      refute_receive {:receive_from_session, _}, 200
    end

    test "group ban notice is handled" do
      msg = ~s'{
        "time": 1718000400,
        "post_type": "notice",
        "notice_type": "group_ban",
        "self_id": 123456789,
        "group_id": 987654321,
        "operator_id": 345678901,
        "user_id": 111222333,
        "duration": 600,
        "sub_type": "ban"
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      refute_receive {:receive_from_session, _}, 200
    end

    test "friend add notice is handled" do
      msg = ~s'{
        "time": 1718000500,
        "post_type": "notice",
        "notice_type": "friend_add",
        "self_id": 123456789,
        "user_id": 444555666
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      refute_receive {:receive_from_session, _}, 200
    end
  end

  describe "request events" do
    test "friend request is dispatched" do
      msg = ~s'{
        "time": 1718000600,
        "post_type": "request",
        "request_type": "friend",
        "self_id": 123456789,
        "user_id": 555666777,
        "comment": "Hello!",
        "flag": "abc123"
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      refute_receive {:receive_from_session, _}, 200
    end

    test "group invite request is dispatched" do
      msg = ~s'{
        "time": 1718000700,
        "post_type": "request",
        "request_type": "group",
        "self_id": 123456789,
        "user_id": 666777888,
        "comment": "pls add me",
        "flag": "def456",
        "sub_type": "invite"
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      refute_receive {:receive_from_session, _}, 200
    end
  end

  describe "error handling" do
    test "malformed JSON returns error without crashing" do
      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, "not valid json"})

      assert_receive {:error, _}
    end

    test "unknown post_type is logged without crashing" do
      msg = ~s'{
        "time": 1718000800,
        "post_type": "unknown_type",
        "self_id": 123456789
      }'

      Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

      refute_receive {:receive_from_session, _}, 200
    end
  end
end

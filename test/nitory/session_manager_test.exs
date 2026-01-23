defmodule Nitory.SessionManagerTest do
  use ExUnit.Case, async: false

  setup do
    start_link_supervised!(Nitory.SessionManager)
    :ok
  end

  test "send msg" do
    Phoenix.PubSub.subscribe(Nitory.PubSub, "socket")
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

    # require IEx
    # IEx.pry()

    Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

    # IEx.pry()
    assert_receive {:receive_from_session, "private:234567890"}

    # Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

    # assert_receive {:receive, _}
    # assert_receive {:receive_from_session, _}

    # msg = ~s'{
    #     "time": 1718000002,
    #     "post_type": "message",
    #     "message_type": "private",
    #     "sub_type": "group",
    #     "message_id": 1002,
    #     "user_id": 234567891,
    #     "target_id": 987654321,
    #     "temp_source": 0,
    #     "message": [
    #         { "type": "text", "data": { "text": "临时会话消息" } }
    #     ],
    #     "raw_message": "临时会话消息",
    #     "font": 0,
    #     "sender": {
    #         "user_id": 234567891,
    #         "nickname": "小红",
    #         "sex": "female"
    #     },
    #     "self_id": 123456789
    # }'

    # Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})

    # assert_receive {:receive, _}
    # assert_receive {:receive_from_session, _}

    # msg = ~s'{
    #     "time": 1718000001,
    #     "post_type": "message",
    #     "message_type": "group",
    #     "sub_type": "normal",
    #     "message_id": 2002,
    #     "user_id": 345678901,
    #     "group_id": 987654321,
    #     "message": [
    #         { "type": "at", "data": { "qq": 123456789 } },
    #         { "type": "text", "data": { "text": "大家好！" } }
    #     ],
    #     "raw_message": "[CQ:at,qq=123456789]大家好！",
    #     "font": 0,
    #     "sender": {
    #         "user_id": 345678901,
    #         "nickname": "群友A",
    #         "sex": "female",
    #         "card": "管理员",
    #         "role": "admin"
    #     },
    #     "self_id": 123456789
    # }'

    # Phoenix.PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, msg})
    # assert_receive {:receive, _}
    # assert_receive {:receive_from_session, _}
  end
end

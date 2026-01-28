defmodule Nitory.EventsTest do
  use ExUnit.Case, async: false

  test "plain private message" do
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

    assert msg
           |> Jason.decode!()
           |> Nitory.Event.cast() ==
             {:ok,
              %Nitory.Events.IncomingMessage.PrivateMessage{
                time: 1_718_000_000,
                post_type: :message,
                message_type: :private,
                sub_type: :friend,
                message_id: 1001,
                user_id: 234_567_890,
                message: [Nitory.Message.Segment.Text.new!(%{data: %{text: "你好"}})],
                raw_message: "你好",
                font: 0,
                sender: %Nitory.Events.IncomingMessage.PrivateMessage.Sender{
                  user_id: 234_567_890,
                  nickname: "小明",
                  sex: :male,
                  age: 18
                },
                self_id: 123_456_789
              }}
  end

  test "private message with temp_source" do
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

    assert msg
           |> Jason.decode!()
           |> Nitory.Event.cast() ==
             {:ok,
              %Nitory.Events.IncomingMessage.PrivateMessage{
                time: 1_718_000_002,
                post_type: :message,
                message_type: :private,
                sub_type: :group,
                message_id: 1002,
                user_id: 234_567_891,
                target_id: 987_654_321,
                temp_source: 0,
                message: [Nitory.Message.Segment.Text.new!(%{data: %{text: "临时会话消息"}})],
                raw_message: "临时会话消息",
                font: 0,
                sender: %Nitory.Events.IncomingMessage.PrivateMessage.Sender{
                  user_id: 234_567_891,
                  nickname: "小红",
                  sex: :female
                },
                self_id: 123_456_789
              }}
  end

  test "plain group message" do
    msg = ~s'{
        "time": 1718000001,
        "post_type": "message",
        "message_type": "group",
        "sub_type": "normal",
        "message_id": 2002,
        "user_id": 345678901,
        "group_id": 987654321,
        "message": [
            { "type": "at", "data": { "qq": 123456789 } },
            { "type": "text", "data": { "text": "大家好！" } }
        ],
        "raw_message": "[CQ:at,qq=123456789]大家好！",
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

    assert msg
           |> Jason.decode!()
           |> Nitory.Event.cast() ==
             {:ok,
              %Nitory.Events.IncomingMessage.GroupMessage{
                time: 1_718_000_001,
                post_type: :message,
                message_type: :group,
                sub_type: :normal,
                message_id: 2002,
                user_id: 345_678_901,
                group_id: 987_654_321,
                message: [
                  Nitory.Message.Segment.At.new!(%{data: %{qq: 123_456_789}}),
                  Nitory.Message.Segment.Text.new!(%{data: %{text: "大家好！"}})
                ],
                raw_message: "[CQ:at,qq=123456789]大家好！",
                font: 0,
                sender: %Nitory.Events.IncomingMessage.GroupMessage.Sender{
                  user_id: 345_678_901,
                  nickname: "群友A",
                  sex: :female,
                  card: "管理员",
                  role: :admin
                },
                self_id: 123_456_789
              }}
  end

  test "some reply" do
    msg = ~s'{
        "status": "ok",
        "retcode": "0",
        "echo": "123",
        "data": {
            "message_id": "123"
        }
    }'

    assert msg
           |> Jason.decode!()
           |> Nitory.Event.cast() ==
             {:ok,
              %Nitory.Events.Echo{
                status: :ok,
                retcode: 0,
                echo: "123",
                data: %{
                  "message_id" => "123"
                },
                post_type: :echo
              }}
  end
end

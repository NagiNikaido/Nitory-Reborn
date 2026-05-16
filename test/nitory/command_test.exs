defmodule Nitory.CommandTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  require Logger

  describe "command options (existing)" do
    test "parsing with regex cmd_face" do
      command = %Nitory.Command{
        display_name: "r",
        hidden: false,
        short_usage: "1",
        usage: "2",
        cmd_face:
          {~r'^r(?<hidden>h?)((?<dice_cnt>[1-9]\d*)|(?<acc>[+\-*/][1-9]\d*))$',
           [:hidden, :dice_cnt, :acc]},
        options: [%Nitory.Command.Option{name: :desc, optional: true}],
        action: fn -> :ok end
      }

      assert {:ok, _} = Nitory.Command.parse(command, ["r+3", "asd"], msg: %{message_type: :group})
      assert {:ok, _} = Nitory.Command.parse(command, ["rh10", "exf"], msg: %{message_type: :group})

      assert {:error, :command_face_not_match} =
               Nitory.Command.parse(command, ["rh20+3", "df"], msg: %{message_type: :group})

      assert {:error, _} = Nitory.Command.parse(command, ["unknown"], msg: %{message_type: :group})
    end
  end

  describe "new/1 property tests" do
    test "visible command with all required fields succeeds" do
      check all(
              display_name <- string(:alphanumeric, min_length: 1),
              short_usage <- string(:alphanumeric, min_length: 1),
              usage <- string(:alphanumeric, min_length: 1),
              msg_type <- member_of([nil, :private, :group])
            ) do
        assert {:ok, cmd} =
                 Nitory.Command.new(
                   hidden: false,
                   display_name: display_name,
                   short_usage: short_usage,
                   usage: usage,
                   cmd_face: display_name,
                   action: fn -> :ok end,
                   msg_type: msg_type
                 )

        assert cmd.hidden == false
      end
    end

    test "hidden command with minimal fields succeeds" do
      check all(
              cmd_face <- string(:alphanumeric, min_length: 1),
              msg_type <- member_of([nil, :private, :group])
            ) do
        assert {:ok, cmd} =
                 Nitory.Command.new(
                   hidden: true,
                   cmd_face: cmd_face,
                   action: fn -> :ok end,
                   msg_type: msg_type
                 )

        assert cmd.hidden == true
      end
    end

    test "new!/1 returns struct or raises" do
      check all(
              display_name <- string(:alphanumeric, min_length: 1),
              short_usage <- string(:alphanumeric, min_length: 1),
              usage <- string(:alphanumeric, min_length: 1)
            ) do
        cmd =
          Nitory.Command.new!(
            hidden: false,
            display_name: display_name,
            short_usage: short_usage,
            usage: usage,
            cmd_face: display_name,
            action: fn -> :ok end
          )

        assert %Nitory.Command{} = cmd
      end
    end

    test "missing required fields returns error" do
      check all(
              missing_key <- member_of([:hidden, :cmd_face, :action])
            ) do
        opts =
          [
            hidden: true,
            cmd_face: "test",
            action: fn -> :ok end
          ]
          |> Keyword.delete(missing_key)

        assert {:error, :required_field_not_found} = Nitory.Command.new(opts)
      end
    end
  end

  describe "parse/3 property tests" do
    test "literal cmd_face matches exact string" do
      check all(
              face <- string(:alphanumeric, min_length: 1),
              msg_type <- member_of([:private, :group])
            ) do
        cmd =
          Nitory.Command.new!(
            hidden: false,
            display_name: face,
            short_usage: "s",
            usage: "u",
            cmd_face: face,
            action: fn -> :ok end,
            msg_type: nil
          )

        assert {:ok, _} =
                 Nitory.Command.parse(cmd, [face], msg: %{message_type: msg_type})
      end
    end

    test "non-matching face returns command_face_not_match" do
      check all(
              face <- string(:alphanumeric, min_length: 1),
              wrong_face <- string(:alphanumeric, min_length: 1),
              face != wrong_face
            ) do
        cmd =
          Nitory.Command.new!(
            hidden: false,
            display_name: face,
            short_usage: "s",
            usage: "u",
            cmd_face: face,
            action: fn -> :ok end,
            msg_type: nil
          )

        assert {:error, :command_face_not_match} =
                 Nitory.Command.parse(cmd, [wrong_face], msg: %{message_type: :group})
      end
    end

    test "msg_type gate rejects mismatched session" do
      check all(
              face <- string(:alphanumeric, min_length: 1)
            ) do
        cmd =
          Nitory.Command.new!(
            hidden: false,
            display_name: face,
            short_usage: "s",
            usage: "u",
            cmd_face: face,
            action: fn -> :ok end,
            msg_type: :private
          )

        assert {:error, {:wrong_msg_type, _, :private}} =
                 Nitory.Command.parse(cmd, [face], msg: %{message_type: :group})
      end
    end
  end
end

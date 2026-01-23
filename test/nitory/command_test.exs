defmodule Nitory.CommandTest do
  use ExUnit.Case, async: false

  require Logger

  test "command options" do
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

    IO.inspect(Nitory.Command.parse(command, ["r+3", "asd"]))
    IO.inspect(Nitory.Command.parse(command, ["rh10", "exf"]))
    IO.inspect(Nitory.Command.parse(command, ["rh20+3", "df"]))
    # IO.inspect(Nitory.Command.parse_optional_arguments([:rest], ["asd"], []))
    # IO.inspect(Nitory.Command.parse_optional_arguments(command.options, ["asd"], []))
  end
end

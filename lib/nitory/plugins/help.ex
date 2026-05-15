defmodule Nitory.Plugins.Help do
  @moduledoc """
  Help plugin providing command listing and usage information.

  `.help` — lists all visible commands with short descriptions.
  `.help <name>` — shows the full usage string for a specific command.
  Also prints a bot banner with version and startup time read from
  application config.
  """

  use Nitory.Plugin

  @impl true
  def handle_call({:help_all}, _from, %{robot: robot} = state) do
    app_info = Application.fetch_env!(:nitory, Nitory.Plugins.Help)

    res =
      Nitory.Robot.all_visible_commands(robot)
      |> Enum.map(fn {_, cmd} -> ".#{cmd.display_name}: #{cmd.short_usage}" end)
      |> (&([
              "Project-Nitory-Reborn v#{app_info[:version]} by NagiNikaido",
              "启动于 #{app_info[:startup_time]}"
              | &1
            ] ++ ["更多功能开发中"])).()
      |> Enum.map_join("\n", & &1)
      |> String.trim_trailing()

    {:reply, {:ok, res}, state}
  end

  @impl true
  def handle_call({:help_help, name}, _from, %{robot: robot} = state) do
    res =
      Nitory.Robot.all_visible_commands(robot)
      |> Enum.filter(fn {_, cmd} -> cmd.display_name == name end)
      |> Enum.map(fn {_, cmd} -> cmd.usage end)
      |> Enum.map_join("\n", & &1)
      |> String.trim_trailing()

    if res == "" do
      {:reply, {:error, "* 未找到这条指令。是否输入错误？"}, state}
    else
      {:reply, {:ok, res}, state}
    end
  end

  @doc """
  Lists all visible commands with a banner header.
  """
  def print_help_all(helper), do: GenServer.call(helper, {:help_all})

  @doc """
  Shows full usage string for a specific command.
  """
  def print_help_help(helper, name), do: GenServer.call(helper, {:help_help, name})

  @doc """
  Delegates to `print_help_all/1` or `print_help_help/2` based on
  whether `:cmd` is present in `opts`.  `opts` must include `:server`.
  """
  def print_help(opts \\ []) do
    helper = Keyword.fetch!(opts, :server)
    name = Keyword.get(opts, :cmd)

    if name do
      print_help_help(helper, name)
    else
      print_help_all(helper)
    end
  end

  @impl true
  def init_plugin(state) do
    commands = [
      Nitory.Command.new!(
        display_name: "help",
        hidden: false,
        short_usage: "显示本帮助",
        cmd_face: "help",
        options: [%Option{name: :cmd, optional: true}],
        action: {__MODULE__, :print_help, []},
        usage: """
        帮助指令
        .help [指令] 可查看对应指令的详细说明
        """
      )
    ]

    %{state | commands: commands}
  end
end

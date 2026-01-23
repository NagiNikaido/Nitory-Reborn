defmodule Nitory.Plugins.Help do
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

    {:reply, {:ok, res}, state}
  end

  @impl true
  def handle_call({:help_help, name}, _from, %{robot: robot} = state) do
    res =
      Nitory.Robot.all_visible_commands(robot)
      |> Enum.filter(fn {_, cmd} -> cmd.display_name == name end)
      |> Enum.map(fn {_, cmd} -> cmd.usage end)
      |> Enum.map_join("\n", & &1)

    if res == "" do
      {:reply, {:error, "* 未找到这条指令。是否输入错误？"}, state}
    else
      {:reply, {:ok, res}, state}
    end
  end

  def print_help_all(helper), do: GenServer.call(helper, {:help_all})

  def print_help_help(helper, name), do: GenServer.call(helper, {:help_help, name})

  def print_help(opts \\ []) do
    helper = Keyword.fetch!(opts, :server)
    name = Keyword.get(opts, :cmd_name)

    if name do
      print_help_help(helper, name)
    else
      print_help_all(helper)
    end
  end

  defcommand(
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
end

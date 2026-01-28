defmodule Nitory.Plugins.Nick do
  require Logger
  use Nitory.Plugin

  @impl true
  def handle_call({:rm_nick, user_id, group_id, default_nickname}, _from, state) do
    res =
      case Nitory.Nickname.rm_nick(user_id, group_id) do
        {:ok, _} ->
          {:ok, "* 恢复 #{default_nickname} 的默认昵称"}

        {:error, err} ->
          Logger.error(
            "Trying to remove the nickname of #{default_nickname}(#{user_id}) in #{group_id}, but error raised."
          )

          Logger.error(inspect(err))
          {:error, "* 发生错误，请查看log"}
      end

    {:reply, res, state}
  end

  @impl true
  def handle_call({:set_nick, user_id, group_id, default_nickname, nickname}, _from, state) do
    res =
      case Nitory.Nickname.set_nick(user_id, group_id, nickname) do
        {:ok, _} ->
          {:ok, "* #{default_nickname} 现在的昵称为 #{nickname}"}

        {:error, err} ->
          Logger.error(
            "Trying to set the nickname of #{default_nickname}(#{user_id}) in #{group_id} to #{nickname}, but error raised."
          )

          Logger.error(inspect(err))
          {:error, "* 发生错误，请查看log"}
      end

    {:reply, res, state}
  end

  def cmd_set_nick(opts) do
    msg = Keyword.fetch!(opts, :msg)
    nickname = Keyword.get(opts, :nickname)
    server = Keyword.fetch!(opts, :server)
    default_nickname = msg.sender.nickname

    if nickname == nil do
      GenServer.call(server, {:rm_nick, msg.user_id, msg.group_id, default_nickname})
    else
      GenServer.call(server, {:set_nick, msg.user_id, msg.group_id, default_nickname, nickname})
    end
  end

  def init_plugin(state) do
    Nitory.Robot.register_command(state.robot,
      display_name: "nn",
      cmd_face: "nn",
      hidden: false,
      msg_type: :group,
      short_usage: "设置昵称",
      options: [%Nitory.Command.Option{name: :nickname, optional: true}],
      action: {__MODULE__, :cmd_set_nick, []},
      usage: """
      设置昵称
      .nn [新昵称]  将本群组中的昵称设置为新昵称
      默认昵称为QQ昵称
      如将新昵称留空，则将当前昵称恢复为默认昵称
      """
    )

    state
  end
end

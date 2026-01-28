defmodule Nitory.Robot do
  use GenServer
  alias Phoenix.PubSub

  require Logger

  def start_link(args) do
    {name, init_arg} = Keyword.pop(args, :name, nil)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  @impl true
  def init(init_arg) do
    session = Keyword.fetch!(init_arg, :session)
    session_type = Keyword.fetch!(init_arg, :session_type)
    session_id = Keyword.fetch!(init_arg, :session_id)
    session_prefix = Keyword.fetch!(init_arg, :session_prefix)
    middleware = {:via, Registry, {Nitory.SessionSlot, "#{session_prefix}:middleware"}}
    robot = self()

    Logger.debug("[#{__MODULE__}] #{inspect(init_arg)}")

    plugins =
      Application.fetch_env!(:nitory, Nitory.Robot)
      |> Keyword.get(:plugins, [])
      |> (&[Nitory.Plugins.Dummy | &1]).()
      |> Enum.map(fn p_n_c ->
        {plugin_module, config} =
          case p_n_c do
            {p, c} -> {p, c}
            p -> {p, []}
          end

        name = apply(plugin_module, :plugin_name, [])
        location = {:via, Registry, {Nitory.SessionSlot, "#{session_prefix}:robot:#{name}"}}
        {plugin_module, config, location}
      end)

    children =
      Enum.map(plugins, fn {plugin_module, config, location} ->
        {plugin_module,
         [
           {:name, location},
           {:session, session},
           {:session_type, session_type},
           {:session_id, session_id},
           {:session_prefix, session_prefix},
           {:middleware, middleware},
           {:robot, robot} | config
         ]}
      end)

    {:ok, robot_sv} =
      Supervisor.start_link(
        [
          {Nitory.Middleware, name: middleware}
          | children
        ],
        strategy: :one_for_one
      )

    GenServer.cast(self(), {:deferred_init})

    {:ok,
     %{
       session: session,
       session_id: session_id,
       session_type: session_type,
       session_prefix: session_prefix,
       robot_sv: robot_sv,
       plugins: plugins,
       commands: [],
       middleware: middleware
     }}
  end

  def split_at(msg) do
    if msg == [] do
      [nil | msg]
    else
      [maybe_at | rest] = msg

      if maybe_at.type == :at do
        [maybe_at.data.qq | rest]
      else
        [nil | msg]
      end
    end
  end

  def split_reply(msg) do
    if msg == [] do
      [nil | split_at(msg)]
    else
      [maybe_reply | rest] = msg

      if maybe_reply.type == :reply do
        [maybe_reply.data.id | split_at(rest)]
      else
        [nil | split_at(msg)]
      end
    end
  end

  @impl true
  def handle_call({:list_commands, show_hidden}, _from, %{commands: cmds} = state) do
    if show_hidden do
      cmds
    else
      Enum.filter(cmds, fn {_, cmd} -> not cmd.hidden end)
    end

    {:reply, cmds, state}
  end

  @impl true
  def handle_cast({:register_command, opts}, %{commands: cmds} = state) do
    {server, opts} = Keyword.pop!(opts, :server)

    case Nitory.Command.new(opts) do
      {:ok, nc} ->
        Logger.info(
          "[#{__MODULE__}] Successfully registered command #{inspect(nc, pretty: true)}"
        )

        {:noreply, %{state | commands: [{server, nc} | cmds]}}

      {:error, err} ->
        Logger.error(
          "[#{__MODULE__}] Failed to register command #{inspect(opts, pretty: true)} with error reason: #{inspect(err)}"
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:message_in, msg}, %{middleware: middleware} = state) do
    Task.Supervisor.async_nolink(Nitory.TaskSupervisor, fn ->
      Nitory.Middleware.excute(middleware, msg)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:deferred_init}, state) do
    server = self()
    %{middleware: middleware, plugins: plugins} = state

    Nitory.Middleware.register(middleware, fn msg, next ->
      [reply, at | message] = split_reply(msg.message)

      if length(message) == 1 and List.first(message).type == :text and
           String.starts_with?(List.first(message).data.text, ".") do
        raw_args = List.first(message).data.text |> String.slice(1..-1//1) |> String.split()

        res =
          all_commands(server)
          |> Enum.map(fn {loc, cmd} ->
            res = Nitory.Command.parse(cmd, raw_args, msg: msg, reply: reply, at: at)

            case res do
              {:ok, {cmd, parsed_opts}} -> {:ok, {cmd, [{:server, loc} | parsed_opts]}}
              _ -> res
            end
          end)
          |> Enum.find(
            {:error, :no_such_command},
            &(elem(&1, 0) == :ok or
                (elem(&1, 0) == :error and elem(&1, 1) != :command_face_not_match))
          )

        res
      else
        Nitory.Middleware.run(msg, next)
      end
    end)

    Enum.each(plugins, fn {_, _, loc} ->
      GenServer.cast(loc, {:deferred_init})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_to_session, :reply, msg}, state) do
    %{session_type: session_type, session_id: session_id} = state
    do_send_msg(session_type, session_id, msg)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_to_session, {session_type, session_id}, msg}, state) do
    do_send_msg(session_type, session_id, msg)
    {:noreply, state}
  end

  defp do_send_msg(:group, group_id, msg),
    do: GenServer.cast(Nitory.ApiHandler, {:send_group_msg, %{group_id: group_id, message: msg}})

  defp do_send_msg(:private, user_id, msg),
    do: GenServer.cast(Nitory.ApiHandler, {:send_private_msg, %{user_id: user_id, message: msg}})

  @impl true
  def handle_info({ref, answer}, state) do
    Process.demonitor(ref, [:flush])

    case answer do
      {:ok, {cmd, parsed_opts}} ->
        Task.Supervisor.async_nolink(Nitory.TaskSupervisor, fn ->
          case cmd.action do
            {m, f, a} -> apply(m, f, [a ++ parsed_opts])
            f -> apply(f, [parsed_opts])
          end
        end)

      _ ->
        handle_answer(answer, state)
    end

    {:noreply, state}
  end

  defp handle_answer(answer, state) do
    PubSub.broadcast(
      Nitory.PubSub,
      "socket",
      {:receive_from_session, "#{state.session_type}:#{state.session_id}"}
    )

    case answer do
      {:ok, msg} when is_binary(msg) or is_list(msg) ->
        reply_to_session(self(), msg)

      {:error, {:unparsed_arguments, _cmd, _args}} ->
        reply_to_session(self(), "* 格式错误，参数过多")

      {:error, {:wrong_argument, _cmd, _opt_name}} ->
        reply_to_session(self(), "* 格式错误")

      {:error, {:wrong_msg_type, _cmd, :private}} ->
        reply_to_session(self(), "* 本指令仅可在私聊中使用")

      {:error, {:wrong_msg_type, _cmd, :group}} ->
        reply_to_session(self(), "* 本指令仅可在群聊中使用")

      {:error, :no_such_command} ->
        reply_to_session(self(), "* 无效指令")

      {:error, error_msg} when is_binary(error_msg) ->
        reply_to_session(self(), "#{error_msg}")

      {:error, error_package} ->
        Logger.warning("[#{__MODULE__}] #{inspect(error_package)}")

      :error ->
        reply_to_session(self(), "* 未知错误")

      :ok ->
        nil
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Shouldn't be here, but let's just log it.
    Logger.warning("[#{__MODULE__}] #{inspect(pid)} down due to #{inspect(reason)}.")
    {:noreply, state}
  end

  def all_commands(pid), do: GenServer.call(pid, {:list_commands, true})

  def all_visible_commands(pid), do: GenServer.call(pid, {:list_commands, false})

  def register_command(pid, opts), do: GenServer.cast(pid, {:register_command, opts})

  def reply_to_session(pid, msg), do: GenServer.cast(pid, {:send_to_session, :reply, msg})

  def send_to_session(pid, msg, {_session_type, _session_id} = session_ref),
    do: GenServer.cast(pid, {:send_to_session, session_ref, msg})
end

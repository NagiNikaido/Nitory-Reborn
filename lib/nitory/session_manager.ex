defmodule Nitory.SessionManager do
  use GenServer
  alias Phoenix.PubSub

  require Logger

  @eta 2_500

  defstruct last_timestamp: nil

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    PubSub.subscribe(Nitory.PubSub, "session_manager")

    children = [
      Nitory.ApiHandler,
      Nitory.Middleware,
      {Registry, name: Nitory.SessionSlot, keys: :unique},
      {DynamicSupervisor, name: Nitory.SessionSupervisor, strategy: :one_for_one}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
    {:ok, %__MODULE__{}}
  end

  defp send_to_socket(msg) do
    PubSub.broadcast(Nitory.PubSub, "socket", msg)
  end

  defp send_to_api_handler(msg) do
    PubSub.broadcast(Nitory.PubSub, "api_handler", msg)
  end

  defp extract_session_id(msg) do
    case msg.message_type do
      :group -> "group:#{msg.group_id}"
      :private -> "private:#{msg.user_id}"
    end
  end

  defp send_to_session(msg, session_id) do
    session_pid =
      case Registry.lookup(Nitory.SessionSlot, session_id) do
        [{_, pid}] ->
          pid

        [] ->
          {:ok, pid} =
            DynamicSupervisor.start_child(
              Nitory.SessionSupervisor,
              {Nitory.Session, [name: session_id]}
            )

          Registry.register(Nitory.SessionSlot, session_id, pid)
          pid
      end

    Logger.info("[#{__MODULE__}] #{session_id}: #{inspect(session_pid)}")
    send(session_pid, msg)
  end

  @impl true
  def handle_info({:event, event}, state) do
    # send(state.socket, {:receive, event})
    msg =
      with {:ok, ev} <- Jason.decode(event),
           {:ok, ev_obj} <- Nitory.Events.cast(ev) do
        send(self(), {:parsed_event, ev_obj})
        {:receive, Jason.encode!(ev_obj)}
      else
        {:error, %Jason.DecodeError{} = err} ->
          {:error, "JSON decoding error: #{Jason.DecodeError.message(err)}"}

        {:error, err} ->
          {:error, "Events casting error: #{inspect(err)}"}
      end

    send_to_socket(msg)

    {:noreply, state}
  end

  @impl true
  def handle_info({:api_request, request}, state) do
    send_to_socket({:api_request, Jason.encode!(request)})

    {:noreply, state}
  end

  @impl true
  def handle_info({:parsed_event, ev_obj}, state) do
    Logger.info("#{inspect(ev_obj, pretty: true)}")
    handle_event(ev_obj, state)

    {:noreply, state}
  end

  def handle_event(%{post_type: :message} = ev_obj, state) do
    session_id = extract_session_id(ev_obj)
    send_to_session({:message_in, ev_obj}, session_id)
    {:noreply, state}
  end

  def handle_event(%{post_type: :echo} = ev_obj, state) do
    send_to_api_handler({:response, ev_obj})

    {:noreply, state}
  end

  def handle_event(%{post_type: :meta_event, meta_event_type: :heartbeat} = ev_obj, state) do
    if ev_obj.status.good do
      Process.send_after(self(), {:check_heartbeat, ev_obj.interval}, ev_obj.interval + @eta)
      cur_timestamp = DateTime.to_unix(DateTime.utc_now(), :millisecond)
      {:noreply, %{state | last_timestamp: cur_timestamp}}
    end
  end

  @impl true
  def handle_info({:check_heartbeat, _interval}, state) do
    cur_timestamp = DateTime.to_unix(DateTime.utc_now(), :millisecond)

    if cur_timestamp - state.last_timestamp > state.interval do
      raise "Heartbeat stopped."
    end

    {:noreply, state}
  end
end

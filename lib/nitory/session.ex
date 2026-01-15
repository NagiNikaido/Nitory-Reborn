defmodule Nitory.Session do
  use GenServer
  alias Phoenix.PubSub

  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg)
  end

  @impl true
  def init(init_arg) do
    session_id = Keyword.fetch!(init_arg, :session_id)
    Logger.info("[#{__MODULE__}] #{inspect(Process.info(self()), pretty: true)}")

    middleware = {:via, Registry, {Nitory.SessionSlot, "#{session_id}:middleware"}}

    children = [
      {Nitory.Middleware, name: middleware}
    ]

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    PubSub.subscribe(Nitory.PubSub, "session:#{session_id}")
    {:ok, %{session_id: session_id, middlewares: middleware}}
  end

  @impl true
  def handle_info({:message_in, msg_obj}, state) do
    Logger.info("[#{__MODULE__}] Received #{inspect(msg_obj, pretty: true)}")

    PubSub.broadcast(Nitory.PubSub, "socket", {:receive_from_session, 123})
    {:noreply, state}
  end

  # Below are delegated methods of middleware registeration, excution and dipositation.
  @impl true
  def handle_call({:excute_middleware, ctx}, _from, state) do
    mw = state.middlewares
    res = Nitory.Middleware.excute(mw, ctx)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:excute_middleware!, ctx}, _from, state) do
    mw = state.middlewares
    res = Nitory.Middleware.excute!(mw, ctx)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:register_middleware, func, mode}, _from, state) do
    mw = state.middlewares
    res = Nitory.Middleware.register(mw, func, mode)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:register_middleware, module, func, args, mode}, _from, state) do
    mw = state.middlewares
    res = Nitory.Middleware.register(mw, module, func, args, mode)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:list_middleware}, _from, state) do
    mw = state.middlewares
    res = Nitory.Middleware.list(mw)
    {:reply, res, state}
  end

  @impl true
  def handle_cast({:dispose_middleware, uuid}, state) do
    mw = state.middlewares
    Nitory.Middleware.dispose(mw, uuid)
    {:noreply, state}
  end
end

defmodule Nitory.Middleware do
  use GenServer

  # a sample middleware
  # fn opts, next ->
  #    prelude(...)
  #    with {:ok, res} <- run(next, opts) do
  #      postlude(...)
  #    end
  # end

  @type server() :: GenServer.server()

  def start_link(arg) do
    {name, init_arg} = Keyword.pop(arg, :name, nil)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  @impl true
  def init(_init_arg) do
    {:ok, []}
  end

  @impl true
  def handle_call({:excute_middleware, ctx}, _from, middlewares = state) do
    res = run(ctx, middlewares)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:excute_middleware!, ctx}, _from, middlewares = state) do
    res = run(ctx, middlewares)

    case res do
      :ok -> {:reply, :ok, state}
      {:ok, payload} -> {:reply, payload, state}
      {:error, error} -> raise error
    end
  end

  @impl true
  def handle_call({:register_middleware, func, mode}, _from, middlewares = _state) do
    uuid = Ecto.UUID.generate()

    middlewares =
      case mode do
        :append -> middlewares ++ [{uuid, :fn, func}]
        :prepend -> [{uuid, :fn, func}] ++ middlewares
      end

    mw = self()
    {:reply, fn -> dispose(mw, uuid) end, middlewares}
  end

  @impl true
  def handle_call({:register_middleware, module, func, args, mode}, _from, middlewares = _state) do
    uuid = Ecto.UUID.generate()

    middlewares =
      case mode do
        :append -> middlewares ++ [{uuid, module, func, args}]
        :prepend -> [{uuid, module, func, args}] ++ middlewares
      end

    mw = self()
    {:reply, fn -> dispose(mw, uuid) end, middlewares}
  end

  @impl true
  def handle_call({:list_middleware}, _from, middlewares = state) do
    {:reply, middlewares, state}
  end

  @impl true
  def handle_cast({:dispose_middleware, uuid}, middlewares = _state) do
    middlewares = Enum.filter(middlewares, fn mw -> elem(mw, 0) != uuid end)
    {:noreply, middlewares}
  end

  @spec run(term(), list()) :: :ok | {:ok, term()} | {:error, term()}
  def run(_ctx, []), do: :ok
  def run(ctx, [{_, :fn, f} | next]), do: apply(f, [ctx, next])
  def run(ctx, [{_, m, f, a} | next]), do: apply(m, f, [ctx, next | a])

  @spec excute(server(), term()) :: :ok | {:ok, term()} | {:error, term()}
  def excute(server, ctx), do: GenServer.call(server, {:excute_middleware, ctx})

  @spec excute!(server(), term()) :: term()
  def excute!(server, ctx), do: GenServer.call(server, {:excute_middleware!, ctx})

  @spec register(
          server(),
          (term(), list() -> {:ok, term()} | {:error, term()}),
          :append | :prepend
        ) ::
          (-> :ok)
  def register(server, func, mode \\ :append),
    do: GenServer.call(server, {:register_middleware, func, mode})

  @spec register(server(), module(), atom(), list(), :append | :prepend) :: (-> :ok)
  def register(server, module, func, args, mode \\ :append),
    do: GenServer.call(server, {:register_middleware, module, func, args, mode})

  @spec dispose(server(), binary()) :: :ok
  def(dispose(server, uuid), do: GenServer.cast(server, {:dispose_middleware, uuid}))

  @spec list(server()) :: list()
  def list(server), do: GenServer.call(server, {:list_middleware})
end

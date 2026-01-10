defmodule Nitory.Middleware do
  use GenServer

  # a sample middleware
  # fn opts, next ->
  #    prelude(...)
  #    with {:ok, res} <- run(next, opts) do
  #      postlude(...)
  #    end
  # end

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, {}}
  end

  @impl true
  def handle_call({:excute, session}, _from, state) do
    middlewares = Process.get(:middlewares, [])
    res = run(session, middlewares)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:excute!, session}, _from, state) do
    middlewares = Process.get(:middlewares, [])
    res = run(session, middlewares)

    case res do
      {:ok, payload} -> {:reply, payload, state}
      {:error, error} -> raise error
    end
  end

  @impl true
  def handle_call({:register, func, mode}, _from, state) do
    middlewares = Process.get(:middlewares, [])

    uuid = Ecto.UUID.generate()

    middlewares =
      case mode do
        :append -> middlewares ++ [{uuid, :fn, func}]
        :prepend -> [{uuid, :fn, func}] ++ middlewares
      end

    Process.put(:middlewares, middlewares)

    {:reply, fn -> dispose(uuid) end, state}
  end

  @impl true
  def handle_call({:register, module, func, args, mode}, _from, state) do
    middlewares = Process.get(:middlewares, [])

    uuid = Ecto.UUID.generate()

    middlewares =
      case mode do
        :append -> middlewares ++ [{uuid, module, func, args}]
        :prepend -> [{uuid, module, func, args}] ++ middlewares
      end

    Process.put(:middlewares, middlewares)

    {:reply, fn -> dispose(uuid) end, state}
  end

  @impl true
  def handle_call({:dispose, uuid}, _from, state) do
    middlewares = Process.get(:middlewares, [])

    middlewares = Enum.filter(middlewares, fn mw -> elem(mw, 0) != uuid end)
    Process.put(:middlewares, middlewares)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:list_mw}, _from, state) do
    middlewares = Process.get(:middlewares, [])

    {:reply, middlewares, state}
  end

  @spec run(term(), list()) :: {:ok, term()} | {:error, term()}
  def run(_session, []), do: {:ok, nil}
  def run(session, [{_, :fn, f} | next]), do: apply(f, [session, next])
  def run(session, [{_, m, f, a} | next]), do: apply(m, f, [session, next | a])

  @spec excute(term()) :: :ok | {:ok, term()} | {:error, term()}
  def excute(session), do: GenServer.call(__MODULE__, {:excute, session})

  @spec excute!(term()) :: term()
  def excute!(session), do: GenServer.call(__MODULE__, {:excute!, session})

  @spec register((term(), list() -> {:ok, term()} | {:error, term()}), :append | :prepend) ::
          (-> :ok)
  def register(func, mode \\ :append), do: GenServer.call(__MODULE__, {:register, func, mode})

  @spec register(module(), atom(), list(), :append | :prepend) :: (-> :ok)
  def register(module, func, args, mode \\ :append),
    do: GenServer.call(__MODULE__, {:register, module, func, args, mode})

  @spec dispose(binary()) :: :ok
  def dispose(uuid), do: GenServer.call(__MODULE__, {:dispose, uuid})

  @spec list_mw() :: list()
  def list_mw(), do: GenServer.call(__MODULE__, {:list_mw})
end

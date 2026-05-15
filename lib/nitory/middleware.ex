defmodule Nitory.Middleware do
  @moduledoc """
  Composable middleware chain for message processing.

  Middleware functions are called in registration order. Each middleware
  receives a context and the tail of the chain; it may short-circuit by
  not calling the next function. Supports anonymous functions, MFA tuples,
  and GenServer-backed middleware (e.g. for stateful processing).

  ## Registration

      Nitory.Middleware.register(mw, fn ctx, next -> Nitory.Middleware.run(ctx, next) end)
      Nitory.Middleware.register(mw, SomeModule, :handler, [arg1, arg2], :prepend)

  Registration returns a dispose function to remove the middleware.
  """

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

  @doc """
  Runs the middleware chain.

  Passes `ctx` through each middleware in registration order.  Each
  middleware receives the context and the remaining chain (`next`).
  If a middleware returns without calling `run(ctx, next)`, the chain
  stops there.

  Returns `:ok`, `{:ok, payload}`, or `{:error, reason}`.
  """
  @spec run(term(), list()) :: :ok | {:ok, term()} | {:error, term()}
  def run(_ctx, []), do: :ok
  def run(ctx, [{_, :fn, f} | next]), do: apply(f, [ctx, next])
  def run(ctx, [{_, m, f, a} | next]), do: apply(m, f, [ctx, next | a])

  @doc """
  Executes the middleware chain via the GenServer and returns the
  result.  See `run/2`.
  """
  @spec excute(server(), term()) :: :ok | {:ok, term()} | {:error, term()}
  def excute(server, ctx), do: GenServer.call(server, {:excute_middleware, ctx})

  @doc """
  Like `excute/2`, but raises on `{:error, reason}`.
  """
  @spec excute!(server(), term()) :: term()
  def excute!(server, ctx), do: GenServer.call(server, {:excute_middleware!, ctx})

  @doc """
  Registers an anonymous function as middleware.

  Returns a zero-arity dispose function.  `mode` is `:append` (default)
  or `:prepend`.
  """
  @spec register(
          server(),
          (term(), list() -> {:ok, term()} | {:error, term()}),
          :append | :prepend
        ) ::
          (-> :ok)
  def register(server, func, mode \\ :append),
    do: GenServer.call(server, {:register_middleware, func, mode})

  @doc """
  Registers an MFA-tuple middleware (`{module, function, extra_args}`).

  The handler function receives `(ctx, next, extra_arg1, extra_arg2, ...)`.
  Returns a dispose function.  `mode` is `:append` (default) or `:prepend`.
  """
  @spec register(server(), module(), atom(), list(), :append | :prepend) :: (-> :ok)
  def register(server, module, func, args, mode \\ :append),
    do: GenServer.call(server, {:register_middleware, module, func, args, mode})

  @doc """
  Removes a middleware by its dispose UUID.

  Prefer calling the dispose function returned by `register/3` or
  `register/5`.
  """
  @spec dispose(server(), binary()) :: :ok
  def(dispose(server, uuid), do: GenServer.cast(server, {:dispose_middleware, uuid}))

  @doc """
  Lists all registered middleware entries.

  Each entry is `{uuid, type, payload}` where `type` is `:fn` for
  anonymous functions or a module atom for MFA tuples.
  """
  @spec list(server()) :: list()
  def list(server), do: GenServer.call(server, {:list_middleware})
end

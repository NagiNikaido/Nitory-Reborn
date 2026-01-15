defmodule Nitory.MiddlewareTest.TestModule do
  import Logger

  def call(ctx, next, a, b, c) do
    Logger.info("I'm another middleware, currently in #{__MODULE__}.")

    Logger.info(
      "I have three other arguments, a: #{inspect(a)}, b: #{inspect(b)}, c: #{inspect(c)}"
    )

    Nitory.Middleware.run(ctx, next)
  end
end

defmodule Nitory.MiddlewareTest.TestGenServer do
  use GenServer

  import Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, {}}
  end

  @impl true
  def handle_call({:feed, ctx, next, a, b}, _from, state) do
    Logger.info("I'm a middlware-genserver, currently in #{__MODULE__}")
    Logger.info("I have two arguments, a: #{inspect(a)}, b: #{inspect(b)}")

    Nitory.Middleware.run(ctx, next)
    {:reply, :ok, state}
  end

  def feed(ctx, next, a, b), do: GenServer.call(__MODULE__, {:feed, ctx, next, a, b})
end

defmodule Nitory.MiddlewareTest do
  use ExUnit.Case, async: false

  import Logger

  setup do
    mw = start_supervised!(Nitory.Middleware)
    start_supervised!(Nitory.MiddlewareTest.TestGenServer)
    {:ok, mw: mw}
  end

  test "middlewares", context do
    mw = context[:mw]

    # 1
    dispose_1 =
      Nitory.Middleware.register(mw, fn ctx, next ->
        Logger.info("I'm middleware 1. Everything ends here.")
        :ok
      end)

    # 2 1
    dispose_2 =
      Nitory.Middleware.register(
        mw,
        fn ctx, next ->
          Logger.info("I'm middleware 2. Let's see what's in the ctx.")
          Logger.info(inspect(ctx, pretty: true))
          Nitory.Middleware.run(ctx, next)
        end,
        :prepend
      )

    # 3 2 1
    dispose_3 =
      Nitory.Middleware.register(
        mw,
        Nitory.MiddlewareTest.TestModule,
        :call,
        [1, "a", %{"t" => "d"}],
        :prepend
      )

    # 3 2 1 4
    dispose_4 =
      Nitory.Middleware.register(mw, fn ctx, next ->
        Logger.info("I'm middleware 4. I'm covered by middleware 1.")
        Logger.info("If I'm seen, middleware 1 has been disposed.")
        Nitory.Middleware.run(ctx, next)
      end)

    # 5 3 2 1 4
    dispose_5 =
      Nitory.Middleware.register(
        mw,
        Nitory.MiddlewareTest.TestGenServer,
        :feed,
        [2, "b"],
        :prepend
      )

    # 5 3 2 1 4 6
    dispose_6 =
      Nitory.Middleware.register(
        mw,
        fn ctx, next ->
          dispose_5.()
          Nitory.Middleware.run(ctx, next)
        end
      )

    Logger.info(Nitory.Middleware.list(mw))

    Nitory.Middleware.excute(mw, {})

    # 5 3 2 4 6
    dispose_1.()

    # After this, should be 3 2 4 6.
    Nitory.Middleware.excute(mw, {})

    dispose_3.()

    Nitory.Middleware.excute(mw, {})
  end
end

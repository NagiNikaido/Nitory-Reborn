defmodule Nitory.MiddlewareTest do
  use ExUnit.Case, async: false

  setup do
    mw = start_supervised!(Nitory.Middleware)
    {:ok, agent} = Agent.start_link(fn -> [] end)
    {:ok, mw: mw, agent: agent}
  end

  defp trace(agent, tag) do
    Agent.update(agent, fn list -> [tag | list] end)
  end

  defp get_trace(agent) do
    Agent.get(agent, &Enum.reverse/1)
  end

  test "middlewares execute in registration order", %{mw: mw, agent: agent} do
    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, :a)
      Nitory.Middleware.run(ctx, next)
    end)

    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, :b)
      Nitory.Middleware.run(ctx, next)
    end)

    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, :c)
      Nitory.Middleware.run(ctx, next)
    end)

    Nitory.Middleware.excute(mw, {})

    assert [:a, :b, :c] = get_trace(agent)
  end

  test "prepend inserts before existing middleware", %{mw: mw, agent: agent} do
    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, :b)
      Nitory.Middleware.run(ctx, next)
    end)

    Nitory.Middleware.register(
      mw,
      fn ctx, next ->
        trace(agent, :a)
        Nitory.Middleware.run(ctx, next)
      end,
      :prepend
    )

    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, :c)
      Nitory.Middleware.run(ctx, next)
    end)

    Nitory.Middleware.excute(mw, {})

    assert [:a, :b, :c] = get_trace(agent)
  end

  test "dispose removes middleware from chain", %{mw: mw, agent: agent} do
    dispose_b =
      Nitory.Middleware.register(mw, fn ctx, next ->
        trace(agent, :b)
        Nitory.Middleware.run(ctx, next)
      end)

    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, :a)
      Nitory.Middleware.run(ctx, next)
    end, :prepend)

    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, :c)
      Nitory.Middleware.run(ctx, next)
    end)

    Nitory.Middleware.excute(mw, {})
    agent |> get_trace() |> Enum.each(fn _ -> nil end)

    dispose_b.()
    Agent.update(agent, fn _ -> [] end)

    Nitory.Middleware.excute(mw, {})
    assert [:a, :c] = get_trace(agent)
  end

  test "short-circuit stops chain execution", %{mw: mw, agent: agent} do
    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, :a)
      Nitory.Middleware.run(ctx, next)
    end, :prepend)

    Nitory.Middleware.register(mw, fn _ctx, _next ->
      trace(agent, :stop)
      :ok
    end, :prepend)

    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, :b)
      Nitory.Middleware.run(ctx, next)
    end)

    Nitory.Middleware.excute(mw, {})

    assert [:stop] = get_trace(agent)
  end

  test "self-disposing middleware removes itself during execution", %{mw: mw, agent: agent} do
    dispose_a =
      Nitory.Middleware.register(mw, fn ctx, next ->
        trace(agent, :a)
        Nitory.Middleware.run(ctx, next)
      end, :prepend)

    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, :b)
      Nitory.Middleware.run(ctx, next)
    end)

    Nitory.Middleware.register(mw, fn ctx, next ->
      dispose_a.()
      trace(agent, :disposer)
      Nitory.Middleware.run(ctx, next)
    end, :prepend)

    Nitory.Middleware.excute(mw, {})
    agent |> get_trace() |> Enum.each(fn _ -> nil end)

    Agent.update(agent, fn _ -> [] end)
    Nitory.Middleware.excute(mw, {})
    assert [:disposer, :b] = get_trace(agent)
  end

  test "excute! raises on {:error, reason}", %{mw: mw, agent: agent} do
    Nitory.Middleware.register(mw, fn _ctx, _next ->
      {:error, "boom"}
    end)

    assert catch_exit(
             Nitory.Middleware.excute!(mw, {})
           )
  end

  test "list returns all registered middleware", %{mw: mw} do
    assert [] = Nitory.Middleware.list(mw)

    Nitory.Middleware.register(mw, fn _ctx, _next -> :ok end)
    Nitory.Middleware.register(mw, fn _ctx, _next -> :ok end)

    assert [_a, _b] = Nitory.Middleware.list(mw)
  end

  test "middleware receives context", %{mw: mw, agent: agent} do
    ctx = %{key: "value"}

    Nitory.Middleware.register(mw, fn ctx, next ->
      trace(agent, ctx.key)
      Nitory.Middleware.run(ctx, next)
    end)

    Nitory.Middleware.excute(mw, ctx)

    assert ["value"] = get_trace(agent)
  end
end

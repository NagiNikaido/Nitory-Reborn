defmodule Nitory.Socket do
  @behaviour Phoenix.Socket.Transport

  require Logger

  alias Phoenix.PubSub

  def child_spec(_), do: :ignore

  def connect(state) do
    {:ok, state}
  end

  def init(state) do
    PubSub.subscribe(Nitory.PubSub, "socket")
    send(self(), :heartbeat)
    Logger.log(:info, "[Nitory.Socket] #{inspect(self())}, #{inspect(state)}")

    children = [
      Nitory.SessionManager
    ]

    Supervisor.start_link(children, strategy: :one_for_one)

    {:ok, state}
  end

  def handle_in({text, _opts}, state) do
    PubSub.broadcast(Nitory.PubSub, "session_manager", {:event, text})

    {:ok, state}
  end

  # def handle_info(:heartbeat, state) do
  #   Process.send_after(self(), :heartbeat, 1_000)

  #   timestamp =
  #     Jason.encode!(%{
  #       heartbeat: DateTime.utc_now() |> DateTime.to_unix()
  #     })

  #   {:push, {:text, timestamp}, state}
  # end

  def handle_info({:receive, reply}, state) do
    {:push, {:text, reply}, state}
  end

  def handle_info({:api_request, request}, state) do
    {:push, {:text, request}, state}
  end

  def handle_info({:error, err}, state) do
    Logger.log(:debug, err)
    {:push, {:text, err}, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end

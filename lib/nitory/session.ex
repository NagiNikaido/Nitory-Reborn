defmodule Nitory.Session do
  use GenServer
  alias Phoenix.PubSub

  require Logger

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: nil)
  end

  @impl true
  def init(init_arg) do
    name = Keyword.fetch!(init_arg, :name)
    Logger.info("[#{__MODULE__}] #{inspect(Process.info(self()), pretty: true)}")
    PubSub.subscribe(Nitory.PubSub, "session:#{name}")
    {:ok, %{name: name}}
  end

  @impl true
  def handle_info({:message_in, msg_obj}, state) do
    Logger.info("[#{__MODULE__}] Received #{inspect(msg_obj, pretty: true)}")

    PubSub.broadcast(Nitory.PubSub, "socket", {:receive_from_session, 123})
    {:noreply, state}
  end
end

defmodule Nitory.ApiHandler do
  use Nitory.Helper.Api

  require Logger

  alias Phoenix.PubSub

  @max_packets_cnt 0x10000000

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    PubSub.subscribe(Nitory.PubSub, "api_handler")

    children = [
      {Registry, name: Nitory.ApiSlot, keys: :unique}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
    {:ok, 0}
  end

  defp send_to_session_manager(msg) do
    PubSub.broadcast(Nitory.PubSub, "session_manager", msg)
  end

  @impl true
  def handle_call({handler, params}, from, state) do
    handle_request(handler, params, from, state, :call)
  end

  @impl true
  def handle_cast({handler, params}, state) do
    handle_request(handler, params, nil, state, :cast)
  end

  defp handle_request(handler, params, from, state, call_type) do
    Logger.info(
      "#{handler}, #{inspect(params, pretty: true)}, #{inspect(from)}, #{inspect(state)}, #{call_type}"
    )

    {:ok, param} = prepare_request(handler, params)
    cur_packet_num = rem(state + 1, @max_packets_cnt)
    echo_serial = "#{cur_packet_num}"
    {:ok, _} = Registry.register(Nitory.ApiSlot, echo_serial, {handler, from, call_type})

    send_to_session_manager({:api_request, %{action: handler, params: param, echo: echo_serial}})

    {:noreply, cur_packet_num}
  end

  @impl true
  def handle_info({:response, %Nitory.Events.Echo{} = msg}, state) do
    [{_, {handler, from, call_type}}] = Registry.lookup(Nitory.ApiSlot, msg.echo)
    Registry.unregister(Nitory.ApiSlot, msg.echo)

    case msg.status do
      :ok ->
        {:ok, data} = prepare_response(handler, msg.data)

        Logger.info(
          "[#{__MODULE__}] Received response to request \##{msg.echo}:\n#{inspect(msg, pretty: true)}"
        )

        if call_type == :call, do: GenServer.reply(from, {:ok, data})

      :fail ->
        Logger.warning(
          "[#{__MODULE__}] Received response to request \##{msg.echo}:\n#{inspect(msg, pretty: true)}"
        )

        if call_type == :call, do: GenServer.reply(from, {:error, msg.retcode})
    end

    {:noreply, state}
  end

  api :send_group_msg do
    input_spec do
      field! :group_id, Union, oneof: [:integer, :string]
      field! :message, Nitory.Message
    end

    output_spec do
      field! :message_id, :integer
    end
  end

  api :send_private_msg do
    input_spec do
      field! :user_id, Union, oneof: [:integer, :string]
      field! :message, Nitory.Message
    end

    output_spec do
      field! :message_id, :integer
    end
  end

  api :send_msg do
    input_spec do
      field! :message_type, Ecto.Enum, values: [:group, :private]
      field :group_id, Union, oneof: [:integer, :string], omitempty: true
      field :user_id, Union, oneof: [:integer, :string], omitempty: true
      field! :message, Nitory.Message
    end

    output_spec do
      field! :message_id, :integer
    end
  end

  api :get_image do
    input_spec do
      field :file_id, :string, omitempty: true
      field :file, :string, omitempty: true
    end

    output_spec do
      field! :file, :string
      field! :url, :string
      field! :file_size, :string
      field! :file_name, :string
      field! :base64, :string
    end
  end
end

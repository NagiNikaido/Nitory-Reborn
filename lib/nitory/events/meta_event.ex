defmodule Nitory.Events.MetaEvent.Types do
  @moduledoc "OneBot meta event type enum: `:heartbeat` or `:lifecycle`."

  use Flint.Type, extends: Ecto.Enum, values: [:heartbeat, :lifecycle]
end

defmodule Nitory.Events.MetaEvent.Heartbeat do
  @moduledoc """
  OneBot heartbeat event (`post_type: "meta_event", meta_event_type: "heartbeat"`).

  Sent periodically by the client to confirm the connection is alive.

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:meta_event` | yes | Event post type |
  | `meta_event_type` | `:heartbeat` | yes | Meta event discriminator |
  | `status.online` | `boolean()` | no | Whether the client is online |
  | `status.good` | `boolean()` | yes | Whether the client is in a healthy state |
  | `interval` | `integer()` | yes | Heartbeat interval hint (ms) |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.MetaEvent.Heartbeat.cast(%{
      ...>   "time" => 1_700_000_000, "self_id" => 12_345,
      ...>   "post_type" => "meta_event", "meta_event_type" => "heartbeat",
      ...>   "status" => %{"online" => true, "good" => true},
      ...>   "interval" => 5_000
      ...> })
      iex> ev.status.good
      true
      iex> ev.interval
      5_000

  ## Serialization

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Events.MetaEvent.Heartbeat{
      ...>   time: 1_700_000_000, self_id: 12_345,
      ...>   post_type: :meta_event, meta_event_type: :heartbeat,
      ...>   status: %Nitory.Events.MetaEvent.Heartbeat.Status{online: true, good: true},
      ...>   interval: 5_000
      ...> })
      %{time: 1_700_000_000, self_id: 12_345, post_type: :meta_event, meta_event_type: :heartbeat,
        status: %{online: true, good: true}, interval: 5_000}
  """

  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :meta_event_type, Nitory.Events.MetaEvent.Types

    embeds_one! :status, Status do
      field :online, :boolean
      field! :good, :boolean
    end

    field! :interval, :integer
  end
end

defmodule Nitory.Events.MetaEvent.Lifecycle do
  @moduledoc """
  OneBot lifecycle event (`post_type: "meta_event", meta_event_type: "lifecycle"`).

  Indicates the client's connection state.

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:meta_event` | yes | Event post type |
  | `meta_event_type` | `:lifecycle` | yes | Meta event discriminator |
  | `sub_type` | `:enable` / `:disable` / `:connect` | yes | Lifecycle phase |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.MetaEvent.Lifecycle.cast(%{
      ...>   "time" => 1_700_000_000, "self_id" => 12_345,
      ...>   "post_type" => "meta_event", "meta_event_type" => "lifecycle",
      ...>   "sub_type" => "connect"
      ...> })
      iex> ev.sub_type
      :connect

  ## Serialization

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Events.MetaEvent.Lifecycle{
      ...>   time: 1_700_000_000, self_id: 12_345,
      ...>   post_type: :meta_event, meta_event_type: :lifecycle,
      ...>   sub_type: :enable
      ...> })
      %{time: 1_700_000_000, self_id: 12_345, post_type: :meta_event, meta_event_type: :lifecycle,
        sub_type: :enable}
  """

  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :meta_event_type, Nitory.Events.MetaEvent.Types
    field! :sub_type, Ecto.Enum, values: [:enable, :disable, :connect]
  end
end

defmodule Nitory.Events.MetaEvent do
  @moduledoc """
  Union type for OneBot meta events.

  Dispatches `cast/1` to `Heartbeat` or `Lifecycle` based on the
  `meta_event_type` field.
  """

  use Ecto.Type

  alias Nitory.Events.MetaEvent.{Heartbeat, Lifecycle}

  @type t :: Heartbeat.t() | Lifecycle.t()

  @doc false
  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{"meta_event_type" => "heartbeat"} = m), do: Heartbeat.cast(m)
  def cast(%{meta_event_type: :heartbeat} = m), do: Heartbeat.cast(m)

  def cast(%{"meta_event_type" => "lifecycle"} = m), do: Lifecycle.cast(m)
  def cast(%{meta_event_type: :lifecycle} = m), do: Lifecycle.cast(m)

  def cast(t), do: {:error, "Unsupported meta event: #{inspect(t)}"}

  @doc false
  def dump(_), do: :error

  @doc false
  def load(_), do: :error
end

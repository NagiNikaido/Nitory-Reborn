defmodule Nitory.Events.MetaEvent.Types do
  @moduledoc "OneBot meta event type enum: `:heartbeat` or `:lifecycle`."

  use Flint.Type, extends: Ecto.Enum, values: [:heartbeat, :lifecycle]
end

defmodule Nitory.Events.MetaEvent.Heartbeat do
  @moduledoc """
  OneBot heartbeat event schema.

  Sent periodically by the client to confirm the connection is alive.
  Includes a status sub-object and an interval hint used for liveness monitoring.
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
  OneBot lifecycle event schema.

  Indicates the client's connection state: `:enable`, `:disable`, or `:connect`.
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

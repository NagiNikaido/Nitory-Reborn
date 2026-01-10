defmodule Nitory.Events.MetaEvent.Types do
  use Flint.Type, extends: Ecto.Enum, values: [:heartbeat, :lifecycle]
end

defmodule Nitory.Events.MetaEvent.Heartbeat do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Events.Types
    field! :meta_event_type, Nitory.Events.MetaEvent.Types

    embeds_one! :status, Status do
      field :online, :boolean
      field! :good, :boolean
    end

    field! :interval, :integer
  end
end

defmodule Nitory.Events.MetaEvent.Lifecycle do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Events.Types
    field! :meta_event_type, Nitory.Events.MetaEvent.Types
    field! :sub_type, Ecto.Enum, values: [:enable, :disable, :connect]
  end
end

defmodule Nitory.Events.MetaEvent do
  use Ecto.Type

  alias Nitory.Events.MetaEvent.{Heartbeat, Lifecycle}

  @type t :: Heartbeat.t() | Lifecycle.t()

  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{meta_event_type: "heartbeat"} = m), do: Heartbeat.cast(m)

  def cast(%{meta_event_type: "lifecycle"} = m), do: Lifecycle.cast(m)

  def cast(t), do: {:error, "Unsupported meta event: #{inspect(t)}"}

  def dump(_), do: :error

  def load(_), do: :error
end

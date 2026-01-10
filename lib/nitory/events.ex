defmodule Nitory.Events do
  use Ecto.Type

  alias Nitory.Events.{MetaEvent, Message, Notice, Request, Echo}

  @type t :: MetaEvent.t() | Message.t() | Notice.t() | Request.t() | Echo.t()

  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{"post_type" => "meta_event"} = m), do: MetaEvent.cast(m)

  def cast(%{"post_type" => "message"} = m), do: Message.cast(m)

  def cast(%{"post_type" => "notice"} = m), do: Notice.cast(m)

  def cast(%{"post_type" => "request"} = m), do: Request.cast(m)

  def cast(%{"echo" => _} = m), do: Echo.new(m)

  def cast(t), do: {:error, "Unsupported event: #{inspect(t)}"}

  def dump(_), do: :error

  def load(_), do: :error
end

defmodule Nitory.Events.Types do
  use Flint.Type, extends: Ecto.Enum, values: [:meta_event, :message, :notice, :request, :echo]
end

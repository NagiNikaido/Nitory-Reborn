defmodule Nitory.Event do
  use Ecto.Type

  alias Nitory.Events.{MetaEvent, IncomingMessage, Notice, Request, Echo}

  @type t :: MetaEvent.t() | IncomingMessage.t() | Notice.t() | Request.t() | Echo.t()

  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{"post_type" => "meta_event"} = m), do: MetaEvent.cast(m)
  def cast(%{post_type: :meta_event} = m), do: MetaEvent.cast(m)

  def cast(%{"post_type" => "message"} = m), do: IncomingMessage.cast(m)
  def cast(%{post_type: :message} = m), do: IncomingMessage.cast(m)

  def cast(%{"post_type" => "notice"} = m), do: Notice.cast(m)
  def cast(%{post_type: :notice} = m), do: Notice.cast(m)

  def cast(%{"post_type" => "request"} = m), do: Request.cast(m)
  def cast(%{post_type: :request} = m), do: Request.cast(m)

  def cast(%{"echo" => _} = m), do: Echo.new(m)
  def cast(%{echo: _} = m), do: Echo.new(m)

  def cast(t), do: {:error, "Unsupported event: #{inspect(t)}"}

  def dump(_), do: :error

  def load(_), do: :error
end

defmodule Nitory.Event.Types do
  use Flint.Type, extends: Ecto.Enum, values: [:meta_event, :message, :notice, :request, :echo]
end

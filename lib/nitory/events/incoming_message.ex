defmodule Nitory.Events.IncomingMessage.Types do
  use Flint.Type, extends: Ecto.Enum, values: [:group, :private]
end

defmodule Nitory.Events.IncomingMessage.PrivateMessage do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :message_type, Nitory.Events.IncomingMessage.Types
    field! :message_id, :integer
    field! :user_id, :integer
    field! :message, Nitory.Message
    field :raw_message, :string
    field :font, :integer
    field :target_id, :integer
    field :temp_source, :integer

    embeds_one :sender, Sender do
      field! :user_id, :integer
      field! :nickname, :string
      field :sex, Ecto.Enum, values: [:male, :female, :unknown]
      field :age, :integer
    end

    field! :sub_type, Ecto.Enum, values: [:friend, :group, :other]
  end
end

defmodule Nitory.Events.IncomingMessage.GroupMessage do
  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :message_type, Nitory.Events.IncomingMessage.Types
    field! :sub_type, Ecto.Enum, values: [:normal, :anonymous, :notice]
    field! :message_id, :integer
    field! :user_id, :integer
    field! :group_id, :integer
    field! :message, Nitory.Message
    field :raw_message, :string
    field :font, :integer

    embeds_one! :sender, Sender do
      field! :user_id, :integer
      field! :nickname, :string
      field :sex, Ecto.Enum, values: [:male, :female, :unknown]
      field :card, :string
      field :role, Ecto.Enum, values: [:owner, :admin, :member]
    end
  end
end

defmodule Nitory.Events.IncomingMessage do
  use Ecto.Type

  alias Nitory.Events.IncomingMessage.{GroupMessage, PrivateMessage}

  @type t :: GroupMessage.t() | PrivateMessage.t()

  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{"message_type" => "group"} = m), do: GroupMessage.cast(m)
  def cast(%{message_type: :group} = m), do: GroupMessage.cast(m)

  def cast(%{"message_type" => "private"} = m), do: PrivateMessage.cast(m)
  def cast(%{message_type: :private} = m), do: PrivateMessage.cast(m)

  def cast(t), do: {:error, "Unsupported incoming message event: #{inspect(t)}"}

  def dump(_), do: :error

  def load(_), do: :error
end

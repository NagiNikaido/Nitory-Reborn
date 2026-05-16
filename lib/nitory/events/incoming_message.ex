defmodule Nitory.Events.IncomingMessage.Types do
  @moduledoc "OneBot message type enum: `:group` or `:private`."

  use Flint.Type, extends: Ecto.Enum, values: [:group, :private]
end

defmodule Nitory.Events.IncomingMessage.PrivateMessage do
  @moduledoc """
  OneBot private message event (`post_type: "message", message_type: "private"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:message` | yes | Event post type |
  | `message_type` | `:private` | yes | Message type discriminator |
  | `sub_type` | `:friend` / `:group` / `:other` | yes | `:friend` for normal PM, `:group` for group temp chat |
  | `message_id` | `integer()` | yes | Unique message ID |
  | `user_id` | `integer()` | yes | Sender's QQ number |
  | `message` | `String.t()` \\| `[Segment.t()]` | yes | Message content |
  | `raw_message` | `String.t()` | no | Raw CQ-code string |
  | `font` | `integer()` | no | Font identifier |
  | `target_id` | `integer()` | no | Target group ID (for group temp chat) |
  | `temp_source` | `integer()` | no | Temp session source |
  | `sender.user_id` | `integer()` | yes | Sender's QQ number |
  | `sender.nickname` | `String.t()` | yes | Sender's nickname |
  | `sender.sex` | `:male` / `:female` / `:unknown` | no | Sender's gender |
  | `sender.age` | `integer()` | no | Sender's age |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.IncomingMessage.PrivateMessage.cast(%{
      ...>   "time" => 1_700_000_000, "self_id" => 12_345,
      ...>   "post_type" => "message", "message_type" => "private",
      ...>   "sub_type" => "friend", "message_id" => 1001,
      ...>   "user_id" => 67_890, "message" => "Hi",
      ...>   "raw_message" => "Hi", "font" => 0,
      ...>   "sender" => %{"user_id" => 67_890, "nickname" => "TestUser",
      ...>     "sex" => "male", "age" => 18}
      ...> })
      iex> ev.user_id
      67_890
      iex> ev.sender.nickname
      "TestUser"

  ## Serialization

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Events.IncomingMessage.PrivateMessage{
      ...>   time: 1, self_id: 1, post_type: :message, message_type: :private,
      ...>   sub_type: :friend, message_id: 1, user_id: 1, message: "Hi",
      ...>   raw_message: "Hi", font: 0, target_id: nil, temp_source: nil,
      ...>   sender: nil
      ...> })
      %{time: 1, self_id: 1, post_type: :message, message_type: :private,
        sub_type: :friend, message_id: 1, user_id: 1, message: "Hi",
        raw_message: "Hi", font: 0, target_id: nil, temp_source: nil,
        sender: nil}
  """

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
  @moduledoc """
  OneBot group message event (`post_type: "message", message_type: "group"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:message` | yes | Event post type |
  | `message_type` | `:group` | yes | Message type discriminator |
  | `sub_type` | `:normal` / `:anonymous` / `:notice` | yes | Message sub-type |
  | `message_id` | `integer()` | yes | Unique message ID |
  | `user_id` | `integer()` | yes | Sender's QQ number |
  | `group_id` | `integer()` | yes | Group ID |
  | `message` | `String.t()` \\| `[Segment.t()]` | yes | Message content |
  | `raw_message` | `String.t()` | no | Raw CQ-code string |
  | `font` | `integer()` | no | Font identifier |
  | `sender.user_id` | `integer()` | yes | Sender's QQ number |
  | `sender.nickname` | `String.t()` | yes | Sender's nickname |
  | `sender.sex` | `:male` / `:female` / `:unknown` | no | Sender's gender |
  | `sender.card` | `String.t()` | no | Group card name |
  | `sender.role` | `:owner` / `:admin` / `:member` | no | Role in group |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.IncomingMessage.GroupMessage.cast(%{
      ...>   "time" => 1_700_000_000, "self_id" => 12_345,
      ...>   "post_type" => "message", "message_type" => "group",
      ...>   "sub_type" => "normal", "message_id" => 2001,
      ...>   "user_id" => 67_890, "group_id" => 99_999,
      ...>   "message" => "hello", "raw_message" => "hello", "font" => 0,
      ...>   "sender" => %{"user_id" => 67_890, "nickname" => "User",
      ...>     "card" => "Admin", "role" => "admin"}
      ...> })
      iex> ev.group_id
      99_999
      iex> ev.sender.role
      :admin

  ## Serialization

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Events.IncomingMessage.GroupMessage{
      ...>   time: 1, self_id: 1, post_type: :message, message_type: :group,
      ...>   sub_type: :normal, message_id: 1, user_id: 1, group_id: 1,
      ...>   message: "hi", raw_message: "hi", font: 0,
      ...>   sender: %Nitory.Events.IncomingMessage.GroupMessage.Sender{
      ...>     user_id: 1, nickname: "U", sex: nil, card: nil, role: :member}
      ...> })
      %{time: 1, self_id: 1, post_type: :message, message_type: :group,
        sub_type: :normal, message_id: 1, user_id: 1, group_id: 1,
        message: "hi", raw_message: "hi", font: 0,
        sender: %{user_id: 1, nickname: "U", sex: nil, card: nil, role: :member}}
  """

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
  @moduledoc """
  Union type for incoming OneBot messages.

  Dispatches `cast/1` to `GroupMessage` or `PrivateMessage` based on
  the `message_type` field.
  """

  use Ecto.Type

  alias Nitory.Events.IncomingMessage.{GroupMessage, PrivateMessage}

  @type t :: GroupMessage.t() | PrivateMessage.t()

  @doc false
  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{"message_type" => "group"} = m), do: GroupMessage.cast(m)
  def cast(%{message_type: :group} = m), do: GroupMessage.cast(m)

  def cast(%{"message_type" => "private"} = m), do: PrivateMessage.cast(m)
  def cast(%{message_type: :private} = m), do: PrivateMessage.cast(m)

  def cast(t), do: {:error, "Unsupported incoming message event: #{inspect(t)}"}

  @doc false
  def dump(_), do: :error

  @doc false
  def load(_), do: :error
end

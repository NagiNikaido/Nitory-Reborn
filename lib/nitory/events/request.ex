defmodule Nitory.Events.Request.Types do
  @moduledoc "OneBot request type enum: `:friend` or `:group`."

  use Flint.Type, extends: Ecto.Enum, values: [:friend, :group]
end

defmodule Nitory.Events.Request.FriendRequest do
  @moduledoc """
  OneBot friend request event (`post_type: "request", request_type: "friend"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:request` | yes | Event post type |
  | `request_type` | `:friend` | yes | Request type discriminator |
  | `user_id` | `integer()` | yes | QQ number of the requesting user |
  | `comment` | `String.t()` | yes | Verification message |
  | `flag` | `String.t()` | yes | Request flag (used for approval) |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.Request.FriendRequest.cast(%{
      ...>   "time" => 1_700_000_000, "self_id" => 12_345,
      ...>   "post_type" => "request", "request_type" => "friend",
      ...>   "user_id" => 67_890, "comment" => "Hello!", "flag" => "abc123"
      ...> })
      iex> ev.user_id
      67_890
      iex> ev.comment
      "Hello!"

  ## Serialization

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Events.Request.FriendRequest{
      ...>   time: 1_700_000_000, self_id: 12_345,
      ...>   post_type: :request, request_type: :friend,
      ...>   user_id: 67_890, comment: "Hi", flag: "abc"
      ...> })
      %{time: 1_700_000_000, self_id: 12_345, post_type: :request, request_type: :friend,
        user_id: 67_890, comment: "Hi", flag: "abc"}
  """

  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :request_type, Nitory.Events.Request.Types
    field! :user_id, :integer
    field! :comment, :string
    field! :flag, :string
  end
end

defmodule Nitory.Events.Request.GroupRequest do
  @moduledoc """
  OneBot group request event (`post_type: "request", request_type: "group"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `time` | `integer()` | yes | Event timestamp (Unix) |
  | `self_id` | `integer()` | yes | Bot's own QQ number |
  | `post_type` | `:request` | yes | Event post type |
  | `request_type` | `:group` | yes | Request type discriminator |
  | `sub_type` | `:add` / `:invite` | yes | `:add` for join request, `:invite` for invitation |
  | `user_id` | `integer()` | yes | QQ number of the requesting/invited user |
  | `comment` | `String.t()` | yes | Verification message |
  | `flag` | `String.t()` | yes | Request flag (used for approval) |

  ## Deserialization

      iex> {:ok, ev} = Nitory.Events.Request.GroupRequest.cast(%{
      ...>   "time" => 1_700_000_000, "self_id" => 12_345,
      ...>   "post_type" => "request", "request_type" => "group",
      ...>   "sub_type" => "add", "user_id" => 67_890,
      ...>   "comment" => "pls add me", "flag" => "def456"
      ...> })
      iex> ev.sub_type
      :add
      iex> ev.user_id
      67_890

  ## Serialization

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Events.Request.GroupRequest{
      ...>   time: 1_700_000_000, self_id: 12_345,
      ...>   post_type: :request, request_type: :group,
      ...>   sub_type: :invite, user_id: 67_890,
      ...>   comment: "join us", flag: "def"
      ...> })
      %{time: 1_700_000_000, self_id: 12_345, post_type: :request, request_type: :group,
        sub_type: :invite, user_id: 67_890, comment: "join us", flag: "def"}
  """

  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :time, :integer
    field! :self_id, :integer
    field! :post_type, Nitory.Event.Types
    field! :request_type, Nitory.Events.Request.Types
    field! :user_id, :integer
    field! :comment, :string
    field! :flag, :string
    field! :sub_type, Ecto.Enum, values: [:add, :invite]
  end
end

defmodule Nitory.Events.Request do
  @moduledoc """
  Union type for OneBot request events.

  Dispatches `cast/1` to `FriendRequest` or `GroupRequest` based on the
  `request_type` field.
  """

  use Ecto.Type

  alias Nitory.Events.Request.{FriendRequest, GroupRequest}

  @type t :: FriendRequest.t() | GroupRequest.t()

  @doc false
  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{"request_type" => "friend"} = m), do: FriendRequest.cast(m)
  def cast(%{request_type: :friend} = m), do: FriendRequest.cast(m)

  def cast(%{"request_type" => "group"} = m), do: GroupRequest.cast(m)
  def cast(%{request_type: :group} = m), do: GroupRequest.cast(m)

  def cast(t), do: {:error, "Unsupported request event: #{inspect(t)}"}

  @doc false
  def dump(_), do: :error

  @doc false
  def load(_), do: :error
end

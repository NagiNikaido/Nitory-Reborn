defmodule Nitory.Events.Request.Types do
  @moduledoc "OneBot request type enum: `:friend` or `:group`."

  use Flint.Type, extends: Ecto.Enum, values: [:friend, :group]
end

defmodule Nitory.Events.Request.FriendRequest do
  @moduledoc """
  OneBot friend request event schema.

  Represents an incoming friend invitation, including the requesting user's ID,
  a comment message, and a flag token used for approval.
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
  OneBot group request event schema.

  Represents a group join request or invitation, with a sub-type of `:add` or `:invite`.
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

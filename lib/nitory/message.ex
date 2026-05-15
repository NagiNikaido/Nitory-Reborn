defmodule Nitory.Message.Segment.Types do
  @moduledoc "OneBot message segment type enum: `:text`, `:image`, `:reply`, `:at`."

  use Flint.Type, extends: Ecto.Enum, values: [:text, :image, :reply, :at]
end

defmodule Nitory.Message.Segment.Text do
  @moduledoc """
  OneBot text message segment schema.

  Contains a single `data.text` field with the plain text content.
  """

  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :type, Nitory.Message.Segment.Types, default: :text

    embeds_one! :data, Datum do
      field! :text, :string
    end
  end
end

defmodule Nitory.Message.Segment.Image do
  @moduledoc """
  OneBot image message segment schema.

  Contains image metadata: local file path, thumbnail, remote URL,
  summary (for accessibility), and sub-type (`:normal` or `:custom`).
  """

  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :type, Nitory.Message.Segment.Types, default: :image

    embeds_one! :data, Datum do
      field! :file, :string
      field :thumb, :string
      field :url, :string
      field :summary, :string
      field :sub_type, Ecto.Enum, values: [normal: 0, custom: 1]
    end
  end
end

defmodule Nitory.Message.Segment.At do
  @moduledoc """
  OneBot at-mention message segment schema.

  Represents an @mention targeting a QQ user. The `qq` field accepts
  either a string (e.g. `"all"`) or an integer user ID.
  """

  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :type, Nitory.Message.Segment.Types, default: :at

    embeds_one! :data, Datum do
      field! :qq, Union, oneof: [:string, :integer]
      field :name, :string
    end
  end
end

defmodule Nitory.Message.Segment.Reply do
  @moduledoc """
  OneBot reply message segment schema.

  Represents a reply to a previous message, identified by the original
  message's `data.id`.
  """

  use Nitory.Helper.LeafSchema

  embedded_schema do
    field! :type, Nitory.Message.Segment.Types, default: :reply

    embeds_one! :data, Datum do
      field! :id, :string
    end
  end
end

defmodule Nitory.Message.Segment do
  @moduledoc """
  Union type for OneBot message segments.

  A message is composed of an array of segments. This module dispatches
  `cast/1` to `Text`, `Image`, `At`, or `Reply` based on the `type` field,
  and `dump/1` serializes back via `Nitory.Helper.LeafSchema.dump/1`.
  """

  use Ecto.Type
  alias Nitory.Message.Segment.{Text, Image, At, Reply}

  @type t :: Text.t() | Image.t() | At.t() | Reply.t()

  def type, do: :any

  @spec cast(map()) :: {:ok, t()} | {:error, term()}
  def cast(%{"type" => "text", "data" => _} = m), do: Text.cast(m)
  def cast(%{type: :text, data: _} = m), do: Text.cast(m)

  def cast(%{"type" => "image", "data" => _} = m), do: Image.cast(m)
  def cast(%{type: :image, data: _} = m), do: Image.cast(m)

  def cast(%{"type" => "reply", "data" => _} = m), do: Reply.cast(m)
  def cast(%{type: :reply, data: _} = m), do: Reply.cast(m)

  def cast(%{"type" => "at", "data" => _} = m), do: At.cast(m)
  def cast(%{type: :at, data: _} = m), do: At.cast(m)

  def cast(t), do: {:error, "Unsupported segment #{inspect(t)}!"}

  def dump(t), do: {:ok, Nitory.Helper.LeafSchema.dump(t)}

  def load(_), do: :error
end

defmodule Nitory.Message do
  @moduledoc """
  OneBot message type (string or segment array).

  A message can be a raw string or a list of `Nitory.Message.Segment`
  structs. `cast/1` accepts either form; `dump/1` normalizes segments
  through their respective `dump` functions.
  """

  use Ecto.Type
  alias Nitory.Message.Segment

  @type t :: String.t() | [Segment.t()]

  def type, do: :any

  @spec cast(String.t()) :: {:ok, String.t()}
  @spec cast([map()]) :: {:ok, [Segment.t()]} | {:error, term()}
  def cast(msg) when is_binary(msg) do
    {:ok, msg}
  end

  def cast(msg) when is_list(msg) do
    msg_list = Enum.map(msg, &Segment.cast/1)

    if Enum.all?(msg_list, &(elem(&1, 0) == :ok)) do
      {:ok, Enum.map(msg_list, &elem(&1, 1))}
    else
      err_msg =
        msg_list
        |> Enum.filter(&(elem(&1, 0) == :error))
        |> Enum.map(&elem(&1, 1))

      {:error, err_msg}
    end
  end

  def cast(t), do: {:error, "Unsupported message #{inspect(t)}!"}

  def dump(msg) when is_binary(msg), do: {:ok, msg}

  def dump(msg) when is_list(msg) do
    msg_list = Enum.map(msg, &Segment.dump/1)

    if Enum.all?(msg_list, &(elem(&1, 0) == :ok)) do
      {:ok, Enum.map(msg_list, &elem(&1, 1))}
    else
      :error
    end
  end

  def embed_as(_), do: :dump

  def load(_), do: :error
end
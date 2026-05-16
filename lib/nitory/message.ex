defmodule Nitory.Message.Segment.Types do
  @moduledoc "OneBot message segment type enum: `:text`, `:image`, `:reply`, `:at`."

  use Flint.Type, extends: Ecto.Enum, values: [:text, :image, :reply, :at]
end

defmodule Nitory.Message.Segment.Text do
  @moduledoc """
  OneBot text segment (`type: "text"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `type` | `:text` | yes | Segment type discriminator |
  | `data.text` | `String.t()` | yes | Plain text content |

  ## Deserialization (JSON → struct)

  `cast/1` accepts a raw OneBot map with string keys:

      iex> {:ok, seg} = Nitory.Message.Segment.Text.cast(%{type: :text, data: %{text: "hello"}})
      iex> seg.type
      :text
      iex> seg.data.text
      "hello"

  ## Serialization (struct → map)

  `Nitory.Helper.LeafSchema.dump/1` converts back for OneBot transport:

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Message.Segment.Text{
      ...>   type: :text,
      ...>   data: %Nitory.Message.Segment.Text.Datum{text: "hello"}
      ...> })
      %{type: :text, data: %{text: "hello"}}
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
  OneBot image segment (`type: "image"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `type` | `:image` | yes | Segment type discriminator |
  | `data.file` | `String.t()` | yes | Image filename or path on local filesystem |
  | `data.url` | `String.t()` | no | Remote URL of the image |
  | `data.thumb` | `String.t()` | no | Thumbnail URL |
  | `data.summary` | `String.t()` | no | Accessibility summary (alt text) |
  | `data.sub_type` | `:normal` / `:custom` | no | `:normal` for standard image, `:custom` for sticker/emoji |

  ## Deserialization (JSON → struct)

      iex> {:ok, seg} = Nitory.Message.Segment.Image.cast(%{
      ...>   "type" => "image",
      ...>   "data" => %{"file" => "abc.jpg", "url" => "https://example.com/abc.jpg", "sub_type" => 0}
      ...> })
      iex> seg.data.file
      "abc.jpg"
      iex> seg.data.sub_type
      :normal

  ## Serialization (struct → map)

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Message.Segment.Image{
      ...>   type: :image,
      ...>   data: %Nitory.Message.Segment.Image.Datum{
      ...>     file: "abc.jpg", url: "https://example.com/abc.jpg",
      ...>     thumb: nil, summary: nil, sub_type: :normal
      ...>   }
      ...> })
      %{data: %{file: "abc.jpg", summary: nil, sub_type: :normal, thumb: nil, url: "https://example.com/abc.jpg"}, type: :image}
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
  OneBot at-mention segment (`type: "at"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `type` | `:at` | yes | Segment type discriminator |
  | `data.qq` | `String.t()` \\| `integer()` | yes | Target QQ number, or `"all"` for @everyone |
  | `data.name` | `String.t()` | no | Display name (usually group card or nickname) |

  ## Deserialization (JSON → struct)

      iex> {:ok, seg} = Nitory.Message.Segment.At.cast(%{
      ...>   "type" => "at", "data" => %{"qq" => 123456, "name" => "小明"}
      ...> })
      iex> seg.data.qq
      123456
      iex> seg.data.name
      "小明"

  ## @everyone

      iex> {:ok, seg} = Nitory.Message.Segment.At.cast(%{
      ...>   "type" => "at", "data" => %{"qq" => "all"}
      ...> })
      iex> seg.data.qq
      "all"

  ## Serialization (struct → map)

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Message.Segment.At{
      ...>   type: :at,
      ...>   data: %Nitory.Message.Segment.At.Datum{qq: 123456, name: "小明"}
      ...> })
      %{type: :at, data: %{name: "小明", qq: 123456}}
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
  OneBot reply segment (`type: "reply"`).

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `type` | `:reply` | yes | Segment type discriminator |
  | `data.id` | `String.t()` | yes | Message ID being replied to |

  ## Deserialization (JSON → struct)

      iex> {:ok, seg} = Nitory.Message.Segment.Reply.cast(%{
      ...>   "type" => "reply", "data" => %{"id" => "10086"}
      ...> })
      iex> seg.data.id
      "10086"

  ## Serialization (struct → map)

      iex> Nitory.Helper.LeafSchema.dump(%Nitory.Message.Segment.Reply{
      ...>   type: :reply,
      ...>   data: %Nitory.Message.Segment.Reply.Datum{id: "10086"}
      ...> })
      %{type: :reply, data: %{id: "10086"}}

  > The reply segment carries only the original message ID.  Full reply
  > metadata (sender, content, time) is available via
  > `Nitory.Events.IncomingMessage` events.
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

  @doc false
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

  @doc false
  def dump(t), do: {:ok, Nitory.Helper.LeafSchema.dump(t)}

  @doc false
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

  @doc false
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

  @doc false
  def dump(msg) when is_binary(msg), do: {:ok, msg}

  @doc false
  def dump(msg) when is_list(msg) do
    msg_list = Enum.map(msg, &Segment.dump/1)

    if Enum.all?(msg_list, &(elem(&1, 0) == :ok)) do
      {:ok, Enum.map(msg_list, &elem(&1, 1))}
    else
      :error
    end
  end

  @doc false
  def embed_as(_), do: :dump

  @doc false
  def load(_), do: :error
end

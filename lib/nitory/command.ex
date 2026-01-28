defmodule Nitory.Command do
  require Logger

  defmodule Option do
    @type t :: %__MODULE__{
            name: atom(),
            predicator: (String.t() -> boolean()) | nil,
            optional: boolean()
          }
    defstruct [:name, :predicator, :optional]
  end

  @type t :: %__MODULE__{
          display_name: String.t() | nil,
          hidden: boolean(),
          short_usage: String.t() | nil,
          usage: String.t() | nil,
          cmd_face: String.t() | {Regex.t(), [atom()]},
          options: [Option.t() | :rest],
          action: function() | mfa(),
          msg_type: :private | :group | nil
        }
  defstruct [
    :display_name,
    :hidden,
    :short_usage,
    :usage,
    :cmd_face,
    :options,
    :action,
    :msg_type
  ]

  @spec new(keyword()) :: {:ok, t()} | {:error, atom()}
  def new(opt) do
    with {:ok, hidden} <- Keyword.fetch(opt, :hidden),
         {:ok, cmd_face} <- Keyword.fetch(opt, :cmd_face),
         {:ok, action} <- Keyword.fetch(opt, :action) do
      display_name = Keyword.get(opt, :display_name)
      short_usage = Keyword.get(opt, :short_usage)
      usage = Keyword.get(opt, :usage)
      options = Keyword.get(opt, :options, [])
      msg_type = Keyword.get(opt, :msg_type)

      cond do
        hidden and !display_name and !short_usage and !usage ->
          {:ok,
           %__MODULE__{
             hidden: true,
             cmd_face: cmd_face,
             options: options,
             action: action,
             msg_type: msg_type
           }}

        !hidden and !!display_name and !!short_usage and !!usage ->
          {:ok,
           %__MODULE__{
             display_name: display_name,
             hidden: false,
             short_usage: short_usage,
             usage: usage,
             cmd_face: cmd_face,
             options: options,
             action: action,
             msg_type: msg_type
           }}

        true ->
          {:error, :required_field_not_found}
      end
    else
      :error -> {:error, :required_field_not_found}
    end
  end

  @spec parse(Nitory.Command.t(), [String.t()], [term()]) ::
          {:ok, {Nitory.Command.t(), [term()]}}
          | {:error,
             {:unparsed_arguments, Nitory.Command.t(), [String.t()]}
             | {:options_after_rest, Nitory.Command.t()}
             | {:wrong_argument, Nitory.Command.t(), String.t()}
             | {:wrong_msg_type, Nitory.Command.t(), :private | :group}
             | :command_face_not_match}
  def parse(cmd, raw_args, opt \\ [])

  def parse(%{cmd_face: {regex, binding_list}} = cmd, raw_args, opt) do
    msg = Keyword.fetch!(opt, :msg)
    [given_cmd | rest_args] = raw_args
    bindings = Regex.named_captures(regex, given_cmd, capture: binding_list)

    if !!bindings do
      if cmd.msg_type == nil or cmd.msg_type == msg.message_type do
        bindings = Enum.map(bindings, fn {key, val} -> {String.to_existing_atom(key), val} end)

        parse_optional_arguments(cmd, cmd.options, rest_args, opt ++ bindings)
      else
        {:error, {:wrong_msg_type, cmd, cmd.msg_type}}
      end
    else
      {:error, :command_face_not_match}
    end
  end

  def parse(%{cmd_face: cmd_face} = cmd, raw_args, opt) when is_binary(cmd_face) do
    msg = Keyword.fetch!(opt, :msg)
    [given_cmd | rest_args] = raw_args

    if cmd_face == given_cmd do
      if cmd.msg_type == nil or cmd.msg_type == msg.message_type do
        parse_optional_arguments(cmd, cmd.options, rest_args, opt)
      else
        {:error, {:wrong_msg_type, cmd, cmd.msg_type}}
      end
    else
      {:error, :command_face_not_match}
    end
  end

  @spec parse_optional_arguments(
          Nitory.Command.t(),
          [Nitory.Command.Option.t()],
          [String.t()],
          [term()]
        ) ::
          {:ok, {Nitory.Command.t(), [term()]}}
          | {:error,
             {:unparsed_arguments, Nitory.Command.t(), [String.t()]}
             | {:options_after_rest, Nitory.Command.t()}
             | {:wrong_argument, Nitory.Command.t(), String.t()}}
  def parse_optional_arguments(cmd, options, args, parsed_opts)

  def parse_optional_arguments(cmd, [], [], parsed_opts), do: {:ok, {cmd, parsed_opts}}

  def parse_optional_arguments(cmd, [], args, _), do: {:error, {:unparsed_arguments, cmd, args}}

  def parse_optional_arguments(cmd, [:rest], args, parsed_opts),
    do: {:ok, {cmd, parsed_opts ++ args}}

  def parse_optional_arguments(cmd, [:rest | _], _, _), do: {:error, {:options_after_rest, cmd}}

  def parse_optional_arguments(cmd, [opt | rest_opts], [], parsed_opts) do
    if opt.optional do
      parse_optional_arguments(cmd, rest_opts, [], parsed_opts ++ [nil])
    else
      {:error, {:wrong_argument, cmd, opt.name}}
    end
  end

  def parse_optional_arguments(cmd, [opt | rest_opts], [arg | rest_args] = args, parsed_opts) do
    cond do
      opt.predicator == nil or opt.predicator.(arg) ->
        parse_optional_arguments(cmd, rest_opts, rest_args, parsed_opts ++ [{opt.name, arg}])

      opt.optional ->
        parse_optional_arguments(cmd, rest_opts, args, parsed_opts ++ [{opt.name, nil}])

      true ->
        {:error, {:wrong_argument, cmd, opt.name}}
    end
  end
end

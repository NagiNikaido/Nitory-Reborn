defmodule Nitory.Helper.LeafSchema do
  defmacro __using__(opt) do
    quote do
      use Flint.Schema, unquote(opt)

      def new(params \\ %{}, bindings \\ []),
        do: Nitory.Helper.LeafSchema.new(__MODULE__, params, bindings)

      def new!(params \\ %{}, bindings \\ []),
        do: Nitory.Helper.LeafSchema.new!(__MODULE__, params, bindings)

      def cast(params),
        do: Nitory.Helper.LeafSchema.cast(__MODULE__, params)

      def load(params),
        do: Nitory.Helper.LeafSchema.load(__MODULE__, params)

      def dump(obj),
        do: Nitory.Helper.LeafSchema.dump(obj)
    end
  end

  def cast(module, params), do: new(module, params)

  def load(module, params), do: new(module, params)

  def dump(obj), do: Ecto.embedded_dump(obj, :json)

  def new(module, params \\ %{}, bindings \\ []) do
    changeset = apply(module, :changeset, [struct!(module), params, bindings])

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      msg =
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
            opts |> Keyword.get(String.to_atom(key), key) |> to_string()
          end)
        end)

      {:error, msg}
    end
  end

  def new!(module, params \\ %{}, bindings \\ []) do
    case new(module, params, bindings) do
      {:ok, res} ->
        res

      {:error, msg} ->
        raise ArgumentError,
              "#{inspect(struct!(module, Map.merge(params, msg)), pretty: true)}"
    end
  end
end

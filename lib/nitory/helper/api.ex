defmodule Nitory.Helper.Api do
  defmacro api(handler, do: block) do
    handler_module =
      handler
      |> Atom.to_string()
      |> Macro.camelize()
      |> (&Module.concat(__CALLER__.module, &1)).()

    input_spec_module = Module.concat(handler_module, "InputSpec")
    output_spec_module = Module.concat(handler_module, "OutputSpec")

    Module.put_attribute(__CALLER__.module, :apis, {handler, handler_module})
    IO.inspect(handler_module)

    quote do
      defmodule unquote(handler_module) do
        unquote(block)

        def handler, do: unquote(handler)

        def validate_input(input), do: unquote(input_spec_module).new(input)

        def validate_output(output), do: unquote(output_spec_module).new(output)
      end
    end
  end

  defmacro input_spec(do: block) do
    quote do
      defmodule InputSpec do
        @moduledoc false
        use Nitory.Helper.LeafSchema

        embedded_schema do
          unquote(block)
        end
      end

      @type input() :: InputSpec.t()
    end
  end

  defmacro output_spec(do: block) do
    quote do
      defmodule OutputSpec do
        @moduledoc false
        use Nitory.Helper.LeafSchema

        embedded_schema do
          unquote(block)
        end
      end

      @type output() :: OutputSpec.t()
    end
  end

  defmacro __using__(_opt) do
    Module.register_attribute(__CALLER__.module, :apis, accumulate: true)

    quote do
      use GenServer
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

      def help, do: "#{inspect(@apis)}"
    end
  end

  defmacro __before_compile__(_opt) do
    apis = Module.get_attribute(__CALLER__.module, :apis)

    calls =
      Enum.map(apis, fn {handler, handler_module} ->
        quote do
          def prepare_request(unquote(handler), params) do
            unquote(handler_module).validate_input(params)
          end

          def prepare_response(unquote(handler), params) do
            unquote(handler_module).validate_output(params)
          end
        end
      end)

    quote do
      (unquote_splicing(calls))
    end
  end
end

defmodule Nitory.Plugins.Dice.AST do
  defmodule DiceAST do
    @moduledoc """

    """
    @type t :: %__MODULE__{
            cnt: pos_integer(),
            face: pos_integer(),
            opt: {:high | :low | :lower_bound | :upper_bound, pos_integer()},
            extra: pos_integer()
          }
    defstruct cnt: nil,
              face: nil,
              opt: nil,
              extra: nil

    @spec new(map() | keyword(), __MODULE__.t() | nil) ::
            {:ok, __MODULE__.t()} | {:error, String.t()}
    def new(k_or_m, default_dice \\ nil)

    def new(k_or_m, nil)
        when is_list(k_or_m) or is_map(k_or_m) do
      dice = struct!(__MODULE__, k_or_m)

      if legal?(dice) do
        {:ok, dice}
      else
        {:error, "Illegal Dice parameters #{inspect(k_or_m)}."}
      end
    end

    def new(k_or_m, default_dice)
        when (is_list(k_or_m) or is_map(k_or_m)) and is_struct(default_dice, __MODULE__) do
      dice =
        struct!(__MODULE__, k_or_m)
        |> (&if(&1.opt == nil, do: %{&1 | opt: default_dice.opt}, else: &1)).()
        |> (&if(&1.extra == nil, do: %{&1 | extra: default_dice.extra}, else: &1)).()
        |> (&(if &1.cnt == nil do
                c_dice = &1

                cnt =
                  default_dice.cnt
                  |> (fn cnt ->
                        with {:high, high} <- c_dice.opt do
                          max(cnt, high + 1)
                        else
                          _ -> cnt
                        end
                      end).()
                  |> (fn cnt ->
                        with {:low, low} <- c_dice.opt do
                          max(&1, low + 1)
                        else
                          _ -> cnt
                        end
                      end).()

                %{&1 | cnt: cnt}
              else
                &1
              end)).()
        |> (&(if &1.face == nil do
                c_dice = &1

                face =
                  default_dice.face
                  |> (fn face ->
                        with {:lower_bound, lb} <- c_dice.opt do
                          max(face, lb + 1)
                        else
                          _ -> face
                        end
                      end).()
                  |> (fn face ->
                        with {:upper_bound, ub} <- c_dice.opt do
                          max(face, ub + 1)
                        else
                          _ -> face
                        end
                      end).()
                  |> (fn face ->
                        if c_dice.extra != nil, do: max(face, c_dice.extra + 1), else: face
                      end).()

                %{&1 | face: face}
              else
                &1
              end)).()

      # if dice.opt == nil, do: ^dice = %{dice | opt: default_dice.opt}

      # if dice.extra == nil, do: ^dice = %{dice | extra: default_dice.extra}

      # if dice.cnt == nil do
      #   cnt = default_dice.cnt
      #   with {:high, high} <- dice.opt, do: ^cnt = max(cnt, high + 1)

      #   with {:low, low} <- dice.opt, do: ^cnt = max(cnt, low + 1)
      #   ^dice = %{dice | cnt: cnt}
      # end

      # if dice.face == nil do
      #   face = default_dice.face

      #   with {:lower_bound, lb} <- dice.opt, do: ^face = max(face, lb + 1)

      #   with {:upper_bound, ub} <- dice.opt, do: ^face = max(face, ub + 1)

      #   if dice.extra != nil, do: ^face = max(face, dice.extra + 1)
      #   ^dice = %{dice | face: face}
      # end

      if legal?(dice) do
        {:ok, dice}
      else
        {:error, "Illegal Dice #{inspect(dice)}."}
      end
    end

    @spec legal?(__MODULE__.t()) :: boolean()
    def legal?(dice) do
      if dice.cnt == nil or dice.face == nil do
        false
      else
        case dice.opt do
          {:lower_bound, lb} ->
            (1 <= lb and lb <= dice.face and
               dice.extra == nil) or (2 <= dice.extra and dice.extra <= dice.face)

          {:upper_bound, ub} ->
            (1 <= ub and ub <= dice.face and
               dice.extra == nil) or (1 <= dice.extra and dice.extra < dice.face)

          {:low, low} ->
            low < dice.cnt

          {:high, high} ->
            high < dice.cnt

          nil ->
            true
        end
      end
    end

    @spec to_string(__MODULE__.t()) :: String.t()
    def to_string(dice) do
      "#{dice.cnt}d#{dice.face}" <>
        case dice.opt do
          {:lower_bound, lb} -> "a#{lb}"
          {:upper_bound, ub} -> "b#{ub}"
          {:low, low} -> "l#{low}"
          {:high, high} -> "h#{high}"
          nil -> ""
        end <>
        if(dice.extra == nil, do: "", else: "e#{dice.extra}")
    end

    defmodule Parser do
      alias Ergo
      alias Ergo.Context
      import Ergo.{Terminals, Combinators, Numeric, Meta}

      def lower_bound() do
        sequence([
          ignore(char([?a, ?A])),
          optional(uint()) |> transform(fn ast -> {:lower_bound, ast} end)
        ])
        |> hoist()
      end

      def upper_bound() do
        sequence([
          ignore(char([?b, ?B])),
          optional(uint()) |> transform(fn ast -> {:upper_bound, ast} end)
        ])
        |> hoist()
      end

      def low() do
        sequence([
          ignore(char([?l, ?L])),
          optional(uint()) |> transform(fn ast -> {:low, ast} end)
        ])
        |> hoist()
      end

      def high() do
        sequence([
          ignore(char([?h, ?H])),
          optional(uint()) |> transform(fn ast -> {:high, ast} end)
        ])
        |> hoist()
      end

      def extra() do
        sequence([
          ignore(char([?e, ?E])),
          optional(uint()) |> transform(fn ast -> {:extra, ast} end)
        ])
        |> hoist()
      end

      def face() do
        sequence([
          ignore(char([?d, ?D])),
          optional(uint()) |> transform(fn ast -> {:face, ast} end)
        ])
        |> hoist()
      end

      def dice() do
        sequence(
          [
            optional(uint()) |> transform(fn ast -> {:cnt, ast} end),
            optional(face()),
            optional(
              choice([lower_bound(), upper_bound(), low(), high()])
              |> transform(fn ast -> {:opt, ast} end)
            ),
            optional(extra())
          ],
          ctx: fn %Context{ast: ast} = ctx ->
            if length(ast) <= 1 do
              ctx
              |> Context.add_error(:not_a_dice, "It is not a dice!")
            else
              nd = DiceAST.new(ast, ctx.captures["default_dice"])

              case nd do
                {:ok, dice} -> %{ctx | ast: dice}
                {:error, reason} -> Context.add_error(ctx, :illegal_dice, reason)
              end
            end
          end
        )
      end

      def just_dice() do
        sequence([dice(), eoi()]) |> hoist()
      end
    end

    @spec parse(binary()) :: {:ok, __MODULE__.t()} | {:error, term()}
    def parse(input) when is_binary(input) do
      %Ergo.Context{status: status, ast: ast} = Ergo.parse(Parser.just_dice(), input)

      case status do
        :ok -> {:ok, ast}
        {:error, _} -> status
      end
    end

    @spec parse!(binary()) :: __MODULE__.t()
    def parse!(input) when is_binary(input) do
      case parse(input) do
        {:ok, value} ->
          value

        {:error, reason} ->
          raise ArgumentError,
                "Cannot parse #{inspect(input)} into Dice, reason: #{inspect(reason)}"
      end
    end
  end

  defimpl String.Chars, for: DiceAST do
    def to_string(dice) do
      DiceAST.to_string(dice)
    end
  end

  defmodule DiceExpr do
    @type dice_cell :: %{type: :cell, ast: DiceAST.t() | number() | dice_expr()}
    @type term_ops :: :* | :/
    @type expr_ops :: :+ | :-
    @type ops :: expr_ops() | term_ops() | :nop
    @type dice_nop_opd :: %{op: :nop, opd: nil}
    @type dice_term_opds :: %{op: term_ops(), opd: dice_cell()}
    @type dice_term :: %{
            type: :term,
            ast: {dice_cell(), [dice_term_opds() | dice_nop_opd(), ...]}
          }
    @type dice_expr_opds :: %{op: expr_ops(), opd: dice_term()}
    @type dice_expr :: %{
            type: :expr,
            ast: {dice_term(), [dice_expr_opds() | dice_nop_opd(), ...]}
          }
    @type dice_full_expr :: %{
            type: :full_expr,
            ast: dice_expr(),
            repeat: integer() | nil
          }

    defmodule Parser do
      alias Ergo
      alias Ergo.Context
      import Ergo.{Terminals, Combinators, Numeric, Meta}

      def cell() do
        choice([
          DiceAST.Parser.dice(),
          number(),
          sequence([ignore(char(?()), lazy(expr()), ignore(char(?)))]) |> hoist()
        ])
        |> transform(fn ast -> %{type: :cell, ast: ast} end)
      end

      def term() do
        sequence([
          cell(),
          many(
            sequence([
              choice([literal("*"), literal("/")])
              |> atom()
              |> transform(fn ast -> {:op, ast} end),
              cell() |> transform(fn ast -> {:opd, ast} end)
            ])
            |> transform(fn ast -> Enum.into(ast, %{}) end)
          )
          |> transform(fn ast -> if ast == [], do: [%{op: :nop, opd: nil}], else: ast end)
        ])
        |> transform(fn ast -> %{type: :term, ast: List.to_tuple(ast)} end)
      end

      def expr() do
        sequence([
          term(),
          many(
            sequence([
              choice([literal("+"), literal("-")])
              |> atom()
              |> transform(fn ast -> {:op, ast} end),
              term() |> transform(fn ast -> {:opd, ast} end)
            ])
            |> transform(fn ast -> Enum.into(ast, %{}) end)
          )
          |> transform(fn ast -> if ast == [], do: [%{op: :nop, opd: nil}], else: ast end)
        ])
        |> transform(fn ast -> %{type: :expr, ast: List.to_tuple(ast)} end)
      end

      def expr_or_empty() do
        choice([
          expr(),
          ignore(eoi(),
            ctx: fn %Context{} = ctx ->
              %{
                ctx
                | ast: %{
                    type: :expr,
                    ast: {
                      %{
                        type: :term,
                        ast: {
                          %{
                            type: :cell,
                            ast: ctx.captures["default_dice"]
                          },
                          [%{op: :nop, opd: nil}]
                        }
                      },
                      [%{op: :nop, opd: nil}]
                    }
                  }
              }
            end
          )
        ])
      end

      def full_expr(default_dice \\ nil) do
        sequence([
          capture(commit(), "default_dice", fn _ -> default_dice end),
          commit() |> transform(fn _ -> {:type, :full_expr} end),
          optional(sequence([uint(), ignore(char(?#))]) |> hoist())
          |> transform(fn ast -> {:repeat, ast} end),
          expr_or_empty() |> transform(fn ast -> {:ast, ast} end),
          eoi()
        ])
        |> transform(fn ast -> Enum.into(ast, %{}) end)
      end
    end

    @spec parse(binary(), DiceAST.t() | nil) :: {:ok, dice_full_expr()} | {:error, term()}
    def parse(input, default_dice \\ nil)

    def parse(input, default_dice)
        when is_binary(input) and (is_nil(default_dice) or is_struct(default_dice, DiceAST)) do
      %Ergo.Context{status: status, ast: ast} = Ergo.parse(Parser.full_expr(default_dice), input)

      case status do
        :ok -> {:ok, ast}
        {:error, _} -> status
      end
    end

    @spec parse!(binary(), DiceAST.t() | nil) :: dice_full_expr()
    def parse!(input, default_dice \\ nil) do
      case parse(input, default_dice) do
        {:ok, value} ->
          value

        {:error, reason} ->
          raise ArgumentError,
                "Cannot parse #{inspect(input)} as DiceExpr, reason: #{inspect(reason)}"
      end
    end

    @type inline_res :: {String.t(), String.t(), number()}

    @spec eval(nil) :: {<<>>, <<>>, 0}
    def eval(nil), do: {"", "", 0}

    @spec eval(dice_full_expr()) :: %{
            full_res: [inline_res()],
            full_lit: String.t(),
            formatted_res: String.t()
          }
    def eval(%{type: :full_expr, ast: ast, repeat: repeat} = _expr) do
      eval_full_expr(ast, repeat)
    end

    @spec eval(dice_expr() | dice_term() | dice_cell()) :: inline_res()
    def eval(%{type: :expr, ast: ast} = _expr), do: eval_expr(ast)

    def eval(%{type: :term, ast: ast} = _expr), do: eval_term(ast)

    def eval(%{type: :cell, ast: ast} = _expr), do: eval_cell(ast)

    @spec eval_cell(dice_expr() | number() | DiceAST.t()) :: inline_res()
    defp eval_cell(%{type: :expr} = ast) do
      {lit, exp, res} = eval(ast)
      {"(" <> lit <> ")", "(" <> exp <> ")", res}
    end

    defp eval_cell(ast) when is_number(ast) do
      {"#{ast}", "#{ast}", ast}
    end

    defp eval_cell(ast) when is_struct(ast, DiceAST) do
      extra_p =
        if ast.extra == nil do
          fn _ -> true end
        else
          case ast.opt do
            {:upper_bound, _} -> fn x -> x > ast.extra end
            _ -> fn x -> x < ast.extra end
          end
        end

      rolled =
        1..ast.cnt
        |> Enum.map(fn _ -> roll_dice_until(ast.face, extra_p) end)
        |> Enum.reduce(fn x, acc -> Enum.concat(x, acc) end)

      case ast.opt do
        {:lower_bound, lb} ->
          {"#{ast}", pretty_concat(rolled, Enum.map(rolled, fn x -> x >= lb end)),
           rolled |> Enum.count(fn x -> x >= lb end)}

        {:upper_bound, ub} ->
          {"#{ast}", pretty_concat(rolled, Enum.map(rolled, fn x -> x <= ub end)),
           rolled |> Enum.count(fn x -> x <= ub end)}

        {:high, high} ->
          sorted = Enum.sort(rolled, :desc)

          {"#{ast}", pretty_concat(sorted, Enum.map(1..length(sorted), fn x -> x <= high end)),
           sorted |> Enum.take(high) |> Enum.sum()}

        {:low, low} ->
          sorted = Enum.sort(rolled, :asc)

          {"#{ast}", pretty_concat(sorted, Enum.map(1..length(sorted), fn x -> x <= low end)),
           sorted |> Enum.take(low) |> Enum.sum()}

        _ ->
          {"#{ast}", "{" <> Enum.join(rolled, ",") <> "}", Enum.sum(rolled)}
      end
    end

    @spec roll_dice_until(integer(), (integer() -> boolean())) :: [integer()]
    defp roll_dice_until(face, stop_fn) do
      dice = :rand.uniform(face)

      if stop_fn.(dice) do
        [dice]
      else
        [dice | roll_dice_until(face, stop_fn)]
      end
    end

    @spec pretty_concat([integer()], [boolean()], boolean(), boolean()) :: String.t()
    defp pretty_concat(rolled, selected, first \\ true, prev_selected \\ false) do
      if rolled == [] do
        if prev_selected, do: "]}", else: "}"
      else
        [cr | rr] = rolled
        [cs | rs] = selected
        lbr = if first, do: "{", else: ""
        prev = if prev_selected and !cs, do: "]", else: ""
        comma = if first, do: "", else: ","
        cur = if !prev_selected and cs, do: "[", else: ""
        lbr <> prev <> comma <> cur <> "#{cr}" <> pretty_concat(rr, rs, false, cs)
      end
    end

    @spec eval_op(ops(), inline_res(), inline_res()) :: inline_res()
    defp eval_op(op, opd1, opd2) do
      {lit1, exp1, res1} = opd1
      {lit2, exp2, res2} = opd2

      case op do
        :+ -> {lit1 <> "+" <> lit2, exp1 <> "+" <> exp2, res1 + res2}
        :- -> {lit1 <> "-" <> lit2, exp1 <> "-" <> exp2, res1 - res2}
        :* -> {lit1 <> "*" <> lit2, exp1 <> "*" <> exp2, res1 * res2}
        :/ -> {lit1 <> "/" <> lit2, exp1 <> "/" <> exp2, res1 / res2}
        :nop -> opd1
        _ -> raise ArgumentError, "#{op} is not a legal operator of DiceExpr"
      end
    end

    @spec eval_term({dice_cell(), [dice_term_opds() | dice_nop_opd(), ...]}) :: inline_res()
    defp eval_term({opd1, opds} = _ast) do
      Enum.reduce(opds, eval(opd1), fn next_cell, acc ->
        eval_op(next_cell.op, acc, eval(next_cell.opd))
      end)
    end

    @spec eval_expr({dice_term(), [dice_expr_opds() | dice_nop_opd(), ...]}) :: inline_res()
    defp eval_expr({opd1, opds} = _ast) do
      Enum.reduce(opds, eval(opd1), fn next_term, acc ->
        eval_op(next_term.op, acc, eval(next_term.opd))
      end)
    end

    defp eval_full_expr(ast, repeat) do
      real_repeat = if repeat == nil, do: 1, else: repeat
      full_res = for _ <- 1..real_repeat, do: eval(ast)
      [{lit, _, _} | _] = full_res

      %{
        full_lit: if(repeat == nil, do: lit, else: "#{repeat}#" <> lit),
        full_res: full_res,
        formatted_res:
          full_res
          |> Enum.map_join("\n", fn nl ->
            {lit, exp, res} = nl
            lit <> "=" <> exp <> "=#{res}"
          end)
      }
    end
  end

  @dice_expr_leading [
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "+",
    "-",
    "(",
    "d",
    "a",
    "b",
    "h",
    "l",
    "e"
  ]
  def dice_expr_leading?(maybe_expr) do
    String.starts_with?(maybe_expr, @dice_expr_leading)
  end
end

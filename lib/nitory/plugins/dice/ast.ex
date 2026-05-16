defmodule Nitory.Plugins.Dice.AST do
  @moduledoc """
  Dice expression AST types, parsers, and evaluator.

  Two levels of AST are defined:

  - `DiceAST` — a single dice specification (e.g. `3d6`, `6d20h1`)
  - `DiceExpr` — an arithmetic expression of one or more `DiceAST`
    units, with optional repeat count (e.g. `2d20h1+5`, `3#6d10a8`)
  """
  defmodule DiceAST do
    @moduledoc """
    Single-dice specification struct and parser.

    ## Format

    A complete dice format unit in canonical string form:

        [$count]d[$face][[h$high][l$low][a$lower_bound][b$upper_bound]][e$extra]

    | Field | Key | Meaning |
    |-------|-----|---------|
    | `cnt` | `$count` | Number of dice to roll (positive integer) |
    | `face` | `$face` | Number of faces per die (positive integer, >= 2) |
    | `opt` | `h$high` | Keep the highest $high dice, discard the rest |
    | `opt` | `l$low` | Keep the lowest $low dice, discard the rest |
    | `opt` | `a$lower_bound` | Count successes: each die >= $lower_bound |
    | `opt` | `b$upper_bound` | Count successes: each die <= $upper_bound |
    | `extra` | `e$extra` | Exploding: re-roll and add for each die >= $extra (or <= $extra when combined with b) |

    `opt` accepts at most one of `h`, `l`, `a`, `b`.  All count values must
    be less than `cnt` (for `h`/`l`) or within `[1, face]` (for `a`/`b`).

    ## Serialization

    `to_string/1` converts a `DiceAST` struct back to canonical form:

        iex> DiceAST.new!(cnt: 3, face: 6) |> DiceAST.to_string()
        "3d6"
        iex> DiceAST.new!(cnt: 6, face: 20, opt: {:high, 1}) |> DiceAST.to_string()
        "6d20h1"

    ## Parsing

    `parse/1` and `parse!/1` accept a binary in the canonical format
    and return `{:ok, DiceAST.t()}` or raise `ArgumentError`.  Parsing
    is powered by Ergo (see `DiceAST.Parser`).
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

    @doc """
    Creates a new `DiceAST` struct.

    `k_or_m` is a keyword list or map with keys `:cnt`, `:face`, `:opt`,
    and `:extra`.  When `default_dice` is provided, missing fields are
    filled from it and adjusted for legality (e.g. `cnt` is raised to
    satisfy `:high`/`:low` constraints).

    Returns `{:ok, dice}` or `{:error, reason}`.
    """
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
                  (fn cnt ->
                     case c_dice.opt do
                       {:high, high} -> max(cnt, high + 1)
                       {:low, low} -> max(cnt, low + 1)
                       _ -> cnt
                     end
                   end).(default_dice.cnt)

                %{&1 | cnt: cnt}
              else
                &1
              end)).()
        |> (&(if &1.face == nil do
                c_dice = &1

                face =
                  default_dice.face
                  |> (fn face ->
                        case c_dice.opt do
                          {:lower_bound, lb} -> max(face, lb + 1)
                          {:upper_bound, ub} -> max(face, ub + 1)
                          _ -> face
                        end
                      end).()
                  |> (fn face ->
                        if c_dice.extra != nil, do: max(face, c_dice.extra), else: face
                      end).()

                %{&1 | face: max(2, face)}
              else
                &1
              end)).()

      if legal?(dice) do
        {:ok, dice}
      else
        {:error, "Illegal Dice #{inspect(dice)}."}
      end
    end

    @doc """
    Returns true if all required fields are present and constraints
    (e.g. keep count vs face) are satisfied.
    """
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

    @doc """
    Serializes a `DiceAST` struct back to its canonical string form,
    e.g. `%DiceAST{cnt: 3, face: 6}` → `"3d6"`,
    `%DiceAST{cnt: 6, face: 20, opt: {:high, 1}}` → `"6d20h1"`.
    """
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
      @moduledoc """
      Ergo parser combinators for single dice notation.
      """
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

    @doc """
    Parses a dice notation string (e.g. `"3d6"`, `"6d20b5e1"`) into a
    `DiceAST` struct.  Returns `{:ok, dice}` or `{:error, reason}`.
    """
    @spec parse(binary()) :: {:ok, __MODULE__.t()} | {:error, term()}
    def parse(input) when is_binary(input) do
      %Ergo.Context{status: status, ast: ast} = Ergo.parse(Parser.just_dice(), input)

      case status do
        :ok -> {:ok, ast}
        {:error, _} -> status
      end
    end

    @doc """
    Like `parse/1`, but returns the struct directly or raises
    `ArgumentError`.
    """
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
    @moduledoc """
    Full dice expression parser and evaluator.

    ## Grammar (BNF)

        <full_expr> ::= number # <expr> | <expr>
        <expr>      ::= <term> + <expr> | <term> - <expr> | <term>
        <term>      ::= <cell> * <term> | <cell> / <term> | <cell>
        <cell>      ::= DiceAST | number | ( <expr> )

    | Level | Meaning | Default |
    |-------|---------|---------|
    | `<full_expr>` | Top-level expression, optionally repeated | No `#` → single evaluation |
    | `<expr>` | Addition / subtraction of terms | Empty expression uses the session default dice |
    | `<term>` | Multiplication / division of cells | — |
    | `<cell>` | A single dice unit (`DiceAST`), literal number, or parenthesized sub-expression | Omitted fields filled from session default |

    When the entire expression is omitted, the session's default dice
    (set per chat via `.r` plugin configuration) is evaluated as-is.

    ## Examples

        iex> DiceExpr.parse!("3d6")
        (evaluates 3d6 once)
        iex> DiceExpr.parse!("2#6d20h1")
        (evaluates 6d20h1 twice)
        iex> DiceExpr.parse!("2d10+5*3d6-1")
        (arithmetic of multiple dice units and constants)

    ## Parsing

    `parse/2` (or `parse/1` with implicit default dice) returns
    `{:ok, ast}` or `{:error, reason}`.  `parse!/2` raises on failure.
    Parsing is powered by Ergo (see `DiceExpr.Parser`).
    """
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
      @moduledoc """
      Ergo parser combinators for full dice expressions with optional
      repeat counts and a default-dice fallback.
      """
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

    @doc """
    Parses a full dice expression (arithmetic of one or more `DiceAST`
    units with optional repeat count, e.g. `"3#2d20h1+5"`).

    `default_dice` is used when the expression omits a dice face or count.

    Returns `{:ok, ast}` or `{:error, reason}`.
    """
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

    @doc """
    Like `parse/2`, but returns the AST directly or raises
    `ArgumentError`.
    """
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

  @doc """
  Returns true if `maybe_expr` starts with a character that could begin
  a dice expression (digit, `+`, `-`, `(`, `d`, `a`, `b`, `h`, `l`, `e`).
  """
  def dice_expr_leading?(maybe_expr) do
    String.starts_with?(maybe_expr, @dice_expr_leading)
  end
end
defmodule Nitory.Plugins.Dice do
  use Nitory.Plugin
  alias Nitory.Plugins.Dice.AST.{DiceAST, DiceExpr}

  @impl true
  def handle_call({:roll_dice, expr, default_dice, msg, desc, hidden}, _from, state) do
    res =
      try do
        normalized_expr = if expr == nil, do: DiceAST.to_string(default_dice), else: expr

        with {:ok, ast} <- DiceExpr.parse(normalized_expr, default_dice) do
          %{full_lit: lit, formatted_res: fmt_res} = DiceExpr.eval(ast)
          default_nick = msg.sender.nickname
          user_id = msg.user_id

          nick =
            if state.session_type == :group do
              Nitory.Nickname.get_nick(user_id, state.session_id, default_nick)
            else
              default_nick
            end

          reply = ~s'#{nick} 掷骰 #{lit}#{if desc == nil, do: "", else: " (#{desc})"}:\n#{fmt_res}'

          if hidden do
            GenServer.cast(
              Nitory.ApiHandler,
              {:send_private_msg, %{user_id: user_id, message: reply}}
            )
          else
            {:ok, reply}
          end
        else
          {:error, _} -> {:error, "* 格式错误"}
        end
      rescue
        ArithmeticError -> {:error, "* 算术错误"}
      end

    {:reply, res, state}
  end

  def roll_dice(opts) do
    hidden = Keyword.get(opts, :hidden) == "h"
    default_dice = Keyword.get(opts, :default_dice)
    expr = Keyword.get(opts, :expr)
    desc = Keyword.get(opts, :desc)
    msg = Keyword.get(opts, :msg)
    server = Keyword.fetch!(opts, :server)
    GenServer.call(server, {:roll_dice, expr, default_dice, msg, desc, hidden})
  end

  def roll_dice_abbr(opts) do
    {dice_cnt, opts} = Keyword.pop(opts, :dice_cnt, "")
    {appendix, opts} = Keyword.pop(opts, :appendix, "")

    roll_dice([{:expr, "#{dice_cnt}d#{appendix}"} | opts])
  end

  defcommand(
    display_name: "r",
    cmd_face: {~r'^r(?<hidden>h?)$', [:hidden]},
    hidden: false,
    short_usage: "掷骰指令（默认d20）",
    options: [
      %Nitory.Command.Option{
        name: :expr,
        optional: true,
        predicator: &Nitory.Plugins.Dice.AST.dice_expr_leading?/1
      },
      %Nitory.Command.Option{name: :desc, optional: true}
    ],
    action: {__MODULE__, :roll_dice, [default_dice: DiceAST.parse!("1d20")]},
    usage: """
    掷骰指令（默认d20）
    .r [重复次数#][掷骰表达式] [备注]
    掷骰表达式为掷骰单元及常数组成的算术表达式
    掷骰单元形如 [枚数][d面数][a目标下限][b目标上限][h取高枚数][l取低枚数][e追加目标]
    其中：
        目标下限：每掷出一个大于等于目标下限的骰子计为一个成功数
        目标上限：每掷出一个小于等于目标上限的骰子计为一个成功数
        取高枚数：取最高的若干枚骰子
        取低枚数：取最低的若干枚骰子
        追加目标：每掷出大于等于追加目标的结果则追加一枚骰子，若同时设定了目标上限则转为“小于等于追加目标”，其余不变
    例：
        3d6        掷3枚d6
        2d20h1     掷2枚d20，取其中较高的1枚
        3d20l2     掷2枚d20，取其中最低的2枚
        6d20b5e1   掷6枚d20，每掷出小于等于5的结果就计为一次成功，每掷出小于等于1的结果就追加一枚骰子
        6d10a8e10  掷6枚d10，每掷出大于等于8的结果就计为一次成功，每掷出大于等于10的结果就追加一枚骰子
    需注意：
        目标上限、目标下限、取高枚数与取低枚数最多有一项
        取高枚数与取低枚数需小于等于总枚数
        追加目标必须大于1（需要大于等于追加目标时）或小于面数（需要小于等于追加目标时），否则将无限追加
    另外，.rh 指令用于暗骰，但需要添加好友才能收到信息
    当掷骰较为简单时，可将枚数或运算合并至r上，如：
        .r3  === .r 3d20
        .r+2 === .r 1d20+2
    此功能与暗骰可同时生效，如：
        .rh3 === .rh 3d20
        .rh*2 === .rh 1d20*2
    但不支持括号，如 .r+(2*3)
    """
  )

  defcommand(
    cmd_face:
      {~r'^r(?<hidden>h?)((?<dice_cnt>(\d+))|(?<appendix>([+\-*\/]\d+)))$',
       [:hidden, :dice_cnt, :appendix]},
    hidden: true,
    options: [%Nitory.Command.Option{name: :desc, optional: true}],
    action: {__MODULE__, :roll_dice_abbr, [default_dice: DiceAST.parse!("1d20")]}
  )
end

defmodule Nitory.Plugins.Dice.ASTTest do
  use ExUnit.Case, async: true

  alias Nitory.Plugins.Dice.AST.{DiceAST, DiceExpr}

  describe "DiceAST.new/2" do
    test "creates a basic dice without defaults" do
      assert {:ok, %DiceAST{cnt: 3, face: 6, opt: nil, extra: nil}} =
               DiceAST.new(%{cnt: 3, face: 6})
    end

    test "rejects illegal dice (cnt > face when using high keep)" do
      assert {:error, _} = DiceAST.new(%{cnt: 2, face: 6, opt: {:high, 5}})
    end

    test "accepts dice with high keep when cnt > high" do
      assert {:ok, %DiceAST{cnt: 5, face: 20, opt: {:high, 3}}} =
               DiceAST.new(%{cnt: 5, face: 20, opt: {:high, 3}})
    end

    test "fills defaults from default_dice" do
      default = DiceAST.parse!("1d20")
      assert {:ok, %DiceAST{cnt: 3, face: 20, opt: nil, extra: nil}} =
               DiceAST.new(%{cnt: 3}, default)
    end

    test "fills missing cnt from default" do
      default = DiceAST.parse!("3d6")
      assert {:ok, %DiceAST{cnt: 3, face: 10}} =
               DiceAST.new(%{face: 10}, default)
    end
  end

  describe "DiceAST.parse/1" do
    test "parses simple dice notation" do
      assert {:ok, %DiceAST{cnt: 3, face: 6}} = DiceAST.parse("3d6")
    end

    test "parses dice with high keep" do
      assert {:ok, %DiceAST{cnt: 4, face: 6, opt: {:high, 3}}} = DiceAST.parse("4d6h3")
    end

    test "parses dice with low keep" do
      assert {:ok, %DiceAST{cnt: 4, face: 6, opt: {:low, 3}}} = DiceAST.parse("4d6l3")
    end

    test "parses dice with upper bound" do
      assert {:ok, %DiceAST{cnt: 6, face: 20, opt: {:upper_bound, 5}}} = DiceAST.parse("6d20b5")
    end

    test "parses dice with lower bound" do
      assert {:ok, %DiceAST{cnt: 6, face: 10, opt: {:lower_bound, 8}}} = DiceAST.parse("6d10a8")
    end

    test "parses dice with extra" do
      assert {:ok, %DiceAST{cnt: 6, face: 10, extra: 10}} = DiceAST.parse("6d10e10")
    end

    test "parses combined options" do
      assert {:ok, %DiceAST{cnt: 6, face: 20, opt: {:upper_bound, 5}, extra: 1}} =
               DiceAST.parse("6d20b5e1")
    end

    test "returns error for invalid input" do
      assert {:error, _} = DiceAST.parse("not_a_dice")
    end
  end

  describe "DiceAST.parse!/1" do
    test "returns struct for valid input" do
      assert %DiceAST{cnt: 2, face: 20} = DiceAST.parse!("2d20")
    end

    test "raises ArgumentError for invalid input" do
      assert_raise ArgumentError, fn -> DiceAST.parse!("xyz") end
    end
  end

  describe "DiceAST.to_string/1" do
    test "converts dice to string" do
      dice = DiceAST.parse!("3d6")
      assert "3d6" = DiceAST.to_string(dice)
    end

    test "converts complex dice" do
      dice = DiceAST.parse!("6d20b5e1")
      assert "6d20b5e1" = DiceAST.to_string(dice)
    end
  end

  describe "DiceExpr.parse/2" do
    test "parses a single dice expression" do
      assert {:ok, _ast} = DiceExpr.parse("3d6")
    end

    test "parses arithmetic expression" do
      assert {:ok, _ast} = DiceExpr.parse("3d6+2d8")
    end

    test "parses with repeat count" do
      assert {:ok, _ast} = DiceExpr.parse("3#2d20h1")
    end

    test "returns error for invalid expression" do
      assert {:error, _} = DiceExpr.parse("+++")
    end
  end

  describe "DiceExpr.parse!/2" do
    test "parses valid expression" do
      assert %{type: :full_expr} = DiceExpr.parse!("3d6")
    end

    test "raises ArgumentError for invalid expression" do
      assert_raise ArgumentError, fn -> DiceExpr.parse!("+++") end
    end
  end

  describe "DiceExpr.eval/1" do
    test "evaluates a simple dice expression" do
      {:ok, ast} = DiceExpr.parse("1d6")
      result = DiceExpr.eval(ast)
      assert is_map(result)
      assert Map.has_key?(result, :full_lit)
      assert Map.has_key?(result, :formatted_res)
    end
  end

  describe "dice_expr_leading?/1" do
    test "recognizes dice expressions" do
      assert Nitory.Plugins.Dice.AST.dice_expr_leading?("3d6")
      assert Nitory.Plugins.Dice.AST.dice_expr_leading?("2d20h1")
      assert Nitory.Plugins.Dice.AST.dice_expr_leading?("10")
    end

    test "rejects non-dice expressions" do
      refute Nitory.Plugins.Dice.AST.dice_expr_leading?("foo")
      refute Nitory.Plugins.Dice.AST.dice_expr_leading?(" world")
    end
  end
end
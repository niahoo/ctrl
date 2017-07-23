defmodule CtrlTest do
  use ExUnit.Case, async: true

  import Ctrl

  test "basic with" do
    assert(ctrl do
      {:ok, res} <- ok(41)
      res
    end == 41)
    assert(ctrl do
      res <- four()
      res + 10
    end == 14)
  end

  test "matching with" do
    assert(ctrl do
      _..42 <- 1..42
      :ok
    end == :ok)
    assert(ctrl do
      {:ok, res} <- error()
      res
    end == :error)
    assert(ctrl do
      {:ok, _} = res <- ok(42)
      elem(res, 1)
    end == 42)
  end

  test "with guards" do
    assert(ctrl do
      x when x < 2 <- four()
      :ok
    end == 4)
    assert(ctrl do
      x when x > 2 <- four()
      :ok
    end == :ok)
    assert(ctrl do
      x when x < 2 when x == 4 <- four()
      :ok
    end == :ok)
  end

  test "pin matching with" do
    key = :ok
    assert(ctrl do
      {^key, res} <- ok(42)
      res
    end == 42)
  end

  test "two levels with" do
    result = ctrl do
      {:ok, n1} <- ok(11)
      n2 <- 22
      n1 + n2
    end
    assert result == 33

    result = ctrl do
      n1 <- 11
      {:ok, n2} <- error()
      n1 + n2
    end
    assert result == :error
  end

  test "binding inside with" do
    result =
      ctrl do
        {:ok, n1} <- ok(11)
        n2 = n1 + 10
        {:ok, n3} <- ok(22)
        n2 + n3
      end
    assert result == 43

    result =
      ctrl do
        {:ok, n1} <- ok(11)
        n2 = n1 + 10
        {:ok, n3} <- error()
        n2 + n3
      end
    assert result == :error
  end

  test "does not leak variables to else" do
    state = 1
    result =
      ctrl do
        1 <- state
        state = 2
        :ok <- error()
        state
      else
        (_ -> state)
      end
    assert result == 1
    assert state == 1
  end

  test "errors in with" do
    assert_raise RuntimeError, fn ->
      ctrl do
        {:ok, res} <- oops()
        res
      end
    end

    assert_raise RuntimeError, fn ->
      ctrl do
        {:ok, res} <- ok(42)
        res = res + oops()
        res
      end
    end
  end

  test "else conditions" do
    assert(ctrl do
      {:ok, res} <- four()
      res
    else
      {:error, error} -> error
      res -> res + 1
    end == 5)
    assert(ctrl do
      {:ok, res} <- four()
      res
    else
      res when res == 4 -> res + 1
      res -> res
    end == 5)
    assert(ctrl do
      {:ok, res} <- four()
      res
    else
      _ -> :error
    end == :error)
  end

  test "else conditions with match error" do
    assert_raise WithClauseError, "no with clause matching: :error",  fn ->
      ctrl do
        {:ok, res} <- error()
        res
      else
        {:error, error} -> error
      end
    end
  end

  defp four() do
    4
  end

  defp error() do
    :error
  end

  defp ok(num) do
    {:ok, num}
  end

  defp oops() do
    raise("oops")
  end

  defmodule C do
    def is_int(n) when is_integer(n), do: {:ok, n}
    def is_int(n), do: {:error, {:not_an_integer, n}}

    def intmap(n) when n > 0, do: %{n: n, sq: n * n}
    def intmap(_), do: :below_zero

    def as_list(map) when is_map(map), do: Map.to_list(map)
    def as_list(other), do: {:error, {:bad_map, other}}

    import Ctrl

    def square_with(n) do
      with {:ok, n} <- is_int(n),
           %{sq: sq} = m <- intmap(n),
           list <- as_list(m),
           ^sq = Keyword.fetch!(list, :sq)
      do
        sq2 = {:sq, sq} |> elem(1)
        sq2 + 1 - 1
      else
        other ->
          other = (fn(x) -> {:wrap, x} end).(other)
          {:something_is_wrong, other}
      end
    end

    def square_ctrl(n) do
      ctrl do
        {:ok, n} <- is_int(n)
        %{sq: sq} = m <- intmap(n)
        list <- as_list(m)
        ^sq = Keyword.fetch!(list, :sq)
        sq2 = {:sq, sq} |> elem(1)
        sq2 + 1 - 1
      else
        other ->
          other = (fn(x) -> {:wrap, x} end).(other)
          {:something_is_wrong, other}
      end
    end
  end

  test "compare with with" do
    a = C.square_ctrl(:a)
    b = C.square_with(:a)
    assert a === b

    a = C.square_ctrl(1)
    b = C.square_with(1)
    assert a === b

    a = C.square_ctrl(-1)
    b = C.square_with(-1)
    assert a === b
  end
end

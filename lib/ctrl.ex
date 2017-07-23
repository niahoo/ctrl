defmodule Ctrl do

  @tag_op :|

  # We will simply transform the AST in the form of a regular `with` call.
  defmacro ctrl([{:do, do_block} | else_catch_rescue] = _input) do
    IO.inspect _input
    {main_block, meta} =
      case do_block do
        {:__block__, meta, exprs} when is_list(exprs) ->
          {exprs, meta}
        other ->
          {[other], []}
      end
    {with_clauses, body} = split_body(main_block)
    # handle the tag operator to tag responses
    with_clauses = Enum.map(with_clauses, &wrap_tag/1)
    body = {:__block__, [], body}

    else_catch_rescue =
      case Keyword.get(else_catch_rescue, :else, nil) do
        nil ->
          else_catch_rescue
        elses ->
          elses = elses |> Enum.map(&unwrap_tag/1)
          :lists.keyreplace(:else, 1, else_catch_rescue, {:else, elses})
      end
    with_body = with_clauses ++ [[{:do, body} | else_catch_rescue]]
    ast = {:with, meta, with_body}
    ast |> Macro.to_string |> IO.puts
    ast
  end

  # Ctrl allow the last clause to have an arrow `<-`. But `with` blocks does not
  # accept those inside its `do` block. So we split the body after the last
  # arrow expression, and if there is no body after the last `<-`, we just use
  # the left operand of the last arrow.
  # Caution : the clause will go into the `else` block if it does not match, as
  # any other `<-` clause.
  defp split_body(exprs) do
    # arrow_clauses/_reversed/ can contain other clauses, but ends with the last
    # arrow clause.
    {body_reversed, arrow_clauses_reversed} =
      exprs
      |> :lists.reverse
      |> Enum.split_while(fn(expr) ->  not arrow?(expr) end)
    body_reversed_nonempty =
      case body_reversed do
        # the last clause is an arrow, so we must invent a body for the with
        # clause
        [] ->
          {:<-, _, [left, _]} = hd(arrow_clauses_reversed)
          [left |> cleanup_last_clause]
        non_empty ->
          non_empty
      end
    {
      arrow_clauses_reversed |> :lists.reverse,
      body_reversed_nonempty |> :lists.reverse
    }
  end

  defp arrow?({:<-, _, _}), do: true
  defp arrow?(_), do: false

  defp wrap_tag({:<-, meta, [left, right]} = _clause) do
    {left2, right2} =
      case left do
        {@tag_op, _meta, [tag, inside]} when is_atom(tag) ->
          {{tag, inside}, {tag, right}}
        {:when, when_meta, [{@tag_op, _meta, [tag, inside]}, when_right]} when is_atom(tag) ->
          l = {:when, when_meta, [{tag, inside}, when_right]}
          {l, {tag, right}}
        _normal ->
          {left, right}
      end
    {:<-, meta, [left2, right2]}
  end
  defp wrap_tag(clause) do
    clause
  end

  # If the last clause is set in the body, we must remove tags and guards
  defp cleanup_last_clause({@tag_op, _, [_tag, content]}),
    do: cleanup_last_clause(content)
  defp cleanup_last_clause({:when, _, [content, guards]}),
    do: cleanup_last_clause(content)
  defp cleanup_last_clause(content),
    do: content

  defp unwrap_tag({:->, meta, [left_match, right]}) do
    left =
      case left_match do
        [{@tag_op, _, [tag, value]}] ->
          [{tag, value}]
        [{:when, when_meta, [{@tag_op, _meta, [tag, inside]}, when_right]}] when is_atom(tag) ->
          [{tag, inside}]
        _untagged ->
          left_match
      end
    {:->, meta, [left, right]}
  end
end

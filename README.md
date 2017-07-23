# Ctrl : Simple control monad for Elixir

This library is an experiment to find a better syntax replacement for `with` blocks. It works well, but there is some more work to do : fill a proposal, find a better name, add more tests.

So, if you are fine with Elixir's `with` block, keep using it, it's powerful.

If not, you may want try `ctrl`. At the moment, the macro does just turn your code into a regular `with` block. Any syntax error or matching clause errors will concern a `with` block. This should change in the future.

## Installation

As it is a proposal, I chose not to publish the package in Hex. You can still add it to your dependencies directly from github :

```elixir
def deps do
  [{:ctrl, github: "niahoo/ctrl"}]
end
```

## Features

Here is how the code looks like :

```elixir
import Ctrl

ctrl do
  {:ok, state} <- init()                              # Classic `with` clause
  %{id: id, opts: opts} = state                       # Any expression
  :ok <- register(id)
  :f_repo | {:ok, repo} <- Keyword.fetch(opts, :repo) # Tagged match
  :f_user | {:ok, user} <- Keyword.fetch(opts, :user) # Different tagged match
  {:ok, do_something(id, repo, user)}
else
  {:error, _} = err -> err                            # Errors with info
  :f_repo | :error -> {:error, :no_repo_option}       # Errors on :repo only
  :f_user | :error -> {:error, :user_not_set}         # Errors on :user only
end
```

It works exactly like a `with` block, but with minor differences :

* It does not use commas, so it is easier to write, indent and refactor and, more important, as easy to read.
* The body (`do` block) when transformed into a `with` block will contain all the expressions after the last `<-` clause.
  So this block :
  ```elixir
  ctrl do
    a <- 1 + 3
    b = a + 1
    c <- transform_b(b)
    d = c * 2
    d + 1
  end
  ```
  Is transformed into this :
  ```elixir
  with a <- 1 + 3,
       b = a + 1,
       c <- transform_b(b)
  do
    d = c * 2
    d + 1
  end
  ```
* If the last expression is a `<-` clause, the body will be the left operand.
  So this block :
  ```elixir
  ctrl do
    a <- 1 + 3
  end
  ```
  Is transformed into this :
  ```elixir
  with a <- 1 + 3 do
    a
  end
  ```

## Tag match

A new feature, the tag match, is also available.

A tag match allow for better understanding of what is going wrong.

In the example above, we use `Keyword.fetch/2` which just returns `:error` when the key is not found. So, in the `else` section of a `with` block, you cannot know which line did not match. Using tags, you can write a match in the `else` block that will only match the body clause with the same tag.

In the same manner, when a function returns a single value, and not a `:ok` / `:error` tuple, you can add a tag and a guard clause to control the flow of what is going on.

Note that if you omit a tagged clause in the `else` section, the code will try to match with `{tag, value}` where `tag` is the tag you set in the body and `value` is the value of the right operand of the `<-` clause.

```elixir
import Ctrl

ctrl do
  :bad_int | id when is_integer(n) <- opts[:id]
  :fetch   | data <- Keyword.fetch_user_data(data_source(), id)
  :omit    | {:ok, data} <- :FAIL
  {:ok, stuff}
else
  :bad_int | bad_id -> raise "IDs must be an integer"
  :fetch   | :error -> {:error, :data_unavailable}
  {:error, _} = err -> err
  # Here we forgot to handle the :omit tag, so other will be {:omit, :FAIL}
  other -> {:error, {:unexpected, other}}
end
```




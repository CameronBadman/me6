defmodule Me6.Memory do
  @moduledoc """
  Behaviour for pluggable agent memory backends.
  """

  @callback put(term(), term(), term()) :: :ok
  @callback get(term(), term(), term()) :: term()
  @callback delete(term(), term()) :: :ok
end

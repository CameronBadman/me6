defmodule Me6.Tools.Upcase do
  @moduledoc """
  Example tool that uppercases a string input.
  """

  @behaviour Me6.Tools.Tool

  alias Me6.Tools.Invocation
  alias Me6.Tools.Result

  @impl true
  def run(%Invocation{input: input} = invocation) when is_binary(input) do
    Result.ok(invocation, String.upcase(input))
  end

  def run(%Invocation{input: input} = invocation) do
    Result.error(invocation, {:invalid_input, input})
  end
end

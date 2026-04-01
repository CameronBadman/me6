defmodule Me6.Tools.Upcase do
  @moduledoc """
  Example tool that uppercases a string input.
  """

  @behaviour Me6.Tool

  @impl true
  def run(input, _context) when is_binary(input) do
    {:ok, String.upcase(input)}
  end

  def run(input, _context), do: {:error, {:invalid_input, input}}
end

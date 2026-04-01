defmodule Me6.Tools.UtcNow do
  @moduledoc """
  Example tool that returns the current UTC timestamp.
  """

  @behaviour Me6.Tool

  @impl true
  def run(_input, _context) do
    {:ok, DateTime.utc_now()}
  end
end

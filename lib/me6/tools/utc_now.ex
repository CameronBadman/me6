defmodule Me6.Tools.UtcNow do
  @moduledoc """
  Example tool that returns the current UTC timestamp.
  """

  @behaviour Me6.Tools.Tool

  alias Me6.Tools.Invocation
  alias Me6.Tools.Result

  @impl true
  def run(%Invocation{} = invocation) do
    Result.ok(invocation, DateTime.utc_now())
  end
end

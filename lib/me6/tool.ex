defmodule Me6.Tool do
  @moduledoc """
  Behaviour for synchronous tool execution inside an agent turn.
  """

  alias Me6.ActionContext

  @callback run(term(), ActionContext.t()) :: {:ok, term()} | {:error, term()}

  @spec run(module(), term(), ActionContext.t()) :: {:ok, term()} | {:error, term()}
  def run(tool_module, input, context) do
    tool_module.run(input, context)
  end
end

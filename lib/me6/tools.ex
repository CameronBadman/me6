defmodule Me6.Tools do
  @moduledoc """
  Native tool registry and invocation entrypoint for action runners.
  """

  alias Me6.Tools.Invocation
  alias Me6.Tools.Registry
  alias Me6.Tools.Result

  @spec new(keyword() | map()) :: Registry.t()
  def new(tools \\ %{}) do
    Registry.new(tools)
  end

  @spec invoke(Registry.t(), atom(), term(), Me6.ActionContext.t(), keyword()) :: Result.t()
  def invoke(%Registry{} = registry, tool_name, input, context, opts \\ []) do
    invocation = Invocation.new(tool_name, input, context, opts)

    case Registry.fetch(registry, tool_name) do
      {:ok, tool_module} ->
        execute(tool_module, invocation)

      :error ->
        Result.error(invocation, {:unknown_tool, tool_name})
    end
  end

  defp execute(tool_module, invocation) do
    case tool_module.run(invocation) do
      %Result{} = result ->
        result

      {:ok, output} ->
        Result.ok(invocation, output)

      {:error, reason} ->
        Result.error(invocation, reason)
    end
  rescue
    exception ->
      Result.error(invocation, {:exception, exception, __STACKTRACE__})
  end
end

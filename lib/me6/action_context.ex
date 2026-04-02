defmodule Me6.ActionContext do
  @moduledoc """
  Runtime services exposed to an action runner during a turn.
  """

  alias Me6.Tools
  alias Me6.Tools.Registry
  alias Me6.Tools.Result

  defstruct [:pair_name, :memory, :tools, :delegation_budget]

  @type t :: %__MODULE__{
          pair_name: atom() | nil,
          memory: module(),
          tools: Registry.t(),
          delegation_budget: non_neg_integer()
        }

  @spec remember(t(), term(), term()) :: :ok
  def remember(%__MODULE__{pair_name: pair_name, memory: memory}, key, value) do
    memory.put(scope(pair_name), key, value)
  end

  @spec recall(t(), term(), term()) :: term()
  def recall(%__MODULE__{pair_name: pair_name, memory: memory}, key, default \\ nil) do
    memory.get(scope(pair_name), key, default)
  end

  @spec run_tool(t(), atom(), term(), keyword()) :: Result.t()
  def run_tool(%__MODULE__{tools: tools} = context, tool_name, input, opts \\ []) do
    Tools.invoke(tools, tool_name, input, context, opts)
  end

  defp scope(nil), do: :anonymous
  defp scope(pair_name), do: pair_name
end

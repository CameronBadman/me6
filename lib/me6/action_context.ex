defmodule Me6.ActionContext do
  @moduledoc """
  Runtime services exposed to an action runner during a turn.
  """

  alias Me6.Tools
  alias Me6.Policy
  alias Me6.Tools.Registry
  alias Me6.Tools.Result

  defstruct [:pair_name, :memory, :tools, :delegation_budget, :policy]

  @type t :: %__MODULE__{
          pair_name: atom() | nil,
          memory: module(),
          tools: Registry.t(),
          delegation_budget: non_neg_integer(),
          policy: Policy.t()
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
  def run_tool(%__MODULE__{tools: tools, policy: policy} = context, tool_name, input, opts \\ []) do
    case Policy.allow?(policy || Policy.allow_all(), {:tool, tool_name}) do
      %{allowed?: true} ->
        Tools.invoke(tools, tool_name, input, context, opts)

      %{reason: reason} ->
        invocation = Me6.Tools.Invocation.new(tool_name, input, context, opts)
        Result.error(invocation, reason)
    end
  end

  @spec send_message(t(), Me6.Mailboxes.mailbox_ref(), term(), keyword()) ::
          :ok | {:error, term()}
  def send_message(%__MODULE__{pair_name: pair_name, policy: policy}, to, body, opts \\ []) do
    case Policy.allow?(policy || Policy.allow_all(), {:mailbox_send, to}) do
      %{allowed?: true} ->
        Me6.Mailboxes.deliver(
          from: {:action, pair_name},
          to: to,
          body: body,
          kind: Keyword.get(opts, :kind, :note),
          metadata: Keyword.get(opts, :metadata, %{})
        )

      %{reason: reason} ->
        {:error, reason}
    end
  end

  defp scope(nil), do: :anonymous
  defp scope(pair_name), do: pair_name
end

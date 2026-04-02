defmodule Me6 do
  @moduledoc """
  OTP-first primitives for building persistent `MrMe6` eval/action pairs.
  """

  alias Me6.EvalAgent
  alias Me6.Mailboxes
  alias Me6.Pair

  @type pair_ref :: pid() | atom()

  @doc """
  Starts a persistent eval/action pair under the framework supervisor.
  """
  @spec start_pair(keyword()) :: DynamicSupervisor.on_start_child()
  def start_pair(opts) do
    DynamicSupervisor.start_child(Me6.PairSupervisor, {Pair, opts})
  end

  @doc """
  Runs a task through the pair's persistent eval/action loop.
  """
  @spec run(pair_ref(), String.t(), keyword()) :: map()
  def run(pair, request, opts \\ []) do
    EvalAgent.run(eval_via(pair), request, opts)
  end

  @doc """
  Returns summary state for a persistent pair.
  """
  @spec status(pair_ref()) :: map()
  def status(pair) do
    EvalAgent.status(eval_via(pair))
  end

  @doc """
  Sends a mailbox message to an eval or action component.
  """
  @spec send_message({:eval | :action, atom()}, {:eval | :action, atom()}, term(), keyword()) ::
          :ok
  def send_message(from, to, body, opts \\ []) do
    Mailboxes.deliver(
      from: from,
      to: to,
      body: body,
      kind: Keyword.get(opts, :kind, :note),
      metadata: Keyword.get(opts, :metadata, %{})
    )
  end

  @doc """
  Returns unread mailbox messages for an eval or action component.
  """
  @spec mailbox({:eval | :action, atom()}) :: [Me6.Mailboxes.Message.t()]
  def mailbox(mailbox) do
    Mailboxes.peek(mailbox)
  end

  @doc """
  Returns the pid for a registered pair component.
  """
  @spec whereis(atom(), :eval | :action) :: pid() | nil
  def whereis(name, component) when is_atom(name) and component in [:eval, :action] do
    case Registry.lookup(Me6.AgentRegistry, {component, name}) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end

  defp eval_via(pid) when is_pid(pid), do: pid
  defp eval_via(name) when is_atom(name), do: EvalAgent.via(name)
end

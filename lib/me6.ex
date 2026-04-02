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
    case Keyword.pop(opts, :actor) do
      {nil, remaining_opts} ->
        Mailboxes.deliver(
          from: from,
          to: to,
          body: body,
          kind: Keyword.get(remaining_opts, :kind, :note),
          metadata: Keyword.get(remaining_opts, :metadata, %{})
        )

      {actor_pair, remaining_opts} ->
        Mailboxes.deliver_as(actor_pair,
          from: from,
          to: to,
          body: body,
          kind: Keyword.get(remaining_opts, :kind, :note),
          metadata: Keyword.get(remaining_opts, :metadata, %{})
        )
    end
  end

  @doc """
  Returns unread mailbox messages for an eval or action component.
  """
  @spec mailbox({:eval | :action, atom()}) :: [Me6.Mailboxes.Message.t()]
  def mailbox(mailbox) do
    Mailboxes.peek(mailbox)
  end

  @spec mailbox_as(atom(), {:eval | :action, atom()}) ::
          [Me6.Mailboxes.Message.t()] | {:error, term()}
  def mailbox_as(actor_pair, mailbox) do
    Mailboxes.peek_as(actor_pair, mailbox)
  end

  @doc """
  Stores a value in the mailbox directory tree at the given path.
  """
  @spec directory_put([term()], term()) :: :ok
  def directory_put(path, value) do
    Mailboxes.put_path(path, value)
  end

  @spec directory_put_as(atom(), [term()], term()) :: :ok | {:error, term()}
  def directory_put_as(actor_pair, path, value) do
    Mailboxes.put_path_as(actor_pair, path, value)
  end

  @doc """
  Reads a value from the mailbox directory tree.
  """
  @spec directory_get([term()], term()) :: term()
  def directory_get(path, default \\ nil) do
    Mailboxes.get_path(path, default)
  end

  @spec directory_get_as(atom(), [term()], term()) :: term() | {:error, term()}
  def directory_get_as(actor_pair, path, default \\ nil) do
    Mailboxes.get_path_as(actor_pair, path, default)
  end

  @doc """
  Deletes a value from the mailbox directory tree.
  """
  @spec directory_delete([term()]) :: :ok
  def directory_delete(path) do
    Mailboxes.delete_path(path)
  end

  @spec directory_delete_as(atom(), [term()]) :: :ok | {:error, term()}
  def directory_delete_as(actor_pair, path) do
    Mailboxes.delete_path_as(actor_pair, path)
  end

  @doc """
  Lists child keys under a mailbox directory path.
  """
  @spec directory_list([term()]) :: [term()]
  def directory_list(path \\ []) do
    Mailboxes.list_path(path)
  end

  @spec directory_list_as(atom(), [term()]) :: [term()] | {:error, term()}
  def directory_list_as(actor_pair, path \\ []) do
    Mailboxes.list_path_as(actor_pair, path)
  end

  @doc """
  Returns a subtree from the mailbox directory.
  """
  @spec directory_tree([term()]) :: term()
  def directory_tree(path \\ []) do
    Mailboxes.tree(path)
  end

  @spec directory_tree_as(atom(), [term()]) :: term() | {:error, term()}
  def directory_tree_as(actor_pair, path \\ []) do
    Mailboxes.tree_as(actor_pair, path)
  end

  @doc """
  Stores a value in the global mailbox directory namespace.
  """
  @spec global_put([term()], term()) :: :ok
  def global_put(path, value) do
    Mailboxes.global_put(path, value)
  end

  @spec global_put_as(atom(), [term()], term()) :: :ok | {:error, term()}
  def global_put_as(actor_pair, path, value) do
    Mailboxes.global_put_as(actor_pair, path, value)
  end

  @doc """
  Reads a value from the global mailbox directory namespace.
  """
  @spec global_get([term()], term()) :: term()
  def global_get(path, default \\ nil) do
    Mailboxes.global_get(path, default)
  end

  @spec global_get_as(atom(), [term()], term()) :: term() | {:error, term()}
  def global_get_as(actor_pair, path, default \\ nil) do
    Mailboxes.global_get_as(actor_pair, path, default)
  end

  @doc """
  Deletes a value from the global mailbox directory namespace.
  """
  @spec global_delete([term()]) :: :ok
  def global_delete(path) do
    Mailboxes.global_delete(path)
  end

  @spec global_delete_as(atom(), [term()]) :: :ok | {:error, term()}
  def global_delete_as(actor_pair, path) do
    Mailboxes.global_delete_as(actor_pair, path)
  end

  @doc """
  Lists child keys under the global mailbox directory namespace.
  """
  @spec global_list([term()]) :: [term()]
  def global_list(path \\ []) do
    Mailboxes.global_list(path)
  end

  @spec global_list_as(atom(), [term()]) :: [term()] | {:error, term()}
  def global_list_as(actor_pair, path \\ []) do
    Mailboxes.global_list_as(actor_pair, path)
  end

  @doc """
  Returns a subtree from the global mailbox directory namespace.
  """
  @spec global_tree([term()]) :: term()
  def global_tree(path \\ []) do
    Mailboxes.global_tree(path)
  end

  @spec global_tree_as(atom(), [term()]) :: term() | {:error, term()}
  def global_tree_as(actor_pair, path \\ []) do
    Mailboxes.global_tree_as(actor_pair, path)
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

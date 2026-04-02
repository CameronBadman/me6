defmodule Me6.Mailboxes do
  @moduledoc """
  Mailbox registry and delivery API for agent-to-agent communication.
  """

  alias Me6.Mailboxes.Message
  alias Me6.Mailboxes.Registry

  @type mailbox_ref :: {:eval | :action, atom()}

  @spec register(mailbox_ref(), pid()) :: :ok
  def register(mailbox, owner) do
    Registry.register(mailbox, owner)
  end

  @spec deliver(keyword()) :: :ok
  def deliver(opts) do
    message =
      Message.new(
        Keyword.fetch!(opts, :from),
        Keyword.fetch!(opts, :to),
        Keyword.fetch!(opts, :body),
        kind: Keyword.get(opts, :kind, :note),
        metadata: Keyword.get(opts, :metadata, %{})
      )

    Registry.deliver(message)
  end

  @spec drain(mailbox_ref()) :: [Message.t()]
  def drain(mailbox) do
    Registry.drain(mailbox)
  end

  @spec peek(mailbox_ref()) :: [Message.t()]
  def peek(mailbox) do
    Registry.peek(mailbox)
  end

  @spec unread_count(mailbox_ref()) :: non_neg_integer()
  def unread_count(mailbox) do
    Registry.unread_count(mailbox)
  end

  @spec deliver_as(atom(), keyword()) :: :ok | {:error, term()}
  def deliver_as(actor_pair, opts) do
    to = Keyword.fetch!(opts, :to)

    case fetch_policy(actor_pair, {:mailbox_send, to}) do
      %{allowed?: true} ->
        deliver(opts)

      %{reason: reason} ->
        {:error, reason}
    end
  end

  @spec peek_as(atom(), mailbox_ref()) :: [Message.t()] | {:error, term()}
  def peek_as(actor_pair, mailbox) do
    case fetch_policy(actor_pair, {:mailbox_read, mailbox}) do
      %{allowed?: true} -> peek(mailbox)
      %{reason: reason} -> {:error, reason}
    end
  end

  @spec put_path([term()], term()) :: :ok
  def put_path(path, value) do
    Registry.put_path(path, value)
  end

  @spec put_path_as(atom(), [term()], term()) :: :ok | {:error, term()}
  def put_path_as(actor_pair, path, value) do
    case fetch_policy(actor_pair, {:directory_write, path}) do
      %{allowed?: true} -> put_path(path, value)
      %{reason: reason} -> {:error, reason}
    end
  end

  @spec get_path([term()], term()) :: term()
  def get_path(path, default \\ nil) do
    Registry.get_path(path, default)
  end

  @spec get_path_as(atom(), [term()], term()) :: term() | {:error, term()}
  def get_path_as(actor_pair, path, default \\ nil) do
    case fetch_policy(actor_pair, {:directory_read, path}) do
      %{allowed?: true} -> get_path(path, default)
      %{reason: reason} -> {:error, reason}
    end
  end

  @spec delete_path([term()]) :: :ok
  def delete_path(path) do
    Registry.delete_path(path)
  end

  @spec delete_path_as(atom(), [term()]) :: :ok | {:error, term()}
  def delete_path_as(actor_pair, path) do
    case fetch_policy(actor_pair, {:directory_write, path}) do
      %{allowed?: true} -> delete_path(path)
      %{reason: reason} -> {:error, reason}
    end
  end

  @spec list_path([term()]) :: [term()]
  def list_path(path \\ []) do
    Registry.list_path(path)
  end

  @spec list_path_as(atom(), [term()]) :: [term()] | {:error, term()}
  def list_path_as(actor_pair, path \\ []) do
    case fetch_policy(actor_pair, {:directory_read, path}) do
      %{allowed?: true} -> list_path(path)
      %{reason: reason} -> {:error, reason}
    end
  end

  @spec tree([term()]) :: term()
  def tree(path \\ []) do
    Registry.tree(path)
  end

  @spec tree_as(atom(), [term()]) :: term() | {:error, term()}
  def tree_as(actor_pair, path \\ []) do
    case fetch_policy(actor_pair, {:directory_read, path}) do
      %{allowed?: true} -> tree(path)
      %{reason: reason} -> {:error, reason}
    end
  end

  @spec global_put([term()], term()) :: :ok
  def global_put(path, value) do
    put_path([:global | List.wrap(path)], value)
  end

  @spec global_put_as(atom(), [term()], term()) :: :ok | {:error, term()}
  def global_put_as(actor_pair, path, value) do
    case fetch_policy(actor_pair, {:global_write, List.wrap(path)}) do
      %{allowed?: true} -> global_put(path, value)
      %{reason: reason} -> {:error, reason}
    end
  end

  @spec global_get([term()], term()) :: term()
  def global_get(path, default \\ nil) do
    get_path([:global | List.wrap(path)], default)
  end

  @spec global_get_as(atom(), [term()], term()) :: term() | {:error, term()}
  def global_get_as(actor_pair, path, default \\ nil) do
    case fetch_policy(actor_pair, {:global_read, List.wrap(path)}) do
      %{allowed?: true} -> global_get(path, default)
      %{reason: reason} -> {:error, reason}
    end
  end

  @spec global_delete([term()]) :: :ok
  def global_delete(path) do
    delete_path([:global | List.wrap(path)])
  end

  @spec global_delete_as(atom(), [term()]) :: :ok | {:error, term()}
  def global_delete_as(actor_pair, path) do
    case fetch_policy(actor_pair, {:global_write, List.wrap(path)}) do
      %{allowed?: true} -> global_delete(path)
      %{reason: reason} -> {:error, reason}
    end
  end

  @spec global_list([term()]) :: [term()]
  def global_list(path \\ []) do
    list_path([:global | List.wrap(path)])
  end

  @spec global_list_as(atom(), [term()]) :: [term()] | {:error, term()}
  def global_list_as(actor_pair, path \\ []) do
    case fetch_policy(actor_pair, {:global_read, List.wrap(path)}) do
      %{allowed?: true} -> global_list(path)
      %{reason: reason} -> {:error, reason}
    end
  end

  @spec global_tree([term()]) :: term()
  def global_tree(path \\ []) do
    tree([:global | List.wrap(path)])
  end

  @spec global_tree_as(atom(), [term()]) :: term() | {:error, term()}
  def global_tree_as(actor_pair, path \\ []) do
    case fetch_policy(actor_pair, {:global_read, List.wrap(path)}) do
      %{allowed?: true} -> global_tree(path)
      %{reason: reason} -> {:error, reason}
    end
  end

  defp fetch_policy(actor_pair, capability) do
    case Me6.Policy.Registry.fetch(actor_pair) do
      {:ok, policy} -> Me6.Policy.allow?(policy, capability)
      :error -> Me6.Policy.Decision.deny(elem(capability, 0), elem(capability, 1))
    end
  end
end

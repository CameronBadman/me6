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

  @spec put_path([term()], term()) :: :ok
  def put_path(path, value) do
    Registry.put_path(path, value)
  end

  @spec get_path([term()], term()) :: term()
  def get_path(path, default \\ nil) do
    Registry.get_path(path, default)
  end

  @spec delete_path([term()]) :: :ok
  def delete_path(path) do
    Registry.delete_path(path)
  end

  @spec list_path([term()]) :: [term()]
  def list_path(path \\ []) do
    Registry.list_path(path)
  end

  @spec tree([term()]) :: term()
  def tree(path \\ []) do
    Registry.tree(path)
  end

  @spec global_put([term()], term()) :: :ok
  def global_put(path, value) do
    put_path([:global | List.wrap(path)], value)
  end

  @spec global_get([term()], term()) :: term()
  def global_get(path, default \\ nil) do
    get_path([:global | List.wrap(path)], default)
  end

  @spec global_delete([term()]) :: :ok
  def global_delete(path) do
    delete_path([:global | List.wrap(path)])
  end

  @spec global_list([term()]) :: [term()]
  def global_list(path \\ []) do
    list_path([:global | List.wrap(path)])
  end

  @spec global_tree([term()]) :: term()
  def global_tree(path \\ []) do
    tree([:global | List.wrap(path)])
  end
end

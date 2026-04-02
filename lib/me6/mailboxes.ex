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
end

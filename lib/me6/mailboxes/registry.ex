defmodule Me6.Mailboxes.Registry do
  @moduledoc """
  Central mailbox store used by eval/action pairs.
  """

  use GenServer

  alias Me6.Mailboxes.Message

  defstruct mailboxes: %{}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @spec register(Me6.Mailboxes.mailbox_ref(), pid()) :: :ok
  def register(mailbox, owner) do
    GenServer.call(__MODULE__, {:register, mailbox, owner})
  end

  @spec deliver(Message.t()) :: :ok
  def deliver(%Message{} = message) do
    GenServer.call(__MODULE__, {:deliver, message})
  end

  @spec drain(Me6.Mailboxes.mailbox_ref()) :: [Message.t()]
  def drain(mailbox) do
    GenServer.call(__MODULE__, {:drain, mailbox})
  end

  @spec peek(Me6.Mailboxes.mailbox_ref()) :: [Message.t()]
  def peek(mailbox) do
    GenServer.call(__MODULE__, {:peek, mailbox})
  end

  @spec unread_count(Me6.Mailboxes.mailbox_ref()) :: non_neg_integer()
  def unread_count(mailbox) do
    GenServer.call(__MODULE__, {:unread_count, mailbox})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:register, mailbox, owner}, _from, state) do
    next_state =
      put_in(
        state.mailboxes[mailbox],
        %{owner: owner, messages: mailbox_messages(state, mailbox)}
      )

    {:reply, :ok, next_state}
  end

  @impl true
  def handle_call({:deliver, %Message{} = message}, _from, state) do
    mailbox = mailbox_state(state, message.to)
    messages = mailbox.messages ++ [message]
    next_state = put_in(state.mailboxes[message.to], %{mailbox | messages: messages})
    maybe_notify_owner(mailbox.owner, message)
    {:reply, :ok, next_state}
  end

  @impl true
  def handle_call({:drain, mailbox}, _from, state) do
    mailbox_state = mailbox_state(state, mailbox)
    next_state = put_in(state.mailboxes[mailbox], %{mailbox_state | messages: []})
    {:reply, mailbox_state.messages, next_state}
  end

  @impl true
  def handle_call({:peek, mailbox}, _from, state) do
    {:reply, mailbox_messages(state, mailbox), state}
  end

  @impl true
  def handle_call({:unread_count, mailbox}, _from, state) do
    {:reply, state |> mailbox_messages(mailbox) |> length(), state}
  end

  defp mailbox_messages(state, mailbox) do
    state
    |> mailbox_state(mailbox)
    |> Map.fetch!(:messages)
  end

  defp mailbox_state(state, mailbox) do
    Map.get(state.mailboxes, mailbox, %{owner: nil, messages: []})
  end

  defp maybe_notify_owner(nil, _message), do: :ok

  defp maybe_notify_owner(owner, message) do
    GenServer.cast(owner, {:mailbox_message, message})
  end
end

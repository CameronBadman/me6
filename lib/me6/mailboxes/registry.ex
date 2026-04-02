defmodule Me6.Mailboxes.Registry do
  @moduledoc """
  Central mailbox store used by eval/action pairs.
  """

  use GenServer

  alias Me6.Mailboxes.Message

  defstruct mailboxes: %{}, directory: %{}

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

  @spec put_path([term()], term()) :: :ok
  def put_path(path, value) do
    GenServer.call(__MODULE__, {:put_path, List.wrap(path), value})
  end

  @spec get_path([term()], term()) :: term()
  def get_path(path, default \\ nil) do
    GenServer.call(__MODULE__, {:get_path, List.wrap(path), default})
  end

  @spec delete_path([term()]) :: :ok
  def delete_path(path) do
    GenServer.call(__MODULE__, {:delete_path, List.wrap(path)})
  end

  @spec list_path([term()]) :: [term()]
  def list_path(path \\ []) do
    GenServer.call(__MODULE__, {:list_path, List.wrap(path)})
  end

  @spec tree([term()]) :: term()
  def tree(path \\ []) do
    GenServer.call(__MODULE__, {:tree, List.wrap(path)})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:register, mailbox, owner}, _from, state) do
    directory =
      state.directory
      |> put_nested([:mailboxes | Tuple.to_list(mailbox)], %{owner: owner})
      |> put_nested([:pids, owner], mailbox)
      |> put_nested([:global, :mailboxes | Tuple.to_list(mailbox)], %{owner: owner})
      |> put_nested([:global, :pids, owner], mailbox)

    next_state =
      state
      |> put_in(
        [Access.key(:mailboxes), mailbox],
        %{owner: owner, messages: mailbox_messages(state, mailbox)}
      )
      |> Map.put(:directory, directory)

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

  @impl true
  def handle_call({:put_path, path, value}, _from, state) do
    {:reply, :ok, %{state | directory: put_nested(state.directory, path, value)}}
  end

  @impl true
  def handle_call({:get_path, path, default}, _from, state) do
    {:reply, get_nested(state.directory, path, default), state}
  end

  @impl true
  def handle_call({:delete_path, path}, _from, state) do
    {:reply, :ok, %{state | directory: delete_nested(state.directory, path)}}
  end

  @impl true
  def handle_call({:list_path, path}, _from, state) do
    value = get_nested(state.directory, path, %{})

    reply =
      case value do
        map when is_map(map) -> map |> Map.keys() |> Enum.sort()
        _ -> []
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:tree, path}, _from, state) do
    {:reply, get_nested(state.directory, path, %{}), state}
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

  defp put_nested(_tree, [], value), do: value

  defp put_nested(tree, [key | rest], value) when is_map(tree) do
    current = Map.get(tree, key, %{})
    Map.put(tree, key, put_nested(current, rest, value))
  end

  defp put_nested(_tree, [key | rest], value) do
    %{key => put_nested(%{}, rest, value)}
  end

  defp get_nested(tree, [], _default), do: tree

  defp get_nested(tree, [key | rest], default) when is_map(tree) do
    case Map.fetch(tree, key) do
      {:ok, value} -> get_nested(value, rest, default)
      :error -> default
    end
  end

  defp get_nested(_tree, _path, default), do: default

  defp delete_nested(tree, []), do: tree

  defp delete_nested(tree, [key]) when is_map(tree) do
    Map.delete(tree, key)
  end

  defp delete_nested(tree, [key | rest]) when is_map(tree) do
    case Map.fetch(tree, key) do
      {:ok, child} ->
        next_child = delete_nested(child, rest)

        next_tree =
          cond do
            is_map(next_child) and map_size(next_child) == 0 -> Map.delete(tree, key)
            true -> Map.put(tree, key, next_child)
          end

        next_tree

      :error ->
        tree
    end
  end

  defp delete_nested(tree, _path), do: tree
end

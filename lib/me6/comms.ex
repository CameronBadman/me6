defmodule Me6.Comms do
  @moduledoc """
  Routing helpers built on top of pair lineage and mailbox identities.
  """

  alias Me6.Mailboxes.Message

  @type component :: :eval | :action
  @type mailbox_ref :: {component(), atom()}

  @spec paired_eval(atom()) :: mailbox_ref()
  def paired_eval(pair_name), do: {:eval, pair_name}

  @spec paired_action(atom()) :: mailbox_ref()
  def paired_action(pair_name), do: {:action, pair_name}

  @spec parent(atom()) :: atom() | nil
  def parent(pair_name) do
    Me6.global_get([:pairs, pair_name, :parent])
  end

  @spec children(atom()) :: [atom()]
  def children(pair_name) do
    case Me6.global_get([:pairs, pair_name, :children], %{}) do
      children when is_map(children) -> children |> Map.keys() |> Enum.sort()
      _ -> []
    end
  end

  @spec child(atom(), atom()) :: atom() | nil
  def child(pair_name, child_name) do
    case Me6.global_get([:pairs, pair_name, :children, child_name, :name]) do
      nil -> nil
      name -> name
    end
  end

  @spec to_paired_eval(atom(), term(), keyword()) :: :ok | {:error, term()}
  def to_paired_eval(pair_name, body, opts \\ []) do
    send_from(pair_name, paired_eval(pair_name), body, opts)
  end

  @spec to_paired_action(atom(), term(), keyword()) :: :ok | {:error, term()}
  def to_paired_action(pair_name, body, opts \\ []) do
    send_from(pair_name, paired_action(pair_name), body, opts)
  end

  @spec to_parent_eval(atom(), term(), keyword()) :: :ok | {:error, term()}
  def to_parent_eval(pair_name, body, opts \\ []) do
    case parent(pair_name) do
      nil -> {:error, {:no_parent_pair, pair_name}}
      parent_pair -> send_from(pair_name, {:eval, parent_pair}, body, opts)
    end
  end

  @spec to_parent_action(atom(), term(), keyword()) :: :ok | {:error, term()}
  def to_parent_action(pair_name, body, opts \\ []) do
    case parent(pair_name) do
      nil -> {:error, {:no_parent_pair, pair_name}}
      parent_pair -> send_from(pair_name, {:action, parent_pair}, body, opts)
    end
  end

  @spec to_child_eval(atom(), atom(), term(), keyword()) :: :ok | {:error, term()}
  def to_child_eval(pair_name, child_name, body, opts \\ []) do
    with {:ok, child_pair} <- fetch_child(pair_name, child_name) do
      send_from(pair_name, {:eval, child_pair}, body, opts)
    end
  end

  @spec to_child_action(atom(), atom(), term(), keyword()) :: :ok | {:error, term()}
  def to_child_action(pair_name, child_name, body, opts \\ []) do
    with {:ok, child_pair} <- fetch_child(pair_name, child_name) do
      send_from(pair_name, {:action, child_pair}, body, opts)
    end
  end

  @spec reply(atom(), Message.t(), term(), keyword()) :: :ok | {:error, term()}
  def reply(pair_name, %Message{from: from}, body, opts \\ []) do
    send_from(pair_name, from, body, opts)
  end

  defp send_from(pair_name, to, body, opts) do
    component = Keyword.get(opts, :from_component, :action)

    Me6.send_message(
      {component, pair_name},
      to,
      body,
      actor: pair_name,
      kind: Keyword.get(opts, :kind, :note),
      metadata: Keyword.get(opts, :metadata, %{})
    )
  end

  defp fetch_child(pair_name, child_name) do
    case child(pair_name, child_name) do
      nil -> {:error, {:unknown_child_pair, pair_name, child_name}}
      child_pair -> {:ok, child_pair}
    end
  end
end

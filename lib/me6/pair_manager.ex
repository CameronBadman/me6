defmodule Me6.PairManager do
  @moduledoc """
  Creates top-level and child pairs under the pair supervisor and records lineage.
  """

  use GenServer

  @name __MODULE__

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  @spec start_pair(keyword()) :: DynamicSupervisor.on_start_child()
  def start_pair(opts) do
    GenServer.call(@name, {:start_pair, opts})
  end

  @spec spawn_child_pair(atom(), keyword()) ::
          DynamicSupervisor.on_start_child() | {:error, term()}
  def spawn_child_pair(parent_pair, opts) do
    GenServer.call(@name, {:spawn_child_pair, parent_pair, opts})
  end

  @impl true
  def init(state) do
    :ok = Me6.global_put([:system, :pair_manager, :pid], self())
    {:ok, state}
  end

  @impl true
  def handle_call({:start_pair, opts}, _from, state) do
    {:reply, do_start_pair(opts), state}
  end

  @impl true
  def handle_call({:spawn_child_pair, parent_pair, opts}, _from, state) do
    reply =
      case Me6.Policy.Registry.fetch(parent_pair) do
        {:ok, policy} ->
          case Me6.Policy.allow?(policy, :spawn_child_pair) do
            %{allowed?: true} -> do_spawn_child_pair(parent_pair, opts)
            %{reason: reason} -> {:error, reason}
          end

        :error ->
          {:error, {:unknown_parent_pair, parent_pair}}
      end

    {:reply, reply, state}
  end

  defp do_spawn_child_pair(parent_pair, opts) do
    name = Keyword.fetch!(opts, :name)
    child_policy = Keyword.get(opts, :policy, inherit_policy(parent_pair))

    opts =
      opts
      |> Keyword.put(:policy, child_policy)
      |> Keyword.put_new(:parent_pair, parent_pair)

    case do_start_pair(opts) do
      {:ok, pid} ->
        record_lineage(parent_pair, name, pid)
        {:ok, pid}

      other ->
        other
    end
  end

  defp do_start_pair(opts) do
    case DynamicSupervisor.start_child(Me6.PairSupervisor, {Me6.Pair, opts}) do
      {:ok, pid} = ok ->
        record_pair(opts, pid)
        ok

      other ->
        other
    end
  end

  defp record_pair(opts, pid) do
    name = Keyword.fetch!(opts, :name)
    parent_pair = Keyword.get(opts, :parent_pair)

    :ok = Me6.global_put([:pairs, name, :pid], pid)
    :ok = Me6.global_put([:pairs, name, :parent], parent_pair)

    :ok =
      Me6.global_put([:pairs, name, :children], Me6.global_get([:pairs, name, :children], %{}))
  end

  defp record_lineage(parent_pair, child_pair, child_pid) do
    :ok = Me6.global_put([:pairs, parent_pair, :children, child_pair, :pid], child_pid)
    :ok = Me6.global_put([:pairs, parent_pair, :children, child_pair, :name], child_pair)
  end

  defp inherit_policy(parent_pair) do
    case Me6.Policy.Registry.fetch(parent_pair) do
      {:ok, policy} -> policy
      :error -> Me6.Policy.allow_all()
    end
  end
end

defmodule Me6.Policy.Registry do
  @moduledoc """
  Stores policies for named pairs.
  """

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec register(atom(), Me6.Policy.t()) :: :ok
  def register(pair_name, policy) do
    GenServer.call(__MODULE__, {:register, pair_name, policy})
  end

  @spec fetch(atom()) :: {:ok, Me6.Policy.t()} | :error
  def fetch(pair_name) do
    GenServer.call(__MODULE__, {:fetch, pair_name})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:register, pair_name, policy}, _from, state) do
    {:reply, :ok, Map.put(state, pair_name, policy)}
  end

  @impl true
  def handle_call({:fetch, pair_name}, _from, state) do
    {:reply, Map.fetch(state, pair_name), state}
  end
end

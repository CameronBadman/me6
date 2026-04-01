defmodule Me6.Memory.ETS do
  @moduledoc """
  In-memory ETS-backed memory store keyed by agent scope.
  """

  use GenServer

  @behaviour Me6.Memory

  @table __MODULE__

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    {:ok, state}
  end

  @impl true
  def put(scope, key, value) do
    true = :ets.insert(@table, {{scope, key}, value})
    :ok
  end

  @impl true
  def get(scope, key, default) do
    case :ets.lookup(@table, {scope, key}) do
      [{{^scope, ^key}, value}] -> value
      [] -> default
    end
  end

  @impl true
  def delete(scope, key) do
    true = :ets.delete(@table, {scope, key})
    :ok
  end
end

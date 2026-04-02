defmodule Me6.ActionAgent do
  @moduledoc """
  Long-lived execution side of a `MrMe6` pair.
  """

  use GenServer

  alias Me6.ActionContext
  alias Me6.Tools

  defstruct [:pair_name, :runner, :runner_state, :memory, :tools]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(Keyword.fetch!(opts, :name)))
  end

  @spec run_turn(pid() | {:via, Registry, tuple()}, Me6.EvalBrief.t()) :: Me6.RunResult.t()
  def run_turn(server, brief) do
    GenServer.call(server, {:run_turn, brief}, 30_000)
  end

  @impl true
  def init(opts) do
    runner = Keyword.fetch!(opts, :runner)
    memory = Keyword.get(opts, :memory, Me6.Memory.ETS)
    tools = Keyword.get(opts, :tools, %{})
    runner_opts = Keyword.get(opts, :runner_opts, [])
    {:ok, runner_state} = runner.init(runner_opts)

    {:ok,
     %__MODULE__{
       pair_name: Keyword.get(opts, :pair_name),
       runner: runner,
       runner_state: runner_state,
       memory: memory,
       tools: Tools.new(tools)
     }}
  end

  @impl true
  def handle_call({:run_turn, brief}, _from, state) do
    context = %ActionContext{
      pair_name: state.pair_name,
      memory: state.memory,
      tools: state.tools,
      delegation_budget: brief.delegation_budget
    }

    {:ok, result, runner_state} = state.runner.run_turn(brief, context, state.runner_state)
    {:reply, result, %{state | runner_state: runner_state}}
  end

  def via(name), do: via_tuple(name)

  defp via_tuple(name), do: {:via, Registry, {Me6.AgentRegistry, {:action, name}}}
end

defmodule Me6.Pair do
  @moduledoc """
  Supervisor that owns exactly one long-lived eval/action pair for a task.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    runner = Keyword.fetch!(opts, :runner)
    runner_opts = Keyword.get(opts, :runner_opts, [])
    memory = Keyword.get(opts, :memory, Me6.Memory.ETS)
    tools = Keyword.get(opts, :tools, %{})
    budget = Keyword.get(opts, :budget, [])
    policy = Keyword.get(opts, :policy, Me6.Policy.allow_all())

    :ok = Me6.Policy.Registry.register(name, policy)

    children = [
      {Me6.ActionAgent,
       name: name,
       pair_name: name,
       runner: runner,
       runner_opts: runner_opts,
       memory: memory,
       tools: tools,
       policy: policy},
      {Me6.EvalAgent, name: name, pair_name: name, action_name: name, budget: budget}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end

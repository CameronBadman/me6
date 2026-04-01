defmodule Me6.EvalAgent do
  @moduledoc """
  Long-lived control side of a `MrMe6` pair.
  """

  use GenServer

  alias Me6.ActionAgent
  alias Me6.Budget
  alias Me6.EvalBrief
  alias Me6.RunResult
  alias Me6.TaskContract

  defstruct [:pair_name, :action_name, :budget, current_task: nil]

  @type task_state :: %{
          contract: TaskContract.t(),
          attempt: non_neg_integer(),
          corrections: [String.t()],
          history: [RunResult.t()],
          status: atom()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(Keyword.fetch!(opts, :name)))
  end

  @spec run(pid() | {:via, Registry, tuple()}, String.t(), keyword()) :: map()
  def run(server, request, opts \\ []) do
    GenServer.call(server, {:run, request, opts}, 30_000)
  end

  @spec status(pid() | {:via, Registry, tuple()}) :: map()
  def status(server) do
    GenServer.call(server, :status)
  end

  @impl true
  def init(opts) do
    {:ok,
     %__MODULE__{
       pair_name: Keyword.get(opts, :pair_name),
       action_name: Keyword.fetch!(opts, :action_name),
       budget: Budget.new(Keyword.get(opts, :budget, []))
     }}
  end

  @impl true
  def handle_call({:run, request, opts}, _from, state) do
    task = %{
      contract: TaskContract.new(request, opts),
      attempt: 0,
      corrections: [],
      history: [],
      status: :running
    }

    {reply, next_state} = execute_loop(task, state)
    {:reply, reply, next_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    summary =
      case state.current_task do
        nil ->
          %{status: :idle}

        task ->
          %{
            status: task.status,
            attempt: task.attempt,
            intent: task.contract.intent,
            corrections: Enum.reverse(task.corrections)
          }
      end

    {:reply, summary, state}
  end

  def via(name), do: via_tuple(name)

  defp execute_loop(task, state) do
    state = %{state | current_task: task}

    cond do
      task.attempt > state.budget.max_retries ->
        finalize(task, state, :failed, "retry budget exhausted", nil)

      task.attempt >= state.budget.max_turns ->
        finalize(task, state, :failed, "turn budget exhausted", nil)

      true ->
        next_attempt = task.attempt + 1

        brief = %EvalBrief{
          intent: task.contract.intent,
          success_criteria: task.contract.success_criteria,
          attempt: next_attempt,
          constraints: task.contract.constraints,
          required_evidence: task.contract.required_evidence,
          correction_notes: Enum.reverse(task.corrections),
          delegation_budget: remaining_child_budget(state)
        }

        result = ActionAgent.run_turn(ActionAgent.via(state.action_name), brief)

        case assess(result) do
          :complete ->
            task =
              task
              |> append_result(next_attempt, result)
              |> Map.put(:status, :complete)

            finalize(task, state, :complete, nil, result)

          {:retry, issue} ->
            task =
              task
              |> append_result(next_attempt, result)
              |> Map.update!(:corrections, &[issue | &1])

            execute_loop(task, state)

          {:failed, reason} ->
            task =
              task
              |> append_result(next_attempt, result)
              |> Map.put(:status, :failed)

            finalize(task, state, :failed, reason, result)
        end
    end
  end

  defp append_result(task, attempt, result) do
    task
    |> Map.put(:attempt, attempt)
    |> Map.update!(:history, &[result | &1])
  end

  defp assess(%RunResult{
         status: :completed,
         completion_claim: true,
         open_issues: [],
         delegation_requests: requests
       })
       when requests == [] do
    :complete
  end

  defp assess(%RunResult{
         status: :completed,
         completion_claim: true,
         delegation_requests: requests
       })
       when requests != [] do
    {:retry, "Resolve or justify outstanding delegation requests before claiming completion"}
  end

  defp assess(%RunResult{status: :incomplete, open_issues: [issue | _]}), do: {:retry, issue}
  defp assess(%RunResult{status: :blocked, open_issues: [issue | _]}), do: {:retry, issue}
  defp assess(%RunResult{status: :failed, errors: [error | _]}), do: {:failed, inspect(error)}
  defp assess(%RunResult{open_issues: [issue | _]}), do: {:retry, issue}

  defp assess(_result),
    do: {:retry, "Return explicit completion evidence or a concrete open issue"}

  defp finalize(task, state, status, reason, result) do
    reply = %{
      status: status,
      pair: state.pair_name,
      intent: task.contract.intent,
      attempts: task.attempt,
      output: result && result.output,
      open_issues: (result && result.open_issues) || [],
      errors: (result && result.errors) || [],
      reason: reason,
      history: Enum.reverse(task.history)
    }

    task = %{task | status: status}
    {reply, %{state | current_task: task}}
  end

  defp remaining_child_budget(state), do: state.budget.max_child_pairs

  defp via_tuple(name), do: {:via, Registry, {Me6.AgentRegistry, {:eval, name}}}
end

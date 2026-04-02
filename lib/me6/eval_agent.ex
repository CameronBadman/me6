defmodule Me6.EvalAgent do
  @moduledoc """
  Long-lived control side of a `MrMe6` pair.
  """

  use GenServer

  alias Me6.ActionAgent
  alias Me6.Budget
  alias Me6.EvalBrief
  alias Me6.Mailboxes
  alias Me6.Mailboxes.Message
  alias Me6.RunResult
  alias Me6.TaskContract

  defstruct [:pair_name, :action_name, :budget, current_task: nil, pending_messages: []]

  @type task_state :: %{
          contract: TaskContract.t(),
          attempt: non_neg_integer(),
          corrections: [String.t()],
          history: [RunResult.t()],
          status: atom(),
          messages: [Message.t()]
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
    name = Keyword.fetch!(opts, :name)
    :ok = Mailboxes.register({:eval, name}, self())

    {:ok,
     %__MODULE__{
       pair_name: Keyword.get(opts, :pair_name),
       action_name: Keyword.fetch!(opts, :action_name),
       budget: Budget.new(Keyword.get(opts, :budget, [])),
       pending_messages: []
     }}
  end

  @impl true
  def handle_call({:run, request, opts}, _from, state) do
    task = %{
      contract: TaskContract.new(request, opts),
      attempt: 0,
      corrections: [],
      history: [],
      status: :running,
      messages: []
    }

    {reply, next_state} =
      state
      |> apply_pending_messages(task)
      |> execute_loop()

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
            corrections: Enum.reverse(task.corrections),
            unread_messages: Mailboxes.unread_count({:eval, state.pair_name}),
            applied_messages: Enum.map(task.messages, &summarize_message/1)
          }
      end

    {:reply, summary, state}
  end

  @impl true
  def handle_cast({:mailbox_message, %Message{}}, state) do
    {:noreply, state}
  end

  def via(name), do: via_tuple(name)

  defp execute_loop({task, state}) do
    {task, state} = sync_mailbox(task, state)
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

            execute_loop({task, state})

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

  defp apply_pending_messages(state, task) do
    {apply_messages(task, Enum.reverse(state.pending_messages)), %{state | pending_messages: []}}
  end

  defp sync_mailbox(task, state) do
    mailbox_messages = Mailboxes.drain({:eval, state.pair_name})

    apply_pending_messages(
      %{state | pending_messages: mailbox_messages ++ state.pending_messages},
      task
    )
  end

  defp apply_messages(task, []), do: task

  defp apply_messages(task, messages) do
    Enum.reduce(messages, task, &apply_message/2)
  end

  defp apply_message(%Message{} = message, task) do
    task
    |> Map.update!(:messages, &[message | &1])
    |> customize_from_message(message)
  end

  defp customize_from_message(task, %Message{kind: :constraint, body: body}) do
    update_in(task.contract.constraints, &append_unique(&1, body))
  end

  defp customize_from_message(task, %Message{kind: :success_criterion, body: body}) do
    update_in(task.contract.success_criteria, &append_unique(&1, body))
  end

  defp customize_from_message(task, %Message{kind: :required_evidence, body: body}) do
    update_in(task.contract.required_evidence, &append_unique(&1, body))
  end

  defp customize_from_message(task, %Message{kind: :intent, body: body}) when is_binary(body) do
    put_in(task.contract.intent, body)
  end

  defp customize_from_message(task, %Message{body: body}) do
    Map.update!(task, :corrections, &[to_string(body) | &1])
  end

  defp append_unique(list, value) do
    if value in list, do: list, else: list ++ [value]
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

  defp summarize_message(%Message{from: from, kind: kind, body: body}) do
    %{from: from, kind: kind, body: body}
  end

  defp via_tuple(name), do: {:via, Registry, {Me6.AgentRegistry, {:eval, name}}}
end

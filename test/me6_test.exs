defmodule Me6Test do
  use ExUnit.Case, async: true

  alias Me6.RunResult
  alias Me6.Tools.Registry
  alias Me6.Tools.Result, as: ToolResult

  test "keeps a one to one eval/action pair alive across repeated runs" do
    name = unique_name()

    assert {:ok, _pid} =
             Me6.start_pair(
               name: name,
               runner: Me6.Runners.DemoRunner,
               tools: %{utc_now: Me6.Tools.UtcNow}
             )

    eval_pid = Me6.whereis(name, :eval)
    action_pid = Me6.whereis(name, :action)

    result = Me6.run(name, "finish the task")
    assert result.status == :complete

    assert eval_pid == Me6.whereis(name, :eval)
    assert action_pid == Me6.whereis(name, :action)
  end

  test "eval retries with the same action process until the task is complete" do
    name = unique_name()

    assert {:ok, _pid} = Me6.start_pair(name: name, runner: Me6.Runners.DemoRunner)

    result =
      Me6.run(name, "ship the answer",
        success_criteria: ["Return a direct answer"],
        constraints: ["Do not leave the output empty"]
      )

    assert result.status == :complete
    assert result.attempts == 2
    assert result.output == "done on turn 2"
    assert [%RunResult{status: :incomplete}, %RunResult{status: :completed}] = result.history
  end

  test "native tool registry invokes registered tools with structured results" do
    registry =
      %{}
      |> Registry.new()
      |> Registry.register(:upcase, Me6.Tools.Upcase)

    context = %Me6.ActionContext{
      pair_name: :tool_test,
      memory: Me6.Memory.ETS,
      tools: registry,
      delegation_budget: 0
    }

    assert %ToolResult{status: :ok, output: "HELLO"} =
             Me6.ActionContext.run_tool(context, :upcase, "hello", metadata: %{source: :test})

    assert %ToolResult{status: :error, error: {:unknown_tool, :missing}} =
             Me6.ActionContext.run_tool(context, :missing, "hello")
  end

  test "communicate tool delivers mailbox messages" do
    registry =
      %{}
      |> Registry.new()
      |> Registry.register(:communicate, Me6.Tools.Communicate)

    context = %Me6.ActionContext{
      pair_name: :sender_pair,
      memory: Me6.Memory.ETS,
      tools: registry,
      delegation_budget: 0
    }

    assert %ToolResult{status: :ok, output: %{delivered: true, to: {:eval, :receiver_pair}}} =
             Me6.ActionContext.run_tool(context, :communicate, %{
               to: {:eval, :receiver_pair},
               body: "Tighten the acceptance criteria",
               kind: :constraint
             })

    assert [
             %Me6.Mailboxes.Message{
               from: {:action, :sender_pair},
               to: {:eval, :receiver_pair},
               kind: :constraint,
               body: "Tighten the acceptance criteria"
             }
           ] = Me6.mailbox({:eval, :receiver_pair})
  end

  test "eval customizes later loop turns from mailbox messages" do
    name = unique_name()

    assert {:ok, _pid} = Me6.start_pair(name: name, runner: Me6.Runners.MailAwareRunner)

    sender =
      Task.async(fn ->
        Process.sleep(10)

        Me6.send_message(
          {:action, :external_parent},
          {:eval, name},
          "Need a written migration note",
          kind: :required_evidence
        )
      end)

    result = Me6.run(name, "finish the task", success_criteria: ["Ship the task"])
    Task.await(sender)

    assert result.status == :complete
    assert result.attempts == 2
    assert "Need a written migration note" in result.output.required_evidence
  end

  test "mailbox directory stores nested values and supports exploration" do
    pid = self()

    assert :ok = Me6.directory_put([:agents, :planner, :children, :worker_1, :pid], pid)
    assert :ok = Me6.directory_put([:agents, :planner, :children, :worker_1, :status], "running")
    assert :ok = Me6.directory_put([:agents, :planner, :children, :worker_2, :status], "idle")

    assert Me6.directory_get([:agents, :planner, :children, :worker_1, :pid]) == pid
    assert Me6.directory_get([:agents, :planner, :children, :worker_1, :status]) == "running"
    assert Me6.directory_list([:agents, :planner, :children]) == [:worker_1, :worker_2]

    assert %{
             worker_1: %{pid: ^pid, status: "running"},
             worker_2: %{status: "idle"}
           } = Me6.directory_tree([:agents, :planner, :children])

    assert :ok = Me6.directory_delete([:agents, :planner, :children, :worker_2])
    assert Me6.directory_list([:agents, :planner, :children]) == [:worker_1]
  end

  test "global directory stores shared named entries" do
    pid = self()

    assert :ok = Me6.global_put([:workers, :indexer, :pid], pid)
    assert :ok = Me6.global_put([:workers, :indexer, :role], "search")

    assert Me6.global_get([:workers, :indexer, :pid]) == pid
    assert Me6.global_list([:workers]) == [:indexer]
    assert %{indexer: %{pid: ^pid, role: "search"}} = Me6.global_tree([:workers])

    assert :ok = Me6.global_delete([:workers, :indexer, :role])
    assert Me6.global_get([:workers, :indexer, :role], :missing) == :missing
  end

  test "mailbox registration exposes owner pids in the directory tree" do
    name = unique_name()

    assert {:ok, _pid} = Me6.start_pair(name: name, runner: Me6.Runners.DemoRunner)

    eval_pid = Me6.whereis(name, :eval)
    action_pid = Me6.whereis(name, :action)

    assert %{owner: ^eval_pid} = Me6.directory_get([:mailboxes, :eval, name])
    assert %{owner: ^action_pid} = Me6.directory_get([:mailboxes, :action, name])
    assert Me6.directory_get([:pids, eval_pid]) == {:eval, name}
    assert Me6.directory_get([:pids, action_pid]) == {:action, name}
    assert %{owner: ^eval_pid} = Me6.global_get([:mailboxes, :eval, name])
    assert %{owner: ^action_pid} = Me6.global_get([:mailboxes, :action, name])
    assert Me6.global_get([:pids, eval_pid]) == {:eval, name}
    assert Me6.global_get([:pids, action_pid]) == {:action, name}
  end

  test "fails cleanly when the eval budget is exhausted" do
    name = unique_name()

    assert {:ok, _pid} =
             Me6.start_pair(
               name: name,
               runner: Me6.Runners.StuckRunner,
               budget: [max_retries: 1, max_turns: 2]
             )

    result = Me6.run(name, "unstick yourself")

    assert result.status == :failed
    assert result.reason == "retry budget exhausted"
    assert result.attempts == 2
  end

  defp unique_name do
    :"pair_#{System.unique_integer([:positive])}"
  end
end

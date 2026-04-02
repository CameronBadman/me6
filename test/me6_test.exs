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

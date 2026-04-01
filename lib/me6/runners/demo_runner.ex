defmodule Me6.Runners.DemoRunner do
  @moduledoc """
  Deterministic demo runner that shows the eval/action repair loop.
  """

  @behaviour Me6.ActionRunner

  alias Me6.ActionContext
  alias Me6.EvalBrief
  alias Me6.RunResult

  @impl true
  def init(_opts) do
    {:ok, %{turns: 0}}
  end

  @impl true
  def run_turn(%EvalBrief{} = brief, %ActionContext{} = context, state) do
    state = %{state | turns: state.turns + 1}

    result =
      cond do
        brief.attempt == 1 ->
          %RunResult{
            status: :incomplete,
            output: nil,
            observations: ["Initial execution was too vague"],
            open_issues: ["Produce a direct answer that explicitly satisfies the request"],
            completion_claim: false
          }

        true ->
          :ok = ActionContext.remember(context, :last_output, "done on turn #{brief.attempt}")

          %RunResult{
            status: :completed,
            output: "done on turn #{brief.attempt}",
            observations: ["Applied eval correction notes"],
            completion_claim: true
          }
      end

    {:ok, result, state}
  end
end

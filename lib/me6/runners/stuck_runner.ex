defmodule Me6.Runners.StuckRunner do
  @moduledoc """
  Deterministic runner that never resolves its open issue.
  """

  @behaviour Me6.ActionRunner

  alias Me6.ActionContext
  alias Me6.EvalBrief
  alias Me6.RunResult

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def run_turn(%EvalBrief{}, %ActionContext{}, state) do
    result = %RunResult{
      status: :incomplete,
      output: nil,
      open_issues: ["Still blocked on the same problem"],
      completion_claim: false
    }

    {:ok, result, state}
  end
end

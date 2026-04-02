defmodule Me6.Runners.MailAwareRunner do
  @moduledoc """
  Runner used in tests to prove eval loop customization from mailbox input.
  """

  @behaviour Me6.ActionRunner

  alias Me6.ActionContext
  alias Me6.EvalBrief
  alias Me6.RunResult

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def run_turn(%EvalBrief{attempt: 1}, %ActionContext{}, state) do
    Process.sleep(50)

    result = %RunResult{
      status: :incomplete,
      output: nil,
      open_issues: ["Need additional direction from eval"],
      completion_claim: false
    }

    {:ok, result, state}
  end

  def run_turn(%EvalBrief{} = brief, %ActionContext{}, state) do
    result = %RunResult{
      status: :completed,
      output: %{
        correction_notes: brief.correction_notes,
        constraints: brief.constraints,
        success_criteria: brief.success_criteria,
        required_evidence: brief.required_evidence
      },
      completion_claim: true
    }

    {:ok, result, state}
  end
end

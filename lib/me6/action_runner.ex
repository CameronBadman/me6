defmodule Me6.ActionRunner do
  @moduledoc """
  Behaviour implemented by the execution backend used by a paired action agent.
  """

  alias Me6.ActionContext
  alias Me6.EvalBrief
  alias Me6.RunResult

  @callback init(keyword()) :: {:ok, term()}
  @callback run_turn(EvalBrief.t(), ActionContext.t(), term()) ::
              {:ok, RunResult.t(), term()}
end

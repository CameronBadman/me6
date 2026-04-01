defmodule Me6.EvalBrief do
  @moduledoc """
  Instruction packet the eval side sends to its paired action side for one turn.
  """

  @enforce_keys [:intent, :success_criteria, :attempt]
  defstruct [
    :intent,
    :success_criteria,
    :attempt,
    constraints: [],
    required_evidence: [],
    correction_notes: [],
    delegation_budget: 0
  ]

  @type t :: %__MODULE__{
          intent: String.t(),
          success_criteria: [String.t()],
          attempt: pos_integer(),
          constraints: [String.t()],
          required_evidence: [String.t()],
          correction_notes: [String.t()],
          delegation_budget: non_neg_integer()
        }
end

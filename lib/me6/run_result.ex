defmodule Me6.RunResult do
  @moduledoc """
  Result returned by the action side after one execution turn.
  """

  @enforce_keys [:status]
  defstruct [
    :status,
    :output,
    artifacts: %{},
    observations: [],
    errors: [],
    open_issues: [],
    completion_claim: false,
    delegation_requests: []
  ]

  @type status :: :completed | :incomplete | :blocked | :failed

  @type t :: %__MODULE__{
          status: status(),
          output: term(),
          artifacts: map(),
          observations: [term()],
          errors: [term()],
          open_issues: [String.t()],
          completion_claim: boolean(),
          delegation_requests: [term()]
        }
end

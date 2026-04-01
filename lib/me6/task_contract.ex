defmodule Me6.TaskContract do
  @moduledoc """
  Normalized representation of user intent and how completion is judged.
  """

  @enforce_keys [:intent, :success_criteria]
  defstruct [
    :intent,
    success_criteria: [],
    constraints: [],
    required_evidence: []
  ]

  @type t :: %__MODULE__{
          intent: String.t(),
          success_criteria: [String.t()],
          constraints: [String.t()],
          required_evidence: [String.t()]
        }

  @spec new(String.t(), keyword()) :: t()
  def new(request, opts \\ []) do
    intent =
      request
      |> to_string()
      |> String.trim()

    success_criteria =
      opts
      |> Keyword.get(:success_criteria, default_success_criteria(intent))
      |> List.wrap()
      |> Enum.map(&to_string/1)

    %__MODULE__{
      intent: intent,
      success_criteria: success_criteria,
      constraints: Keyword.get(opts, :constraints, []),
      required_evidence: Keyword.get(opts, :required_evidence, [])
    }
  end

  defp default_success_criteria(intent) do
    ["Deliver a result that satisfies: #{intent}"]
  end
end

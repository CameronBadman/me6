defmodule Me6.DelegationRequest do
  @moduledoc """
  Request from an action side asking its eval side for child-pair budget.
  """

  @enforce_keys [:intent]
  defstruct [:intent, requested_child_pairs: 1, reason: nil]

  @type t :: %__MODULE__{
          intent: String.t(),
          requested_child_pairs: pos_integer(),
          reason: String.t() | nil
        }
end

defmodule Me6.Budget do
  @moduledoc """
  Limits enforced by eval before another action turn or delegation is allowed.
  """

  defstruct max_retries: 3, max_turns: 4, max_child_pairs: 0

  @type t :: %__MODULE__{
          max_retries: non_neg_integer(),
          max_turns: pos_integer(),
          max_child_pairs: non_neg_integer()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      max_retries: Keyword.get(opts, :max_retries, 3),
      max_turns: Keyword.get(opts, :max_turns, 4),
      max_child_pairs: Keyword.get(opts, :max_child_pairs, 0)
    }
  end
end

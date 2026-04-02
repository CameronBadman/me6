defmodule Me6.Tools.Invocation do
  @moduledoc """
  Structured tool call emitted by the action side.
  """

  @enforce_keys [:id, :tool, :input, :context, :started_at]
  defstruct [:id, :tool, :input, :context, :started_at, metadata: %{}]

  @type t :: %__MODULE__{
          id: reference(),
          tool: atom(),
          input: term(),
          context: Me6.ActionContext.t(),
          started_at: DateTime.t(),
          metadata: map()
        }

  @spec new(atom(), term(), Me6.ActionContext.t(), keyword()) :: t()
  def new(tool, input, context, opts \\ []) do
    %__MODULE__{
      id: make_ref(),
      tool: tool,
      input: input,
      context: context,
      started_at: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
end

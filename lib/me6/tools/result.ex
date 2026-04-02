defmodule Me6.Tools.Result do
  @moduledoc """
  Structured result for a tool invocation.
  """

  alias Me6.Tools.Invocation

  @enforce_keys [:invocation_id, :tool, :status, :finished_at]
  defstruct [
    :invocation_id,
    :tool,
    :status,
    :output,
    :error,
    :finished_at,
    metadata: %{}
  ]

  @type status :: :ok | :error

  @type t :: %__MODULE__{
          invocation_id: reference(),
          tool: atom(),
          status: status(),
          output: term(),
          error: term(),
          finished_at: DateTime.t(),
          metadata: map()
        }

  @spec ok(Invocation.t(), term(), keyword()) :: t()
  def ok(%Invocation{} = invocation, output, opts \\ []) do
    %__MODULE__{
      invocation_id: invocation.id,
      tool: invocation.tool,
      status: :ok,
      output: output,
      finished_at: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @spec error(Invocation.t(), term(), keyword()) :: t()
  def error(%Invocation{} = invocation, reason, opts \\ []) do
    %__MODULE__{
      invocation_id: invocation.id,
      tool: invocation.tool,
      status: :error,
      error: reason,
      finished_at: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
end

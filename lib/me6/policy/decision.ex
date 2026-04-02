defmodule Me6.Policy.Decision do
  @moduledoc """
  Result of evaluating a capability against a policy.
  """

  defstruct [:allowed?, :capability, :target, :reason]

  @type t :: %__MODULE__{
          allowed?: boolean(),
          capability: atom(),
          target: term(),
          reason: term()
        }

  @spec allow(atom(), term()) :: t()
  def allow(capability, target) do
    %__MODULE__{allowed?: true, capability: capability, target: target, reason: :allowed}
  end

  @spec deny(atom(), term()) :: t()
  def deny(capability, target) do
    %__MODULE__{
      allowed?: false,
      capability: capability,
      target: target,
      reason: {:permission_denied, capability, target}
    }
  end
end

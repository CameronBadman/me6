defmodule Me6.Tools.Registry do
  @moduledoc """
  Immutable registry of named tools available to an action runner.
  """

  @enforce_keys [:tools]
  defstruct [:tools]

  @type t :: %__MODULE__{
          tools: %{optional(atom()) => module()}
        }

  @spec new(keyword() | map()) :: t()
  def new(tools \\ %{}) do
    %__MODULE__{tools: tools |> Enum.into(%{})}
  end

  @spec register(t(), atom(), module()) :: t()
  def register(%__MODULE__{tools: tools} = registry, name, tool_module)
      when is_atom(name) and is_atom(tool_module) do
    %{registry | tools: Map.put(tools, name, tool_module)}
  end

  @spec fetch(t(), atom()) :: {:ok, module()} | :error
  def fetch(%__MODULE__{tools: tools}, name) do
    Map.fetch(tools, name)
  end

  @spec list(t()) :: [atom()]
  def list(%__MODULE__{tools: tools}) do
    tools
    |> Map.keys()
    |> Enum.sort()
  end
end

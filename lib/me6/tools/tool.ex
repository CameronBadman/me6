defmodule Me6.Tools.Tool do
  @moduledoc """
  Behaviour implemented by native tools registered in a `Me6.Tools.Registry`.
  """

  alias Me6.Tools.Invocation
  alias Me6.Tools.Result

  @callback run(Invocation.t()) :: Result.t() | {:ok, term()} | {:error, term()}
end

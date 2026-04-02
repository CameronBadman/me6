defmodule Me6.Tools.Communicate do
  @moduledoc """
  Sends a structured mailbox message to another agent mailbox.
  """

  @behaviour Me6.Tools.Tool

  alias Me6.Mailboxes
  alias Me6.Tools.Invocation
  alias Me6.Tools.Result

  @impl true
  def run(%Invocation{input: input, context: context} = invocation) when is_map(input) do
    with {:ok, to} <- fetch_mailbox(input, :to),
         {:ok, body} <- fetch_body(input),
         :ok <-
           Mailboxes.deliver(
             from: {:action, context.pair_name},
             to: to,
             body: body,
             kind: Map.get(input, :kind, :note),
             metadata: Map.get(input, :metadata, %{})
           ) do
      Result.ok(invocation, %{delivered: true, to: to, kind: Map.get(input, :kind, :note)})
    else
      {:error, reason} ->
        Result.error(invocation, reason)
    end
  end

  def run(%Invocation{} = invocation) do
    Result.error(invocation, :invalid_input)
  end

  defp fetch_mailbox(input, key) do
    case Map.fetch(input, key) do
      {:ok, {component, name}} when component in [:eval, :action] and is_atom(name) ->
        {:ok, {component, name}}

      _ ->
        {:error, {:invalid_mailbox, key}}
    end
  end

  defp fetch_body(input) do
    case Map.fetch(input, :body) do
      {:ok, body} -> {:ok, body}
      :error -> {:error, :missing_body}
    end
  end
end

defmodule Me6.Mailboxes.Message do
  @moduledoc """
  Structured message delivered through agent mailboxes.
  """

  @enforce_keys [:id, :from, :to, :body, :kind, :created_at]
  defstruct [:id, :from, :to, :body, :kind, :created_at, metadata: %{}]

  @type mailbox_ref :: {:eval | :action, atom()}

  @type t :: %__MODULE__{
          id: reference(),
          from: mailbox_ref(),
          to: mailbox_ref(),
          body: term(),
          kind: atom(),
          created_at: DateTime.t(),
          metadata: map()
        }

  @spec new(mailbox_ref(), mailbox_ref(), term(), keyword()) :: t()
  def new(from, to, body, opts \\ []) do
    %__MODULE__{
      id: make_ref(),
      from: from,
      to: to,
      body: body,
      kind: Keyword.get(opts, :kind, :note),
      created_at: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
end

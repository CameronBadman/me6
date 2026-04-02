defmodule Me6.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Me6.AgentRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Me6.PairSupervisor},
      {Me6.Policy.Registry, []},
      {Me6.Mailboxes.Registry, []},
      {Me6.Memory.ETS, []}
    ]

    opts = [strategy: :one_for_one, name: Me6.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

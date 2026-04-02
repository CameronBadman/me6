defmodule Me6.Policy do
  @moduledoc """
  Capability policy for tools, mailboxes, and directory access.
  """

  alias Me6.Policy.Decision

  defstruct tools: :all,
            mailbox_send: :all,
            mailbox_read: :all,
            directory_read: :all,
            directory_write: :all,
            global_read: :all,
            global_write: :all,
            spawn_child_pair: true

  @type path :: [term()]
  @type mailbox_ref :: {:eval | :action, atom()}
  @type prefix_list :: :all | [path()]

  @type t :: %__MODULE__{
          tools: :all | MapSet.t(atom()),
          mailbox_send: :all | [mailbox_ref()],
          mailbox_read: :all | [mailbox_ref()],
          directory_read: prefix_list(),
          directory_write: prefix_list(),
          global_read: prefix_list(),
          global_write: prefix_list(),
          spawn_child_pair: boolean()
        }

  @spec allow_all() :: t()
  def allow_all do
    %__MODULE__{}
  end

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      tools: normalize_tools(Keyword.get(opts, :tools, :all)),
      mailbox_send: normalize_mailboxes(Keyword.get(opts, :mailbox_send, :all)),
      mailbox_read: normalize_mailboxes(Keyword.get(opts, :mailbox_read, :all)),
      directory_read: normalize_prefixes(Keyword.get(opts, :directory_read, :all)),
      directory_write: normalize_prefixes(Keyword.get(opts, :directory_write, :all)),
      global_read: normalize_prefixes(Keyword.get(opts, :global_read, :all)),
      global_write: normalize_prefixes(Keyword.get(opts, :global_write, :all)),
      spawn_child_pair: Keyword.get(opts, :spawn_child_pair, true)
    }
  end

  @spec allow?(
          t(),
          {:tool, atom()}
          | {:mailbox_send, mailbox_ref()}
          | {:mailbox_read, mailbox_ref()}
          | {:directory_read, path()}
          | {:directory_write, path()}
          | {:global_read, path()}
          | {:global_write, path()}
          | :spawn_child_pair
        ) :: Decision.t()
  def allow?(%__MODULE__{} = policy, {:tool, tool_name}) do
    decide(tool_allowed?(policy.tools, tool_name), :tool, tool_name)
  end

  def allow?(%__MODULE__{} = policy, {:mailbox_send, mailbox}) do
    decide(mailbox_allowed?(policy.mailbox_send, mailbox), :mailbox_send, mailbox)
  end

  def allow?(%__MODULE__{} = policy, {:mailbox_read, mailbox}) do
    decide(mailbox_allowed?(policy.mailbox_read, mailbox), :mailbox_read, mailbox)
  end

  def allow?(%__MODULE__{} = policy, {:directory_read, path}) do
    decide(path_allowed?(policy.directory_read, path), :directory_read, path)
  end

  def allow?(%__MODULE__{} = policy, {:directory_write, path}) do
    decide(path_allowed?(policy.directory_write, path), :directory_write, path)
  end

  def allow?(%__MODULE__{} = policy, {:global_read, path}) do
    decide(path_allowed?(policy.global_read, path), :global_read, path)
  end

  def allow?(%__MODULE__{} = policy, {:global_write, path}) do
    decide(path_allowed?(policy.global_write, path), :global_write, path)
  end

  def allow?(%__MODULE__{} = policy, :spawn_child_pair) do
    decide(policy.spawn_child_pair, :spawn_child_pair, :pair_manager)
  end

  defp decide(true, capability, target), do: Decision.allow(capability, target)
  defp decide(false, capability, target), do: Decision.deny(capability, target)

  defp normalize_tools(:all), do: :all
  defp normalize_tools(tools), do: tools |> List.wrap() |> MapSet.new()

  defp normalize_mailboxes(:all), do: :all
  defp normalize_mailboxes(mailboxes), do: List.wrap(mailboxes)

  defp normalize_prefixes(:all), do: :all
  defp normalize_prefixes(prefixes), do: prefixes |> List.wrap() |> Enum.map(&List.wrap/1)

  defp tool_allowed?(:all, _tool_name), do: true
  defp tool_allowed?(tools, tool_name), do: MapSet.member?(tools, tool_name)

  defp mailbox_allowed?(:all, _mailbox), do: true
  defp mailbox_allowed?(mailboxes, mailbox), do: mailbox in mailboxes

  defp path_allowed?(:all, _path), do: true

  defp path_allowed?(prefixes, path) do
    Enum.any?(prefixes, &prefix_match?(&1, path))
  end

  defp prefix_match?(prefix, path) do
    Enum.take(path, length(prefix)) == prefix
  end
end

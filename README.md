# me6

`me6` is a small Elixir/OTP-first AI agent framework starter built around persistent `MrMe6` pairs.

The runtime model is strict:

- one long-lived eval process
- one long-lived action process
- exactly one eval/action relationship per pair
- action turns end, processes do not, unless the task completes or the pair dies

## Architecture

Core runtime modules:

- `Me6` exposes the public API for starting pairs and running tasks.
- `Me6.Pair` supervises one eval process and one action process.
- `Me6.EvalAgent` owns task intent, success criteria, retries, and completion checks.
- `Me6.ActionAgent` owns execution turns and keeps runner state alive across turns.
- `Me6.TaskContract` normalizes intent and success criteria.
- `Me6.EvalBrief` is the per-turn execution brief emitted by eval.
- `Me6.RunResult` is the per-turn result returned by action.
- `Me6.Budget` caps retries, turns, and child-pair delegation.
- `Me6.ActionRunner` is the behaviour for the execution backend.
- `Me6.ActionContext` gives runners access to memory and tools.
- `Me6.Tools` is the native tool invocation entrypoint.
- `Me6.Tools.Registry` stores named tool modules.
- `Me6.Tools.Invocation` and `Me6.Tools.Result` provide structured tool calls.
- `Me6.Tools.Tool` defines the tool behaviour.
- `Me6.Mailboxes` provides registry-backed mailboxes for agent communication.
- `Me6.Mailboxes.Message` is the structured mailbox envelope.
- `Me6.Tools.Communicate` lets agents send mailbox messages through the native tool layer.
- `Me6.Policy` defines pair capabilities for tools, mailboxes, and directory paths.
- `Me6.Policy.Registry` stores per-pair policies.
- `Me6.PairManager` creates top-level and child pairs and records lineage.
- `Me6.Comms` provides routing helpers for paired, parent, child, and reply messaging.
- `Me6.Memory` defines the memory backend contract.
- `Me6.Memory.ETS` is the default in-memory backend.

OTP topology:

- `Registry` tracks named eval and action processes.
- `DynamicSupervisor` owns persistent pairs.
- each pair supervisor owns exactly two children: its eval and action side
- `Me6.Memory.ETS` owns the ETS table used for default memory.

## Loop Design

Each task runs through a stable pair:

1. eval receives a request
2. eval derives or accepts success criteria
3. eval sends one bounded brief to its paired action process
4. action performs one execution turn
5. action returns evidence, issues, and completion claim
6. eval either completes the task or emits a correction brief and loops again

This keeps the responsibilities clean:

- eval is the control plane
- action is the execution plane
- delegation budget originates from eval, not action
- mailbox messages can modify later eval turns without replacing the pair processes

## Communication

Each eval/action side has a mailbox identity:

- `{:eval, pair_name}`
- `{:action, pair_name}`

Messages are stored in a central mailbox registry and can be delivered either through the public API or the native communication tool. The eval side drains its mailbox between turns and folds messages into the active task loop:

- `:constraint` appends a new constraint
- `:success_criterion` appends a new success criterion
- `:required_evidence` appends required evidence
- `:intent` rewrites the current intent
- other message kinds become correction notes

The mailbox registry also exposes a recursive directory tree for named discovery. Agents can store nested values, including pids, and explore them by path. The framework reserves a shared `:global` root for globally visible entries such as registered mailbox owners.

## Permissions

Pairs may be started with an explicit `Me6.Policy`. Policies are enforced at the runtime boundaries:

- tool invocation
- mailbox sends
- actor-scoped mailbox reads
- actor-scoped directory reads and writes
- actor-scoped global namespace reads and writes

The current model is capability-based and path-prefix based. If no policy is provided for a pair, the runtime defaults to allow-all for compatibility. Restricted pairs can narrow:

- allowed tool names
- allowed mailbox recipients
- allowed mailbox readers
- readable and writable directory prefixes
- readable and writable `:global` prefixes
- whether the pair may spawn child pairs

## Child Pairs

Pairs are now created through `Me6.PairManager`. The manager pid is published under:

- `[:global, :system, :pair_manager, :pid]`

Child pairs can be spawned on behalf of a parent pair with `Me6.spawn_child_pair/2`. The manager:

- checks the parent pair policy for spawn permission
- starts the new pair under the pair supervisor
- records parent/child lineage under `[:global, :pairs, ...]`
- keeps child pairs discoverable in the global namespace

## Routing

`Me6.Comms` builds on the global pair tree and mailbox layer so callers do not need to construct mailbox addresses manually. The helper layer currently supports:

- paired eval/action routing
- parent eval/action routing
- child eval/action routing
- reply routing from an inbound mailbox message
- parent and child lookup helpers

## Example

Run the tests:

```bash
mix test
```

Try the demo pair in `iex`:

```elixir
iex -S mix
{:ok, _pid} = Me6.start_pair(name: :demo, runner: Me6.Runners.DemoRunner)
Me6.run(:demo, "finish the task")
Me6.status(:demo)
```

The bundled `Me6.Runners.DemoRunner` intentionally fails its first turn so you can see eval re-brief the same persistent action process and complete on the second turn.

## Next steps

The next useful additions are:

1. Add an LLM-backed `ActionRunner`.
2. Add event logging for every eval/action turn.
3. Add real child-pair delegation and budget accounting.
4. Add durable task state and resumability.

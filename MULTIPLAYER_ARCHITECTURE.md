# ArtifactRun Multiplayer Foundation

## Decision

ArtifactRun uses a server-authoritative simulation. A listen server is the
first playable target; the same simulation boundary must also support a later
headless dedicated server.

Clients own presentation and submit gameplay intent. The server owns movement
results, AI, pathfinding, combat, damage, health, spawning, resources, mission
state, and victory/failure decisions.

Offline play follows the host command path. This keeps single-player behavior
from becoming a separate implementation that quietly bypasses multiplayer
rules.

## Command flow

1. A client selects locally and submits a command containing stable entity IDs
   and intent such as a destination or stance.
2. The server identifies the RPC sender, rejects stale or excessive commands,
   resolves the IDs, and verifies that the sender owns those entities.
3. The server applies the command to the authoritative simulation.
4. Replicated state communicates the result. Clients never report final
   positions, damage, cooldown completion, inventory totals, or AI decisions.

Reliable packets are appropriate for discrete orders, spawning, inventory,
and mission events. Frequently changing transforms and velocities should use
ordered unreliable state updates once interpolation is implemented.

## Entity identity and ownership

Every gameplay Entity has a session-stable `network_entity_id` and an
`owning_peer_id`. Network messages refer to IDs, never Node references,
instance IDs, RIDs, or scene-tree paths. The server allocates runtime IDs and
must include them in replicated spawn data.

Ownership grants permission to request commands; it does not grant simulation
authority. AI, projectiles, structures, artifacts, and mission systems remain
server-owned.

## Replication phases

### Current foundation

- ENet host/client session lifecycle.
- One validated client-to-server command gateway.
- Stable entity registry and peer ownership fields.
- Authority gates for simulation code.
- Offline play routed through the same command API.

### Next multiplayer slice

- Server-only `MultiplayerSpawner` paths for dynamic entities and projectiles.
- `MultiplayerSynchronizer` configurations for coarse entity state.
- Client interpolation for position and facing.
- Join snapshot containing entities, health, teams, mission clock, and world
  state.
- Player join/leave ownership assignment and a two-process localhost test.
- Replace the current single active-formation state with per-order or per-squad
  formation state before two players can command formations concurrently.

### Later hardening

- Command-specific validation and cooldown/rate limits.
- Interest management using synchronizer visibility.
- Client prediction only where latency proves it necessary.
- Reconnection, migration policy, authentication, and dedicated-server export.

## Rules for new gameplay systems

- Put authoritative mutations behind commands or server-owned simulation.
- Give persistent/replicated objects stable IDs.
- Keep visual effects derivable from replicated state or explicit events.
- Do not serialize Node references, Resources, instance IDs, or RIDs.
- Make timers and random outcomes server-owned.
- Test every feature in offline authority mode first, then in a host/client
  process pair before treating it as multiplayer-ready.

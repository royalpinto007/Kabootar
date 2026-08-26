# Architecture

Kabootar is a **delay-tolerant network (DTN)** messenger. This document explains
the routing protocol, the layering, and the design decisions behind them.

## The problem

A normal messenger assumes a path to a server exists. Kabootar assumes it does
not. What it assumes instead is weaker but often true: **some people are
physically near you, at least sometimes.** The job is to turn intermittent,
short-range, phone-to-phone contact into reliable 1:1 delivery.

That is the textbook definition of a delay-tolerant network, and the classic
solution is **epidemic routing**: flood a message to everyone you meet, let each
of them carry and re-flood it, and rely on the message eventually reaching the
destination through some chain of carriers. The cost of naive flooding is
infinite duplication; the fix is **idempotent de-duplication by message id**,
plus hop/age/size caps.

## Layering

```
UI  ──▶  ChatService  ──▶  MeshEngine        (pure Dart, this doc's focus)
                        ├─▶  SeenStore  ]
                        ├─▶  MeshOutbound ]   ports: interfaces the engine
                        └─▶  MeshDelegate ]   depends on, nothing concrete
```

The engine depends only on **ports** - narrow interfaces (`MeshOutbound`,
`SeenStore`, `MeshDelegate`) plus an injected clock and id generator. It never
imports Flutter, the transport plugin, or SQLite. Consequences:

- The whole routing brain is unit-tested with in-memory fakes, in plain Dart, no
  device required (`tool/engine_check.dart`, `test/mesh_engine_test.dart`).
- The transport is swappable. Today it is `flutter_nearby_connections`; a raw-BLE
  implementation (to break the cross-platform wall) would not touch the engine.

## The wire unit: `Envelope`

Everything on the wire is one tiny JSON object. It is deliberately
self-describing so any node can make every routing decision as a pure function
of these fields, with no shared state:

| field | meaning |
|-------|---------|
| `id`  | globally-unique id. **The de-dup key.** Stable across every hop. |
| `k`   | kind: `hello`, `msg`, `ack`, `read`, `retract`, `invite`, `media`, or `chunk`. |
| `f`   | originator app id. |
| `t`   | recipient app id (empty for a broadcast `hello`). |
| `b`   | payload: chat text or sealed ciphertext (`msg`), the referenced id (`ack` / `read` / `retract`), or a manifest / chunk (`media` / `chunk`). |
| `ts`  | originator send time; drives age-based pruning. |
| `ttl` | remaining relay hops; decremented per relay, bounds flood radius. |
| `n`   | display name (only on `hello`). |
| `e2`  | set when `b` is a sealed ciphertext rather than plaintext. |
| `sg`  | sender's Ed25519 signature over the routing fields + body, so a recipient can prove who sent it. |

Addresses are **stable app ids**, minted once per install and never changed -
deliberately decoupled from the transport's per-session device id, which churns
on every reconnect. The mapping between the two is learned from `hello`.

## The six rules

Every received envelope runs the same pipeline (`MeshEngine.onEnvelopeReceived`):

1. **De-dup.** If the id has been seen before, drop it. This is what makes
   epidemic flooding safe: a message can arrive by many paths, but is only ever
   acted on once. The seen-set is **persisted**, so a reboot cannot forget and
   re-flood.
2. **Learn (`hello`).** A `hello` is link-local: it teaches us a peer's app id
   and name (building the contact list) and is never relayed.
3. **Deliver.** If `t == me` and it is a `msg`: persist it, surface it, and emit
   an `ack` addressed back to the sender.
4. **Receipt.** If `t == me` and it is an `ack`: the referenced message we sent
   is now delivered.
5. **Relay / carry.** If `t != me` and `ttl > 0`: decrement TTL, add to the
   carry-cache, and re-flood to all peers. The message now rides this device.
6. **Cap.** TTL, max-age, and max-cache-size bound the carry-cache. Additionally,
   any `ack` a carrier sees lets it **stop carrying** the message that ack
   acknowledges - delivered mail should not keep circulating.

### Store-and-forward across time

Rules 5 and 6 give carry. The other half is **flush-on-connect**: when a new
peer link comes up, a node hands its entire carry-cache to that peer (who
de-dups whatever it already holds). This is the moment a message stranded on a
courier finally moves the last hop:

```
t0   Alice → Relay:  "hi Bob"        Relay caches it (Bob not in range)
t1   Alice leaves.   Relay carries "hi Bob" around
t2   Relay ↔ Bob link up → Relay flushes cache → Bob delivers, emits ack
t3   Relay ↔ Alice link up → ack flushed back → Alice sees "delivered"
```

No node ever needed to be online at the same time as the other two.

### At-least-once, made exactly-once at the edges

Flooding is at-least-once by nature. Exactly-once *effects* come from de-dup on
the id at two points: the recipient delivers a given id only once, and the
sender's message row is keyed by that same id, so a duplicate `ack` is
idempotent. Message id == envelope id is what ties a delivery receipt back to
the exact row it completes.

## Encryption

Routing is oblivious to payload secrecy: a carrier relays `b` without ever
reading it. Confidentiality rides on top, in `MessageCipher` over `AppKeys`:

- **1:1 chats.** Each install holds an X25519 key pair (agreement) and an Ed25519
  key pair (signing). Peers learn each other's public bundles from `hello`
  (trust-on-first-use), derive a shared secret via ECDH, and seal each message
  with AES-GCM; the `sg` signature authenticates the sender. A per-chat safety
  code lets two people verify keys in person.
- **Private groups.** A shared symmetric key is generated by the creator and
  handed out through per-member encrypted `invite`s; messages are sealed with it,
  so only members can read them.
- **Open channels** are public broadcasts joined by code, so they stay plaintext
  by design.

Media travels the same way: the file is sealed, then chunked, so relays only
carry ciphertext. The honest limit is **no forward secrecy yet** - keys are
long-lived, so a future ratchet is the next step (see the roadmap).

## Delivery status

Only states the app can actually observe are represented - it never claims a
status it cannot prove:

| status | means | shown as |
|--------|-------|----------|
| `sending` | queued into the mesh, no peer yet | clock |
| `sent` | handed to at least one peer | single tick |
| `delivered` | end-to-end `ack` came back | grey double tick |
| `read` | the recipient's `read` envelope came back, proving they opened and saw it | blue double tick |
| `failed` | aged out of the carry-cache undelivered | error glyph |

## Bounds and why they exist

A DTN node stores and retransmits data on behalf of strangers, so every resource
needs a ceiling (`MeshConfig`):

- `ttl` (default 8) - hop budget; bounds how far a flood spreads.
- `maxCacheSize` (default 500) - carried-envelope ceiling; oldest evicted first.
- `maxAgeMs` (default 24h) - a carried envelope past this age is dropped.
- `seenRetentionMs` (default 48h) - de-dup records live comfortably longer than
  `maxAgeMs`, so an envelope can never outlive the memory of having seen it.

`MeshEngine.housekeeping()` enforces the age-based bounds on a timer.

## Data model (SQLite)

- `messages` - `id` (= wire id), `peer_id`, `body`, `direction`, `status`, `ts`,
  plus media columns (`media_kind`, `media_name`, `media_mime`, `media_path`,
  `media_bytes`, `media_status`, `thumb`) for image and file attachments.
- `contacts` - `app_id`, `name`, `last_seen`, `pub_bundle` (the peer's public
  keys, learned from `hello`, that enable end-to-end encryption).
- `channels` / `group_members` - broadcast channels and private-group rosters;
  a private group also stores its shared symmetric key.
- `conv_meta` - per-conversation flags (archived, hidden, blocked, unread).
- `media_chunks` - reassembly buffer for in-flight media transfers.
- `seen` - `id`, `ts`. The persisted de-dup set.

On launch, `ChatService` reloads still-undelivered outgoing messages from
`messages` and re-injects them into the engine (`resumeOutbound`), because the
carry-cache itself is in-memory. De-dup makes the resume safe.

## Testing strategy

- **`tool/engine_check.dart`** - a dependency-free harness with a simulated
  network (`Node`s wired by a fake radio, a hand-driven clock, and a message
  pump). Runs under the bare Dart SDK; doubles as a CI smoke check where Flutter
  is not installed. Asserts 32 invariants.
- **`test/`** - the same scenarios as idiomatic `flutter test` suites, sharing
  an in-memory network simulator in `test/support/`.

Because the engine is pure, these tests exercise the real routing code - not a
model of it.

## Known limitations

See the README's "Honest constraints". The headline is the **cross-platform
wall**: Android and iOS expose different peer-to-peer radios, so v1 meshes within
an OS family but not across it. Breaking that wall means a raw-BLE transport,
which the port-based design isolates to a single swappable layer.

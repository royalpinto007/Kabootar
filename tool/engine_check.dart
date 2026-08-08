// This is a standalone dev script, not part of the app: it prints to stdout and
// imports lib/ by relative path so it can run under the bare Dart SDK (no pub).
// ignore_for_file: avoid_print, avoid_relative_lib_imports

// A dependency-free, runnable proof that the mesh engine routes correctly.
//
// It stands up an in-memory network of [MeshEngine]s wired together by a fake
// transport, then drives real scenarios: direct delivery, de-dup, multi-hop
// relay through an uninvolved node, store-and-forward across time (recipient
// offline then back), end-to-end acks, TTL expiry, and cache bounds.
//
// Because the engine and models are framework-free, this runs under the plain
// Dart SDK with zero packages:  `dart run tool/engine_check.dart`
//
// It is also the CI smoke check for environments without Flutter installed.

import 'dart:async';

import '../lib/core/mesh/envelope.dart';
import '../lib/core/mesh/mesh_config.dart';
import '../lib/core/mesh/mesh_engine.dart';
import '../lib/core/mesh/mesh_ports.dart';

// ---------------------------------------------------------------------------
// Tiny test harness (no package:test dependency)
// ---------------------------------------------------------------------------

int _passed = 0;
int _failed = 0;

void check(String name, bool ok, {String? detail}) {
  if (ok) {
    _passed++;
    print('  ✓ $name');
  } else {
    _failed++;
    print('  ✗ $name${detail == null ? '' : '  ($detail)'}');
  }
}

void section(String title) => print('\n── $title');

// ---------------------------------------------------------------------------
// In-memory fakes for the ports
// ---------------------------------------------------------------------------

class InMemorySeen implements SeenStore {
  final Map<String, int> _seen = <String, int>{};

  @override
  Future<bool> hasSeen(String id) async => _seen.containsKey(id);

  @override
  Future<void> markSeen(String id, int ts) async => _seen[id] = ts;

  @override
  Future<void> prune(int olderThanTs) async =>
      _seen.removeWhere((_, int ts) => ts < olderThanTs);

  int get size => _seen.length;
}

class CollectingDelegate implements MeshDelegate {
  final List<Envelope> delivered = <Envelope>[];
  final List<String> acked = <String>[];
  final Map<String, String> contacts = <String, String>{};
  final List<MeshEvent> events = <MeshEvent>[];

  @override
  Future<void> onMessageDelivered(Envelope message) async =>
      delivered.add(message);

  final List<String> read = <String>[];

  @override
  Future<void> onAckReceived(String messageId, int ts) async =>
      acked.add(messageId);

  @override
  Future<void> onReadReceived(String messageId, int ts) async =>
      read.add(messageId);

  final List<String> retracted = <String>[];

  @override
  Future<void> onRetractReceived(String messageId) async =>
      retracted.add(messageId);

  final List<Envelope> invites = <Envelope>[];

  @override
  Future<void> onInviteReceived(Envelope invite) async => invites.add(invite);

  final List<Envelope> media = <Envelope>[];
  final List<Envelope> chunks = <Envelope>[];

  @override
  Future<void> onMediaReceived(Envelope manifest) async => media.add(manifest);

  @override
  Future<void> onChunkReceived(Envelope chunk) async => chunks.add(chunk);

  @override
  Future<void> onHelloReceived(String appId, String name, String keys) async =>
      contacts[appId] = name;

  @override
  void onMeshEvent(MeshEvent event) => events.add(event);

  int countOf(MeshEventType t) =>
      events.where((MeshEvent e) => e.type == t).length;
}

/// A fake radio: an engine's outbound calls land in the network's queue, which
/// only delivers to nodes that are currently linked to the sender.
class Node {
  Node(this.id, this.network, {MeshConfig config = MeshConfig.defaults}) {
    delegate = CollectingDelegate();
    seen = InMemorySeen();
    engine = MeshEngine(
      myId: id,
      outbound: _Outbound(this),
      seen: seen,
      delegate: delegate,
      clock: () => network.clock,
      newId: network.nextId,
      config: config,
    );
  }

  final String id;
  final Network network;
  late final MeshEngine engine;
  late final CollectingDelegate delegate;
  late final InMemorySeen seen;
}

class _Outbound implements MeshOutbound {
  _Outbound(this.node);
  final Node node;

  @override
  void broadcast(Envelope e) {
    for (final String peer in node.network.peersOf(node.id)) {
      node.network.enqueue(peer, e, node.id);
    }
  }

  @override
  void sendTo(String peerId, Envelope e) =>
      node.network.enqueue(peerId, e, node.id);
}

class _Frame {
  _Frame(this.target, this.envelope, this.from);
  final String target;
  final Envelope envelope;
  final String from;
}

class Network {
  final Map<String, Node> nodes = <String, Node>{};
  final Set<String> _links = <String>{}; // "a|b" with a<b
  final List<_Frame> _queue = <_Frame>[];
  int clock = 1000;
  int _idSeq = 0;

  String nextId() => 'id-${_idSeq++}';

  Node add(String id, {MeshConfig config = MeshConfig.defaults}) {
    final Node n = Node(id, this, config: config);
    nodes[id] = n;
    return n;
  }

  String _key(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  void connect(String a, String b) {
    _links.add(_key(a, b));
    // Both ends learn of the new link and flush their carry-cache.
    nodes[a]!.engine.onPeerConnected(b);
    nodes[b]!.engine.onPeerConnected(a);
  }

  void disconnect(String a, String b) => _links.remove(_key(a, b));

  Iterable<String> peersOf(String id) => nodes.keys.where(
        (String other) => other != id && _links.contains(_key(id, other)),
      );

  void enqueue(String target, Envelope e, String from) =>
      _queue.add(_Frame(target, e, from));

  /// Drain the queue: propagate every frame to completion (multi-hop). Returns
  /// once the network is quiescent.
  Future<void> pump() async {
    while (_queue.isNotEmpty) {
      final _Frame f = _queue.removeAt(0);
      final Node? target = nodes[f.target];
      if (target == null) continue;
      // A frame only lands if the link still exists at delivery time.
      if (!_links.contains(_key(f.target, f.from))) continue;
      await target.engine.onEnvelopeReceived(f.envelope, fromPeerId: f.from);
    }
  }

  void advanceClock(int ms) => clock += ms;
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

Future<void> scenarioDirectDelivery() async {
  section('Direct delivery + end-to-end ack (A <-> B)');
  final Network net = Network();
  net.add('A');
  net.add('B');
  net.connect('A', 'B');

  final Envelope sent = await net.nodes['A']!.engine.sendMessage(
    toId: 'B',
    body: 'hey',
  );
  await net.pump();

  check(
    'B received exactly one message',
    net.nodes['B']!.delegate.delivered.length == 1,
  );
  check(
    'B received the right body',
    net.nodes['B']!.delegate.delivered.first.body == 'hey',
  );
  check(
    'A got a delivery ack for its message',
    net.nodes['A']!.delegate.acked.contains(sent.id),
  );
}

Future<void> scenarioDedup() async {
  section('De-duplication (a duplicate id is dropped, not re-delivered)');
  final Network net = Network();
  net.add('A');
  final Node b = net.add('B');
  net.connect('A', 'B');

  final Envelope e = Envelope(
    id: 'dupe-1',
    kind: EnvelopeKind.msg,
    fromId: 'A',
    toId: 'B',
    body: 'once',
    ts: net.clock,
    ttl: 4,
  );
  await b.engine.onEnvelopeReceived(e, fromPeerId: 'A');
  await b.engine.onEnvelopeReceived(e, fromPeerId: 'A'); // same id again
  await net.pump();

  check(
    'delivered only once despite two arrivals',
    b.delegate.delivered.length == 1,
  );
  check(
    'the duplicate was logged as dropped',
    b.delegate.countOf(MeshEventType.duplicateDropped) == 1,
  );
}

Future<void> scenarioMultiHopRelay() async {
  section('Multi-hop relay through an uninvolved node (A - R - C)');
  final Network net = Network();
  net.add('A');
  final Node r = net.add('R');
  net.add('C');
  // A and C never touch; R is the only bridge and is neither party.
  net.connect('A', 'R');
  net.connect('R', 'C');

  final Envelope sent = await net.nodes['A']!.engine.sendMessage(
    toId: 'C',
    body: 'via relay',
  );
  await net.pump();

  check(
    'C received the message',
    net.nodes['C']!.delegate.delivered.length == 1,
  );
  check(
    'R relayed (carried) but never "delivered" to itself',
    net.nodes['R']!.delegate.delivered.isEmpty &&
        r.delegate.countOf(MeshEventType.relayed) > 0,
  );
  check(
    'A got its ack back through R',
    net.nodes['A']!.delegate.acked.contains(sent.id),
  );
}

Future<void> scenarioStoreAndForward() async {
  section('Store-and-forward across time (recipient offline, then returns)');
  final Network net = Network();
  net.add('A');
  final Node r = net.add('R');
  net.add('C');

  // C is out of range entirely. A meets a courier R and hands off the message.
  net.connect('A', 'R');
  final Envelope sent = await net.nodes['A']!.engine.sendMessage(
    toId: 'C',
    body: 'catch me later',
  );
  await net.pump();

  check(
    'nobody delivered yet (C never in range)',
    net.nodes['C']!.delegate.delivered.isEmpty,
  );
  check('R is carrying the message for later', r.engine.carriedCount >= 1);

  // A walks away; time passes; later R runs into C.
  net.disconnect('A', 'R');
  net.advanceClock(60 * 1000);
  net.connect('R', 'C'); // flush-on-connect carries it the last hop
  await net.pump();

  check(
    'C finally received it after coming back in range',
    net.nodes['C']!.delegate.delivered.length == 1 &&
        net.nodes['C']!.delegate.delivered.first.body == 'catch me later',
  );

  // And the ack survives the trip home the same way.
  net.disconnect('R', 'C');
  net.connect('A', 'R');
  await net.pump();
  check(
    'A eventually learns it was delivered',
    net.nodes['A']!.delegate.acked.contains(sent.id),
  );
}

Future<void> scenarioTtlExpiry() async {
  section('TTL bounds the flood (a 1-hop message dies at the relay)');
  final Network net = Network();
  net.add('A');
  final Node r = net.add('R');
  net.add('C');
  net.connect('A', 'R');
  net.connect('R', 'C');

  // TTL is the remaining-relay budget. R receives it with none left, so R must
  // drop it rather than forward the last hop to C.
  final Envelope e = Envelope(
    id: 'ttl-1',
    kind: EnvelopeKind.msg,
    fromId: 'A',
    toId: 'C',
    body: 'short legs',
    ts: net.clock,
    ttl: 0,
  );
  await r.engine.onEnvelopeReceived(e, fromPeerId: 'A');
  await net.pump();

  check('R saw the message', r.delegate.countOf(MeshEventType.received) == 1);
  check(
    'R dropped it for expired TTL',
    r.delegate.countOf(MeshEventType.ttlExpired) == 1,
  );
  check('C never received it', net.nodes['C']!.delegate.delivered.isEmpty);
}

Future<void> scenarioAckStopsCarry() async {
  section('Seeing an ack stops a relay from carrying the message');
  final Network net = Network();
  net.add('A');
  final Node r = net.add('R');
  net.add('C');
  net.connect('A', 'R');
  net.connect('R', 'C');

  await net.nodes['A']!.engine.sendMessage(toId: 'C', body: 'clean up after');
  await net.pump();

  check('C received', net.nodes['C']!.delegate.delivered.length == 1);
  check(
    'R stopped carrying the message once the ack passed back through',
    r.delegate.countOf(MeshEventType.carryCleared) >= 1,
  );
}

Future<void> scenarioCacheBounds() async {
  section('Carry-cache is bounded (oldest evicted past capacity)');
  final Network net = Network();
  final Node r = net.add(
    'R',
    config: const MeshConfig(ttl: 8, maxCacheSize: 3),
  );
  // R relays 5 distinct messages for others; cache must cap at 3.
  for (int i = 0; i < 5; i++) {
    await r.engine.onEnvelopeReceived(
      Envelope(
        id: 'm$i',
        kind: EnvelopeKind.msg,
        fromId: 'A',
        toId: 'Z', // not us, not connected -> pure carry
        body: 'x',
        ts: net.clock + i,
        ttl: 4,
      ),
      fromPeerId: 'A',
    );
  }
  check('cache never exceeded capacity', r.engine.carriedCount == 3);
  check(
    'evictions were logged',
    r.delegate.countOf(MeshEventType.cacheEvicted) == 2,
  );
}

Future<void> scenarioHousekeeping() async {
  section('Housekeeping ages out stale carried envelopes and seen records');
  final Network net = Network();
  final Node r = net.add(
    'R',
    config: const MeshConfig(
      ttl: 8,
      maxAgeMs: 10 * 1000,
      seenRetentionMs: 20 * 1000,
    ),
  );
  await r.engine.onEnvelopeReceived(
    Envelope(
      id: 'old',
      kind: EnvelopeKind.msg,
      fromId: 'A',
      toId: 'Z',
      body: 'stale',
      ts: net.clock,
      ttl: 4,
    ),
    fromPeerId: 'A',
  );
  check('carrying before housekeeping', r.engine.carriedCount == 1);

  net.advanceClock(11 * 1000); // past maxAge
  await r.engine.housekeeping();
  check('stale carried envelope aged out', r.engine.carriedCount == 0);

  net.advanceClock(30 * 1000); // past seenRetention
  await r.engine.housekeeping();
  check('ancient seen records pruned', r.seen.size == 0);
}

Future<void> scenarioHello() async {
  section('Hello builds the contact list and is never relayed');
  final Network net = Network();
  net.add('A');
  final Node b = net.add('B');
  net.add('C');
  net.connect('A', 'B');
  net.connect('B', 'C');

  await b.engine.onEnvelopeReceived(
    const Envelope(
      id: 'hello-A',
      kind: EnvelopeKind.hello,
      fromId: 'A',
      toId: '',
      body: '',
      ts: 0,
      ttl: 0,
      name: 'Alice',
    ),
    fromPeerId: 'A',
  );
  await net.pump();

  check('B learned Alice as a contact', b.delegate.contacts['A'] == 'Alice');
  check(
    'hello was not relayed onward to C',
    net.nodes['C']!.delegate.contacts.isEmpty,
  );
}

Future<void> scenarioChannels() async {
  section('Channels: every member receives, a non-member relay just carries');
  final Network net = Network();
  final Node a = net.add('A');
  final Node r = net.add('R');
  final Node b = net.add('B');

  // A and B join channel "ch1"; R is only a relay and does not join.
  a.engine.groupIds.add('ch1');
  b.engine.groupIds.add('ch1');
  net.connect('A', 'R');
  net.connect('R', 'B');

  await a.engine.sendMessage(toId: 'ch1', body: 'hi all');
  await net.pump();

  check(
    'B (member) received the channel message',
    b.delegate.delivered.any((Envelope e) => e.body == 'hi all'),
  );
  check(
    'R (non-member) relayed but never delivered to itself',
    r.delegate.delivered.isEmpty &&
        r.delegate.countOf(MeshEventType.relayed) > 0,
  );
  check(
    'A did not re-deliver its own channel message (dedup on own send)',
    a.delegate.delivered.isEmpty,
  );
}

Future<void> scenarioReadReceipt() async {
  section('Read receipt (recipient opens chat -> sender sees "read")');
  final Network net = Network();
  net.add('A');
  net.add('B');
  net.connect('A', 'B');

  final Envelope sent = await net.nodes['A']!.engine.sendMessage(
    toId: 'B',
    body: 'seen test',
  );
  await net.pump();
  check('A saw delivered (ack)',
      net.nodes['A']!.delegate.acked.contains(sent.id));

  // B opens the conversation and sends a read receipt for A's message.
  await net.nodes['B']!.engine.sendReadReceipt(toId: 'A', messageId: sent.id);
  await net.pump();
  check(
    'A received a read receipt for its message',
    net.nodes['A']!.delegate.read.contains(sent.id),
  );
}

Future<void> scenarioRetract() async {
  section('Retract (delete for everyone reaches the recipient via a relay)');
  final Network net = Network();
  net.add('A');
  net.add('R');
  net.add('B');
  net.connect('A', 'R');
  net.connect('R', 'B');

  final Envelope sent = await net.nodes['A']!.engine.sendMessage(
    toId: 'B',
    body: 'delete me',
  );
  await net.pump();
  check(
      'B received the message', net.nodes['B']!.delegate.delivered.isNotEmpty);

  // A deletes it for everyone; the retract floods to B through the relay.
  await net.nodes['A']!.engine.sendRetract(toId: 'B', messageId: sent.id);
  await net.pump();
  check(
    'B was told to delete the message',
    net.nodes['B']!.delegate.retracted.contains(sent.id),
  );
  check(
    'A stopped carrying the retracted message',
    !net.nodes['A']!.engine.carried.any((Envelope e) => e.id == sent.id),
  );
}

Future<void> main() async {
  print('Kabootar mesh engine - behavioural verification');
  await scenarioDirectDelivery();
  await scenarioDedup();
  await scenarioMultiHopRelay();
  await scenarioStoreAndForward();
  await scenarioTtlExpiry();
  await scenarioAckStopsCarry();
  await scenarioCacheBounds();
  await scenarioHousekeeping();
  await scenarioHello();
  await scenarioChannels();
  await scenarioReadReceipt();
  await scenarioRetract();

  print('\n── result');
  print('  $_passed passed, $_failed failed');
  if (_failed > 0) {
    throw StateError('$_failed check(s) failed');
  }
  print('  all mesh-engine invariants hold ✓');
}

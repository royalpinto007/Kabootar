import 'dart:convert';

/// The eight kinds of unit that travel over the mesh.
///
/// * [hello] - a link-local handshake. Not flooded, not relayed. When two
///   devices form a transport link they trade a [hello] so each learns the
///   other's stable app id and display name (this is how the contact list is
///   built).
/// * [msg]  - a 1:1 chat message addressed to a specific [Envelope.toId].
/// * [ack]  - an end-to-end delivery receipt. Its [Envelope.body] carries the
///   id of the message being acknowledged; it is addressed back to the
///   original sender and flows through the mesh the same way a message does.
/// * [read] - a read receipt, shaped like an [ack] (body is the read message
///   id), flowing back to the original sender.
/// * [retract] - a delete-for-everyone. Its [Envelope.body] carries the id of
///   the message to remove; it is addressed to the original recipient (or the
///   channel) and floods the same way a message does. Any node holding that
///   message deletes it.
/// * [invite] - a private-group invitation addressed to one recipient. Its
///   body is sealed to that recipient (like an encrypted message) and carries
///   the group id, name, symmetric key, and current roster.
/// * [media] - a media manifest (image/file metadata + encrypted thumbnail)
///   addressed to a peer or group. The bytes follow as [chunk] envelopes.
/// * [chunk] - one transport-sized slice of a media payload. Its body is
///   `<mediaId>|<index>|<total>|<base64slice>`; reassembled by the recipient.
enum EnvelopeKind {
  hello,
  msg,
  ack,
  read,
  retract,
  invite,
  media,
  chunk;

  static EnvelopeKind fromWire(String value) {
    switch (value) {
      case 'hello':
        return EnvelopeKind.hello;
      case 'msg':
        return EnvelopeKind.msg;
      case 'ack':
        return EnvelopeKind.ack;
      case 'read':
        return EnvelopeKind.read;
      case 'retract':
        return EnvelopeKind.retract;
      case 'invite':
        return EnvelopeKind.invite;
      case 'media':
        return EnvelopeKind.media;
      case 'chunk':
        return EnvelopeKind.chunk;
      default:
        throw FormatException('Unknown envelope kind: $value');
    }
  }

  String get wire => name;
}

/// The single unit that crosses the wire. Deliberately tiny and self-describing
/// so any node can route it without shared state: every routing decision the
/// mesh makes is a pure function of these fields.
///
/// Envelopes are immutable. Relaying produces a *new* envelope with a
/// decremented [ttl] via [relayed]; the [id] is preserved so de-duplication
/// still recognises it as the same logical unit at every hop.
class Envelope {
  const Envelope({
    required this.id,
    required this.kind,
    required this.fromId,
    required this.toId,
    required this.body,
    required this.ts,
    required this.ttl,
    this.name = '',
    this.enc = false,
    this.sig = '',
  });

  /// Globally-unique id for this logical unit. The de-dup key. Stable across
  /// every hop - this is what makes epidemic flooding idempotent.
  final String id;

  final EnvelopeKind kind;

  /// Stable app id of the originator.
  final String fromId;

  /// Stable app id of the intended recipient. Empty for a broadcast [hello].
  final String toId;

  /// Chat text for [EnvelopeKind.msg]; the acknowledged message id for
  /// [EnvelopeKind.ack]; the read message id for [EnvelopeKind.read]; the
  /// deleted message id for [EnvelopeKind.retract]; a sealed group invitation
  /// payload for [EnvelopeKind.invite]; a media manifest for
  /// [EnvelopeKind.media]; a transport slice for [EnvelopeKind.chunk]; and the
  /// hello handshake payload (which carries the sender's public-key bundle)
  /// for [EnvelopeKind.hello].
  final String body;

  /// Originator's send time, epoch milliseconds. Used for age-based pruning.
  final int ts;

  /// Remaining hops. Decremented on each relay; at zero the envelope is
  /// dropped rather than forwarded. Bounds flood radius and storage.
  final int ttl;

  /// Display name - only meaningful on a [hello]. On a hello it is also where
  /// the sender's public-key bundle rides (via [body]).
  final String name;

  /// Whether [body] is an encrypted, base64url sealed blob rather than
  /// plaintext. Set on 1:1 messages once both devices have exchanged keys.
  final bool enc;

  /// Base64url Ed25519 signature over the message's immutable fields, present
  /// on encrypted messages so the recipient can prove who sent it.
  final String sig;

  bool get isHello => kind == EnvelopeKind.hello;
  bool get isMessage => kind == EnvelopeKind.msg;
  bool get isAck => kind == EnvelopeKind.ack;
  bool get isRead => kind == EnvelopeKind.read;
  bool get isRetract => kind == EnvelopeKind.retract;
  bool get isInvite => kind == EnvelopeKind.invite;
  bool get isMedia => kind == EnvelopeKind.media;
  bool get isChunk => kind == EnvelopeKind.chunk;

  /// A copy of this envelope one hop older. Everything is preserved except a
  /// decremented [ttl] - the [id] in particular, so de-dup keeps working.
  Envelope relayed() => Envelope(
        id: id,
        kind: kind,
        fromId: fromId,
        toId: toId,
        body: body,
        ts: ts,
        ttl: ttl - 1,
        name: name,
        enc: enc,
        sig: sig,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'k': kind.wire,
        'f': fromId,
        't': toId,
        'b': body,
        'ts': ts,
        'ttl': ttl,
        if (name.isNotEmpty) 'n': name,
        if (enc) 'e2': 1,
        if (sig.isNotEmpty) 'sg': sig,
      };

  static Envelope fromJson(Map<String, Object?> json) {
    Object? req(String key) {
      final Object? value = json[key];
      if (value == null) throw FormatException('Missing field "$key"');
      return value;
    }

    return Envelope(
      id: req('id')! as String,
      kind: EnvelopeKind.fromWire(req('k')! as String),
      fromId: req('f')! as String,
      toId: (json['t'] as String?) ?? '',
      body: (json['b'] as String?) ?? '',
      ts: (req('ts')! as num).toInt(),
      ttl: (req('ttl')! as num).toInt(),
      name: (json['n'] as String?) ?? '',
      enc: (json['e2'] as num?)?.toInt() == 1,
      sig: (json['sg'] as String?) ?? '',
    );
  }

  /// Compact wire form sent over the transport.
  String encode() => jsonEncode(toJson());

  /// Parse a wire payload. Throws [FormatException] on anything malformed -
  /// callers on the receive path treat that as a poisoned frame and drop it.
  static Envelope decode(String payload) {
    final Object? decoded = jsonDecode(payload);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Envelope payload is not a JSON object');
    }
    return fromJson(decoded);
  }

  @override
  bool operator ==(Object other) => other is Envelope && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Envelope(${kind.wire} id=${_short(id)} $fromId->${toId.isEmpty ? '*' : toId} ttl=$ttl)';

  static String _short(String s) => s.length <= 8 ? s : s.substring(0, 8);
}

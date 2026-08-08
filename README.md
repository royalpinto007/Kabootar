<div align="center">

<img src="https://raw.githubusercontent.com/royalpinto007/Kabootar/main/docs/assets/logo.svg" width="96" alt="kabootar logo" />

# Kabootar

<img src="https://raw.githubusercontent.com/royalpinto007/Kabootar/main/docs/assets/flag.svg" width="132" alt="Flag of India" />

**Proudly Made in India**

### Chat that works with **no internet, no servers, no SIM.**

Messages hop **phone-to-phone over Bluetooth and Wi-Fi** and are delivered
whenever the other person comes back in range. An offline, serverless mesh
messenger built on a delay-tolerant network with epidemic routing, **end-to-end
encryption**, private groups, and image and file sharing.

<br/>

[![CI](https://github.com/royalpinto007/Kabootar/actions/workflows/ci.yml/badge.svg)](https://github.com/royalpinto007/Kabootar/actions/workflows/ci.yml)
[![Build APK](https://github.com/royalpinto007/Kabootar/actions/workflows/build-apk.yml/badge.svg)](https://github.com/royalpinto007/Kabootar/actions/workflows/build-apk.yml)
[![mesh engine: 32 invariants](https://img.shields.io/badge/mesh_engine-32_invariants_green-2ea44f)](tool/engine_check.dart)
<br/>
[![Flutter](https://img.shields.io/badge/Flutter-3.22%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](docs/PLATFORM_SETUP.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)
[![Made in India](https://img.shields.io/badge/Made%20in-India%20%F0%9F%87%AE%F0%9F%87%B3-FF9933)](#-made-in-india)

<br/>

**[What it is](#what-it-is) · [How it works](#-how-your-message-travels) · [Architecture](#-architecture) · [Try it](#-try-it) · [Roadmap](#-roadmap) · [Contributing](#-contributing)**

</div>

---

> [!NOTE]
> **Why this exists.** When the network is down or jammed but people are nearby,
> Kabootar still gets your message through. Dead-zone buildings, basements, exam
> halls, festivals, protests, stadiums, trains, remote areas, roaming with no
> plan. Proximity is available even when the internet is not.

## Screenshots

<table>
  <tr>
    <td width="25%" valign="top">
      <img src="docs/media/1-chats.webp" width="100%" alt="Chats, with delivery receipts that travelled back through the mesh.">
      <sub><b>Chats.</b> Receipts travel back the same way the message went.</sub>
    </td>
    <td width="25%" valign="top">
      <img src="docs/media/2-mesh.webp" width="100%" alt="The mesh: peers in range, messages carried for others, and live routing events.">
      <sub><b>Mesh.</b> Peers in range, what you are carrying for other people, and routing as it happens.</sub>
    </td>
    <td width="25%" valign="top">
      <img src="docs/media/3-people.webp" width="100%" alt="Scanning for nearby phones over Bluetooth and Wi-Fi.">
      <sub><b>People.</b> Whoever is running Kabootar within range.</sub>
    </td>
    <td width="25%" valign="top">
      <img src="docs/media/4-channels.webp" width="100%" alt="Channels and private groups, joined with a code.">
      <sub><b>Channels.</b> Private groups, joined with a code you share in person.</sub>
    </td>
  </tr>
</table>

<sub>Captured from the app running on a physical device, with the status and
navigation bars cropped out. Peer counts read zero because only one device was
in range for the capture.</sub>

## What it is

Kabootar is a private **messenger with no backend at all**. Instead of routing
through a server, your phone forms a peer-to-peer **mesh** with other phones
nearby. A message you send is flooded to everyone in range, **carried onward**
by each device it reaches, and delivered the moment a chain of carriers connects
you to the recipient, even if that is minutes later after you have both walked
away.

It feels like a normal chat app, a contact list, saved history, sent/delivered
receipts, end-to-end encrypted 1:1 chats and private groups, image and file sharing, but
the transport underneath is a **store-and-forward mesh** rather than the cloud.

|  | Kabootar | Normal messenger |
| --- | --- | --- |
| Needs internet / cell data | **No** | Yes |
| Needs a server or account | **No** | Yes |
| Works in a signal dead-zone | **Yes** | No |
| Your data leaves the device | **No** | Yes |
| Delivers to someone offline-then-back | **Yes**, via carriers | No |

## ✨ Features

- 📡 **Truly offline** — Bluetooth + Wi-Fi peer links, zero infrastructure.
- 🕓 **Store-and-forward** — messages wait and ride other phones until delivered.
- 🔐 **End-to-end encrypted** — X25519 + Ed25519 + AES-GCM, with signed messages
  and a safety code to verify a contact. Relays only ever see ciphertext.
- 👥 **Private groups** — invite-only, encrypted with a shared group key.
- 🖼️ **Image & file sharing** — photos are compressed and thumbnailed; any file
  (up to 8 MB) is chunked and carried across the mesh just like text.
- 🔔 **Notifications** — local alerts when a message arrives (no push server).
- 🌗 **Light / dark theme**, archive / hide / block, delete-for-everyone,
  mark-as-unread — the everyday chat controls.
- ✅ **Delivery receipts** — end-to-end acks, WhatsApp-style ticks you can trust.
- 🔁 **Self-healing routing** — epidemic flooding with idempotent de-duplication.
- 📶 **Live mesh view** — watch peers, carried messages, and routing events.
- 🧪 **Provably correct core** — 32 routing invariants verified in plain Dart.
- 🇮🇳 **Made in India** — open source, no foreign backend.

## 📨 How your message travels

Alice sends a message to Bob, who is **out of range**. A relay carries it and
delivers it later, then the receipt makes the return trip the same way.

```mermaid
sequenceDiagram
    autonumber
    participant A as Alice
    participant R as Relay (a stranger's phone)
    participant B as Bob (offline, then back)

    A->>R: msg "hey Bob" (flood)
    Note over R: Bob not in range —<br/>R carries the message
    A--xB: no path yet
    Note over A,R: time passes, Alice walks away
    R->>B: link comes up → flush carry
    B->>B: deliver + show message
    B->>R: ack (delivery receipt)
    R->>A: ack carried back
    Note over A: message flips to "delivered" ✓✓
```

Every phone applies the **same six rules** to each envelope it sees:

| # | Rule | Why it matters |
|---|------|----------------|
| 1 | **De-dup** by message id | Idempotency; stops loops and flood storms |
| 2 | **Learn** from a `hello` | Builds the contact list from whoever is near |
| 3 | **Deliver** if it is for me | Save, show, and send an `ack` |
| 4 | **Receipt** on an `ack` for me | Flip my message to *delivered* |
| 5 | **Relay + carry** otherwise | Decrement TTL, cache, re-flood; carry onward |
| 6 | **Cap** everything | TTL + max-age + cache size bound battery and storage |

<details>
<summary><b>Why this is interesting (the systems angle)</b></summary>

<br/>

This is a **delay-tolerant network (DTN)** using **epidemic routing with
end-to-end acknowledgements**, the same shape as a durable, at-least-once
message queue, but running across a swarm of phones instead of a datacenter:

- **Idempotency by id** — a message can arrive by many paths but is acted on once.
- **At-least-once delivery** made exactly-once at the edges via de-dup on the id.
- **Persisted de-dup set** — survives restarts, so a reboot cannot re-flood.
- **Bounded resources** — TTL, max-age, and cache-size caps keep a carrier honest.

The whole routing brain is **framework-free Dart** (no Flutter, no radio, no DB),
which is why its behaviour is pinned down by tests that run on a laptop. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

</details>

## 🧱 Architecture

```mermaid
flowchart TD
    UI["UI · Flutter Material 3<br/>onboarding · chats · people · mesh"]
    SVC["ChatService<br/>the seam: state · hello handshake · ticks"]
    ENG["MeshEngine<br/>DTN routing · pure Dart"]
    DB[("SQLite<br/>messages · contacts · seen")]
    TX["Transport<br/>Nearby / Multipeer P2P"]

    UI --> SVC
    SVC --> ENG
    SVC --> DB
    SVC --> TX
    ENG -. ports .-> SVC
    TX <-->|"Bluetooth + Wi-Fi"| PEERS(("nearby phones"))

    classDef core fill:#4F46E5,stroke:#3730A3,color:#fff;
    class ENG core;
```

- **`lib/core/mesh`** — the engine, envelope, config, ports. **Zero framework imports.**
- **`lib/data`** — SQLite persistence + identity; the `seen` set is persisted.
- **`lib/transport`** — `MeshTransport` interface + `flutter_nearby_connections`.
- **`lib/services/chat_service.dart`** — the single source of truth the UI binds to.
- **`lib/ui`** — a polished Material 3 messenger, including a live **Mesh** tab.

## 🚀 Try it

> [!IMPORTANT]
> The mesh needs **two physical phones on the same OS family** (Android⇄Android
> or iOS⇄iOS). Emulators have no real Bluetooth/Wi-Fi radio.

<details open>
<summary><b>Build & run from source</b></summary>

<br/>

```bash
git clone https://github.com/royalpinto007/Kabootar.git
cd Kabootar

# The Android native shell is committed, so no `flutter create` is needed.
flutter pub get
dart run flutter_launcher_icons    # launcher icon
bash tool/patch_nearby_plugin.sh   # modernise the 2021-era mesh plugin
bash tool/patch_gradle.sh          # core-library desugaring (notifications)
flutter run                        # on a connected Android device
```

iOS needs a one-time `flutter create . --platforms=ios --org dev.studchat` to
generate its Xcode shell. Full platform notes (permissions, minimum SDKs) are in
[`docs/PLATFORM_SETUP.md`](docs/PLATFORM_SETUP.md).

</details>

<details>
<summary><b>Grab a prebuilt APK</b></summary>

<br/>

Grab a signed-per-ABI APK from
[Releases](https://github.com/royalpinto007/Kabootar/releases) (pick
`kabootar-vX.Y.Z-arm64-v8a.apk` for most phones). Every push also builds one via
the [**Build APK** workflow](https://github.com/royalpinto007/Kabootar/actions/workflows/build-apk.yml)
(open the newest run → **Artifacts** → `kabootar-apks`).

</details>

<details>
<summary><b>Verify the routing engine without a phone</b></summary>

<br/>

The store-and-forward core is provable on a laptop with just the Dart SDK:

```bash
dart run tool/engine_check.dart
```

```
── Store-and-forward across time (recipient offline, then returns)
  ✓ nobody delivered yet (C never in range)
  ✓ R is carrying the message for later
  ✓ C finally received it after coming back in range
  ✓ A eventually learns it was delivered
  ...
  32 passed, 0 failed — all mesh-engine invariants hold ✓
```

</details>

## 🧭 Honest constraints

Designed in up front, so nothing surprises you:

- **Cross-platform wall** — one codebase runs on both, but a message cannot hop
  across the OS boundary (Android and iOS use different peer radios). v1 meshes
  within an OS family.
- **Range and density** — delivery needs a chain of carriers to exist. Sparse
  crowds mean slow or no delivery. Inherent to any mesh.
- **No forward secrecy yet** — encryption uses long-term static keys; a
  ratcheting scheme is future work. Open channels stay plaintext by design.
- **Battery** — continuous advertise + scan is not free; duty-cycling is planned.

## 🗺 Roadmap

- [x] Onboarding, live peer discovery, 1:1 text chat
- [x] Store-and-forward with de-dup, TTL, and end-to-end acks
- [x] Persistent history and contacts; resume undelivered on restart
- [x] Live mesh diagnostics view
- [x] 📢 Channels (broadcast group rooms, joined by code)
- [x] 🔐 End-to-end encryption (X25519 + Ed25519 + AES-GCM) + message signing
- [x] 👥 Private groups with membership (encrypted, invite-only)
- [x] 🖼 Image sharing (compressed, chunked, carried like text)
- [x] 📎 Arbitrary file sharing over the same chunk path
- [x] 🔔 Local notifications, 🌗 theme, and full chat management
- [ ] 🔒 Forward secrecy (a message ratchet on top of the static keys)
- [ ] 🔋 Battery duty-cycling
- [ ] 🌉 Online bridge: any node with internet relays onward

## 🇮🇳 Made in India

Built in India, open source, privacy-first. No servers, no foreign backend, no
account: your messages and identity **never leave your device**. Kabootar is the
kind of resilient, self-reliant tech that works in India's dead-zones, trains,
and crowds, and it belongs to everyone who runs it.

The app carries a tricolour identity and the **Ashoka Chakra**, and an in-app
**"India & Kabootar"** screen with the **Preamble** and the **Fundamental Duties
(Article 51A)** for civic reference, plus friendly facts about how the mesh
works.

> [!NOTE]
> Kabootar is an **independent, citizen-built** project. It is **not affiliated
> with or endorsed by** any government or political party. National symbols are
> used respectfully; we deliberately never use the restricted State Emblem (the
> Lion Capital). See [DISCLAIMER.md](DISCLAIMER.md).

**Legal:** [Privacy Policy](PRIVACY.md) · [Terms of Use](TERMS.md) ·
[Disclaimer](DISCLAIMER.md). Direct chats and private groups are end-to-end
encrypted; open channels are public by design and there is no forward secrecy
yet, so use your judgement for highly sensitive information.

## 🤝 Contributing

Contributions are welcome. Good first steps:

- Read [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- Keep the mesh engine framework-free and add tests for routing changes
- Open an [issue](https://github.com/royalpinto007/Kabootar/issues/new/choose) or a PR

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
Security issues: see [SECURITY.md](SECURITY.md).

## ⭐ Star this project

If Kabootar is useful or interesting, a star genuinely helps others find it.

<a href="https://github.com/royalpinto007/Kabootar/stargazers">
  <img src="https://img.shields.io/github/stars/royalpinto007/Kabootar?style=social" alt="GitHub stars" />
</a>

Once the project gathers a few stars, a growth chart will render here via
[star-history.com](https://star-history.com/#royalpinto007/Kabootar&Date).

## 📄 License

[MIT](LICENSE) © royalpinto007

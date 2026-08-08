# Kabootar v1.0.0

Kabootar is an offline-first mesh messenger. It carries your messages phone to
phone over Bluetooth and Wi-Fi, with no SIM, no internet, and no servers. A
message you send can be relayed by other phones and delivered later, when the
recipient comes back into range.

## Highlights

- **Offline mesh delivery.** Store-carry-forward epidemic routing: a message
  hops phone to phone (up to 8 hops) and is held for up to 24 hours until it
  reaches you.
- **End-to-end encryption.** X25519 key agreement, Ed25519 signatures, and
  AES-GCM. Your keys are generated on your device and never leave it. Chats
  show a safety code you can compare in person.
- **1:1 chats and channels.** Create a broadcast channel and share a short
  code so anyone nearby can join.
- **Media.** Send photos and files; they are chunked to travel across the mesh.
- **A full chat manager.** Archive, hide, block, clear, delete, delete for
  everyone, mark as unread, and multi-select.
- **Notifications and themes.** Light, dark, or follow the system.
- **Local by default.** Everything is stored on your device. No account, no
  phone number, no tracking.

## Install

Kabootar ships as per-ABI APKs to keep the download small. Pick the one for
your phone:

- **Most phones (2017 and newer, 64-bit ARM):** `kabootar-v1.0.0-arm64-v8a.apk`
- **Older 32-bit phones:** `kabootar-v1.0.0-armeabi-v7a.apk`
- **x86 tablets and emulators:** `kabootar-v1.0.0-x86_64.apk`

Enable "Install unknown apps" for your browser or file manager, then open the
downloaded APK.

## Good to know

- Two or more phones running Kabootar are needed to relay messages between
  people. A single phone still works for notes to self and for creating
  channels.
- Messages wait patiently: if the recipient is out of range, the mesh keeps
  carrying your message until they come back.

Made in India. Works offline.

## Re-cut 2026-08-08

This tag was moved to pick up the rename work. Every user-visible "Studchat" is
now "Kabootar", including the iOS app name and the two Bluetooth permission
prompts, which is the sentence somebody reads before deciding whether to let an
app use their radio.

The Android app itself is unchanged from the original v1.0.0 build: nothing
under `lib/` or `android/` differs, so these APKs behave identically. The repo
also gained screenshots in the README and issue templates.

Deliberately unchanged, because they are identifiers rather than names: the
`dev.studchat.studchat` application id, the `studchat.*` preference keys that
hold your identity and keypair, the key-derivation label, and the
`_studchat._tcp` Bonjour service names peers discover each other by. Renaming
the last two would stop a new build talking to one already in the field.

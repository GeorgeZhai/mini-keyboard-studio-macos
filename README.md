# Mini Keyboard Studio for macOS

A native SwiftUI configurator for the inexpensive USB macro keypads sold with
the Windows-only “MINI KeyBoard V02.1.1” utility.

This project was built against a keypad connected to macOS as **USB
`1189:8890`**. It uses Apple's built-in USB stack and has no runtime dependency.

## Download

Download the prebuilt universal app from
[release/Mini-Keyboard-Studio-1.2.dmg](release/Mini-Keyboard-Studio-1.2.dmg).
It supports both Apple Silicon and Intel Macs running macOS 13 or newer.

## The short answer about drivers

The keypad does **not** need a custom Mac driver for normal use. macOS already
recognizes its keyboard, media-key, and mouse interfaces as standard USB HID.
Mini Keyboard Studio is only used to change mappings. Once saved, the mapping
lives in the keypad and the app can be closed or removed.

## Features

- Native macOS UI with 3 layers and common 3/6/12-key layouts
- Keyboard shortcuts and five-step macros
- Command, Option, Control, and Shift modifiers
- Media controls and mouse clicks/scrolling
- One- and two-knob layouts
- Backlight modes exposed by the original utility
- Three known `1189:8890` firmware protocols
- Edit every displayed control, then save the complete mapping in one action
- Safe mapping writes; no firmware or hardware-variant commands
- Clearly labeled local draft because this model cannot read mappings back

## Build and run

macOS 13 or newer and Apple's Command Line Tools are sufficient; full Xcode is
not required.

```sh
./scripts/build-app.sh
open "dist/Mini Keyboard Studio.app"
```

`build-app.sh` creates a universal app for Apple Silicon and Intel Macs. To
create the same compressed disk image used for GitHub releases:

```sh
./scripts/build-dmg.sh
```

The versioned DMG is written to `dist/`. Local build products are ignored by
Git; selected release builds may be copied into `release/` for direct download
and attached to a GitHub Release.

The app is deliberately not sandboxed because it needs direct user-space access
to the output-only configuration interface. Without the optional environment
variables below, the scripts make an ad-hoc signed build for local testing.

## Signing and notarization

Frictionless distribution outside the Mac App Store requires an active
[Apple Developer Program](https://developer.apple.com/programs/) membership, a
**Developer ID Application** certificate, and Apple notarization. Apple
currently charges USD 99 per membership year, or the local-currency equivalent.

Create the certificate through Xcode or
[Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list),
then confirm that it is installed in your login keychain:

```sh
security find-identity -v -p codesigning
```

Create an app-specific password for your Apple Account and store the notarization
credentials securely in Keychain. The command prompts for the password; do not
put it in this repository:

```sh
xcrun notarytool store-credentials "MiniKeyboardStudio" \
  --apple-id "YOUR_APPLE_ACCOUNT_EMAIL" \
  --team-id "YOUR_TEAM_ID"
```

Build, sign with hardened runtime and a secure timestamp, notarize the DMG, and
staple the resulting ticket in one operation:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: YOUR NAME (TEAM_ID)" \
NOTARYTOOL_PROFILE="MiniKeyboardStudio" \
./scripts/build-dmg.sh
```

The scripts never store a certificate, password, or private key in the project.
See Apple's guides to
[Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)
and the
[notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
for account and troubleshooting details.

## Tests

Run the zero-dependency unit and protocol-vector suite with:

```sh
./scripts/test.sh
```

The suite validates report framing and padding, all supported protocol styles,
media and mouse encodings, error handling, hardware slot layouts, HID key codes,
and the built-in macOS presets. The diagnostic self-test does not write to the
keyboard.

To check the device without writing anything:

```sh
swift run -c release MiniKeyboardDiag --probe-only
swift run -c release MiniKeyboardDiag
swift run -c release MiniKeyboardDiag --readback-probe
```

The second command opens interface 1 and endpoint `0x02`, then closes them
without sending a report. The readback probe issues standard read-only HID
requests and does not change any mapping.

## Using the app

1. Connect the keypad and confirm that the header says **Connected**.
2. Choose the physical layout and layer.
3. Click a key or one of a knob's left/press/right controls.
4. Edit the other keys and knob actions in the same way.
5. Choose **Save All to Keypad** once to apply the complete displayed mapping.
6. Press the physical controls to test them.

Start with protocol **V02.1.1**, which matches the Windows app linked for this
project. Some `1189:8890` batches use different firmware; if a saved control does
not change, open **Compatibility**, try **Layered 8890** and then **FE preamble**,
and save all controls again.

See [Docs/PROTOCOL.md](Docs/PROTOCOL.md) for the USB inspection and safety notes.

## Important limitation

This hardware's configuration interface is output-only. It cannot return its
existing mappings. On the tested unit, standard input, output, and feature
`GET_REPORT` requests each return only the one-byte acknowledgement `AA`, not a
64-byte mapping report. The UI therefore labels its values as a **local draft**.
Choosing **Save All to Keypad** overwrites every displayed control with that
draft.

## License

MIT. Protocol research credits are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

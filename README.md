# Mini Keyboard Studio for macOS

A native SwiftUI configurator for the inexpensive USB macro keypads sold with
the Windows-only “MINI KeyBoard V02.1.1” utility.

This project was built against a keypad connected to macOS as **USB
`1189:8890`**. It uses Apple's built-in USB stack and has no runtime dependency.

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
- Safe per-control writes; no firmware or hardware-variant commands
- Local draft persistence because this model cannot read mappings back

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

The versioned DMG is written to `dist/`. Build products are intentionally
ignored by Git and should be attached to a GitHub Release rather than committed
to the source repository.

The app is ad-hoc signed for local use. It is deliberately not sandboxed,
because it needs direct user-space access to the output-only configuration
interface. Public downloads are not Apple-notarized, so Gatekeeper may require
the user to Control-click the app and choose **Open** the first time. A release
signed with an Apple Developer ID and notarized by Apple avoids that warning.

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
```

The second command opens interface 1 and endpoint `0x02`, then closes them
without sending a report.

## Using the app

1. Connect the keypad and confirm that the header says **Connected**.
2. Choose the physical layout and layer.
3. Click a key or one of a knob's left/press/right controls.
4. Pick an action or preset, then choose **Save to Keypad**.
5. Press the physical control to test it.

Start with protocol **V02.1.1**, which matches the Windows app linked for this
project. Some `1189:8890` batches use different firmware; if a saved control does
not change, open **Compatibility**, try **Layered 8890** and then **FE preamble**,
and save that control again.

See [Docs/PROTOCOL.md](Docs/PROTOCOL.md) for the USB inspection and safety notes.

## Important limitation

This hardware's configuration interface is output-only. It cannot return its
existing mappings, so the UI starts with a useful local draft rather than
claiming to show what is already stored on the device.

## License

MIT. Protocol research credits are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

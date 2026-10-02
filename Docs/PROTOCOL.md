# USB and protocol notes

## Hardware observed on this Mac

The connected device enumerates as:

- USB vendor ID `0x1189` (4489)
- USB product ID `0x8890` (34960)
- full-speed USB HID composite device
- interface 0: boot keyboard
- interface 1: HID configuration interface, interrupt OUT endpoint `0x02`
- interface 2: keyboard + Consumer/media input
- interface 3: mouse input

macOS attaches its built-in HID drivers to interfaces 0, 2, and 3. Interface 1
has no system driver because it is output-only. Mini Keyboard Studio opens only
interface 1 with `IOUSBHost`; it does not seize the full USB device.

## Driver conclusion

No kernel extension or DriverKit extension is needed. Normal keys already use
the standard USB HID keyboard, mouse, and Consumer pages. A user-space app is
needed only when mappings are changed, and the mapping is then stored in the
keypad's flash.

## Report framing

The HID report descriptor declares a 64-byte payload under report ID `0x03`, so
the user-space write is **65 bytes** total. The command begins at byte 1 and
unused bytes are zero-filled. USB itself splits that report into endpoint-sized
transactions as needed.

The app supports three observed `1189:8890` command dialects:

1. **V02.1.1** — reconstructed from the linked Windows `HIDTester` configurator.
   It is single-layer, sends binding records beginning with the control slot and
   plain type (`01`, `02`, or `03`), and commits with `03 AA AA`.
2. **Layered 8890** — selects the layer with `03 A1 <layer>`, puts the layer in
   the high nibble of the type byte, and commits with `03 AA AA`. This form has
   been hardware-tested by another open-source implementation.
3. **FE preamble** — uses `03 FE <layer> 01 01` before the layered binding
   records and commits with `03 AA AA`.

Keys use slots 1–12. Knob actions use 13/14/15 for left/press/right on knob 1
and 16/17/18 on knob 2. Shortcuts can contain up to five HID key steps.

The configuration interface has no input endpoint, so current mappings cannot
be read back. The app keeps the draft locally and writes every control displayed
for the selected layout in one save operation. Each control still uses its own
firmware commit report inside that batch.

## Safety choices

Mini Keyboard Studio never sends:

- firmware/bootloader commands (`0xEF` or `0x5A` in related protocols);
- hardware-variant command `0xFC`;
- blind command scans;
- any report to the normal keyboard, media, or mouse interfaces.

Only documented binding, layer-select, commit, and backlight reports are built.

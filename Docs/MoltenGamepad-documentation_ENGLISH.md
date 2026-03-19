# MoltenGamepad – User Documentation

MoltenGamepad is a daemon that reads input devices (controllers, gamepads, etc.) and forwards them as virtual gamepads that game software understands. It lets you remap buttons and axes, combine input devices, and ensure controllers "just work" — even when they are disconnected and reconnected.

---

## Table of Contents

1. [Concepts and Terminology](#1-concepts-and-terminology)
2. [Configuration Files and Directory Structure](#2-configuration-files-and-directory-structure)
3. [Creating a Generic Driver (gendev)](#3-creating-a-generic-driver-gendev)
4. [Default Gamepad Profile – Name Reference](#4-default-gamepad-profile--name-reference)
5. [Profiles and Event Mapping](#5-profiles-and-event-mapping)
6. [Output Slots](#6-output-slots)
7. [Startup and Configuration File](#7-startup-and-configuration-file)
8. [Running and Sending Commands](#8-running-and-sending-commands)
9. [Advanced: Group Translators](#9-advanced-group-translators)

---

## 1. Concepts and Terminology

Before configuring anything, it helps to have a clear picture of how MoltenGamepad (MG) is structured.

```
[Physical device] → [Driver/gendev] → [Input source] → [Profile] → [Output slot / virtual gamepad]
```

**Input source** is MG's representation of a physical device. One input source can come from one physical device, or a single device can be split into multiple input sources.

**Driver** is the code that understands a particular type of device. MG has one built-in driver for Wii remotes. For all other devices you create a *generic driver* via a `.cfg` file (see section 3).

**Profile** contains all event mappings for a driver or device. Profiles inherit from each other in a hierarchy:

```
gamepad (root profile)
 ├── <driver profile>
 │    ├── <device profile>
 │    └── <device profile>
 └── <driver profile>
      └── <device profile>
```

Changes to a driver profile automatically propagate down to all connected devices. Changes to the root profile `gamepad` propagate to all drivers that subscribe to it (the default for all gamepads).

**Output slot** is the virtual gamepad devices created by MG, named `virtpad1`, `virtpad2`, etc. These are what games actually read from. By default, 4 virtual gamepads are created, one keyboard slot (`keyboard`), and one empty dummy slot (`blank`).

---

## 2. Configuration Files and Directory Structure

MG follows the XDG specification. With default values that means:

| Purpose | User-specific | System-wide |
|---|---|---|
| Config root directory | `~/.config/moltengamepad/` | `/etc/xdg/moltengamepad/` |
| Generic drivers | `~/.config/moltengamepad/gendevices/` | `/etc/xdg/moltengamepad/gendevices/` |
| Profiles | `~/.config/moltengamepad/profiles/` | `/etc/xdg/moltengamepad/profiles/` |
| Startup settings | `~/.config/moltengamepad/moltengamepad.cfg` | `/etc/xdg/moltengamepad/moltengamepad.cfg` |
| Dynamic settings | `~/.config/moltengamepad/options/*.cfg` | `/etc/xdg/moltengamepad/options/*.cfg` |

---

## 3. Creating a Generic Driver (gendev)

This is the first thing you need to do after installation if you are not using a Wii remote. A generic driver tells MG which device to handle, and what the various event codes from the device are called.

The file is placed in the `gendevices/` directory, e.g. `~/.config/moltengamepad/gendevices/mycontroller.cfg`.

### 3.1 Finding Event Codes for Your Device

Install `evtest` and run it:

```bash
sudo evtest
```

Select your device from the list, press buttons and move axes. You will see output like:

```
Event: time 1234567890.123, type 1 (EV_KEY), code 304 (BTN_SOUTH), value 1
Event: time 1234567890.456, type 3 (EV_ABS), code 0 (ABS_X), value -32767
```

Note down the event names (e.g. `btn_south`, `abs_x`) for all inputs you want to use. At the top of the `evtest` output you will also find the vendor ID and product ID:

```
Input device ID: bus 0x3 vendor 0x045e product 0x028e version 0x110
```

### 3.2 Structure of a gendev File

A gendev file has four parts:

```ini
# Part 1: Which device should this driver recognise?
["Device name as reported by the system"]

# Part 2: Driver name and settings
name = "mydriver"      # Name of the driver in MG
devname = "pad"        # Prefix for device names (pad1, pad2, ...)
exclusive = "true"     # Hide the original device from other software

# Part 3: Event definitions  (<evdev code> = "<internal name>","<description>")
btn_south = "first",   "Primary button"
btn_east  = "second",  "Secondary button"
abs_x     = "left_x",  "Left stick X axis"

# Part 4: Aliases (connects the device's names to the gamepad profile's names)
alias first  first
alias second second
```

### 3.3 Device Matching

The simplest way to match a device is via its reported name:

```ini
["Microsoft X-Box 360 pad"]
```

You can also combine multiple fields (all must match):

```ini
[name="Microsoft X-Box 360 pad" vendor=045e product=028e]
```

Available match fields:

| Field | Description |
|---|---|
| `name` | The device's reported name (string) |
| `vendor` | Vendor ID in hex |
| `product` | Product ID in hex |
| `driver` | Name of the Linux driver |
| `events` | `superset`, `subset`, or `exact` – compares the event list |
| `min_common_events` | Minimum number of common events for a `subset` match |
| `order` | Priority when matches overlap (lower number = higher priority) |

Multiple match lines in a row define alternative devices under the **same driver**. Two separate match blocks (with something else in between) define **two separate drivers**.

### 3.4 Driver Name and Settings

```ini
name = "mydriver"           # Driver name used in MG commands
devname = "pad"             # Prefix for connected devices: pad1, pad2, ...
exclusive = "true"          # Steals events – original device appears silent
change_permissions = "true" # Blocks access to the original device entirely (requires ownership via udev)
flatten = "false"           # Coalesces all matching devices into one input source
rumble = "false"            # Forward rumble events (requires --rumble at startup)
split = 1                   # Number of input sources from one device (for arcade sticks etc.)
device_type = "gamepad"     # "gamepad" (default), "keyboard", or custom string
```

> **Note on `change_permissions`:** Requires your user to be owner of the device node. This is set up via the udev rules from the installation process.

### 3.5 Event Definitions

Format: `<evdev code> = "<internal name>","<description>"`

```ini
btn_south  = "first",    "Primary button (Confirm)"
btn_east   = "second",   "Secondary button (Back)"
abs_x      = "left_x",  "Left stick X axis"
abs_y      = "left_y",  "Left stick Y axis"
```

If you need to specify an event by number instead of name:

```ini
key(304) = "first",  "Primary button"    # btn_south = key code 304
abs(0)   = "left_x", "Left X"           # abs_x = abs code 0
```

### 3.6 Aliases – Connecting to the Gamepad Profile

> **This is the most important and most overlooked part.** Once you understand this, you understand MoltenGamepad.

When `device_type = "gamepad"` (the default), the driver automatically subscribes to the **root profile `gamepad`**. This profile contains default mappings that forward events to the correct output codes.

The `gamepad` profile uses specific event names. Your device uses your own internal names. **Aliases are the bridge between these.**

**Example:** The gamepad profile knows `first` as the primary button. Your device has `cross` as the internal name for that same button. So you add:

```ini
alias first cross
```

This means: "When the gamepad profile tries to configure `first`, use my event `cross` instead."

Without aliases, the mappings from the gamepad profile will have no effect on your device.

### 3.7 Reference: Gamepad Profile Event Names

These are all the names the gamepad profile understands. You need aliases for the names that do not already match your own event names.

**Buttons:**

| Gamepad profile name | Evdev code | Description |
|---|---|---|
| `first` | `BTN_SOUTH` | Primary button (Confirm) |
| `second` | `BTN_EAST` | Secondary button (Back) |
| `third` | `BTN_WEST` | Third face button |
| `fourth` | `BTN_NORTH` | Fourth face button |
| `up` | `BTN_DPAD_UP` | D-pad up |
| `down` | `BTN_DPAD_DOWN` | D-pad down |
| `left` | `BTN_DPAD_LEFT` | D-pad left |
| `right` | `BTN_DPAD_RIGHT` | D-pad right |
| `start` | `BTN_START` | Start |
| `select` | `BTN_SELECT` | Select |
| `mode` | `BTN_MODE` | Logo/Guide/Home button |
| `tl` | `BTN_TL` | Upper left shoulder button (L1/LB) |
| `tr` | `BTN_TR` | Upper right shoulder button (R1/RB) |
| `tl2` | `BTN_TL2` | Lower left trigger, digital (only without analog triggers) |
| `tr2` | `BTN_TR2` | Lower right trigger, digital (only without analog triggers) |
| `thumbl` | `BTN_THUMBL` | Left stick click (L3) |
| `thumbr` | `BTN_THUMBR` | Right stick click (R3) |
| `tl2_axis_btn` | – | Digital event from analog trigger – normally ignored |
| `tr2_axis_btn` | – | Digital event from analog trigger – normally ignored |

**Axes:**

| Gamepad profile name | Evdev code | Description |
|---|---|---|
| `left_x` | `ABS_X` | Left stick X axis |
| `left_y` | `ABS_Y` | Left stick Y axis |
| `right_x` | `ABS_RX` | Right stick X axis |
| `right_y` | `ABS_RY` | Right stick Y axis |
| `tl2_axis` | `ABS_Z` | Left trigger, analog value |
| `tr2_axis` | `ABS_RZ` | Right trigger, analog value |
| `updown` | `ABS_HAT0Y` | D-pad up/down as hat axis |
| `leftright` | `ABS_HAT0X` | D-pad left/right as hat axis |

> **`tl2` vs. `tl2_axis`:** If the device has **analog** triggers, use `tl2_axis`/`tr2_axis` for the analog values, and map `tl2_axis_btn`/`tr2_axis_btn` to `nothing`. If the device only has **digital** triggers, use `tl2`/`tr2`.

**Backwards compatibility aliases:**

| Alias | Points to |
|---|---|
| `primary` | `first` |
| `secondary` | `second` |

### 3.8 Complete Example – Xbox 360 Controller

```ini
["Microsoft X-Box 360 pad"]

name    = "xbox360"
devname = "xbox"
exclusive = "true"

# Face buttons
btn_south = "a",      "A button"
btn_east  = "b",      "B button"
btn_west  = "x",      "X button"
btn_north = "y",      "Y button"

# Shoulder buttons and triggers
btn_tl    = "lb",       "Left shoulder"
btn_tr    = "rb",       "Right shoulder"
abs_z     = "lt_axis",  "Left trigger, analog"
abs_rz    = "rt_axis",  "Right trigger, analog"
btn_tl2   = "lt",       "Left trigger, digital"
btn_tr2   = "rt",       "Right trigger, digital"

# Sticks
abs_x     = "left_x",   "Left stick X"
abs_y     = "left_y",   "Left stick Y"
abs_rx    = "right_x",  "Right stick X"
abs_ry    = "right_y",  "Right stick Y"
btn_thumbl = "l3",      "Left stick click"
btn_thumbr = "r3",      "Right stick click"

# D-pad
abs_hat0x = "leftright", "D-pad left/right"
abs_hat0y = "updown",    "D-pad up/down"

# Menu buttons
btn_start  = "start",   "Start"
btn_select = "back",    "Back"
btn_mode   = "guide",   "Xbox Guide"

# Aliases to gamepad profile
# (Events that already have the correct name do not need an alias)
alias first    a
alias second   b
alias third    x
alias fourth   y

alias tl       lb
alias tr       rb
alias tl2_axis    lt_axis
alias tr2_axis    rt_axis
alias tl2_axis_btn lt
alias tr2_axis_btn rt

alias thumbl   l3
alias thumbr   r3
alias start    start
alias select   back
alias mode     guide
```

> **Tip:** Events that already have the correct name (e.g. `left_x`, `left_y`, `right_x`, `right_y`, `leftright`, `updown`) do not need an alias — they match the gamepad profile's names directly.

---

## 4. Default Gamepad Profile – Name Reference

*(See section 3.7 for the complete table.)*

The gamepad profile is the root profile that all gamepad drivers inherit from. It defines default mappings from logical event names to virtual output codes. Your driver needs aliases to tell the profile which of your event names correspond to the profile names.

---

## 5. Profiles and Event Mapping

### 5.1 Changing a Mapping

Syntax for changing a mapping:

```
<profile>.<event name> = <output event>
```

**Examples:**

```
# Change for all devices in a driver at once:
xbox360.a = select

# Change for one specific device only:
xbox1.a = start

# Change for all gamepads via the root profile:
gamepad.select = start

# Remove a mapping (send nothing):
xbox360.a = nothing
```

Changes to a driver profile propagate to all currently connected and future devices from that driver. Changes to a device profile apply only to that specific device.

### 5.2 Available Output Events

**Buttons:**
`first`, `second`, `third`, `fourth`, `start`, `select`, `mode`, `lt`, `lt2`, `tr`, `tr2`, `thumbl`, `thumbr`, `up`, `down`, `left`, `right`

**Axes:**
`left_x`, `left_y`, `right_x`, `right_y`, `tl2_axis`, `tr2_axis`, `leftright`, `updown`

All evdev codes are also available as output using lowercase names:
`btn_south`, `abs_x`, `key_a`, `key_esc`, etc.

### 5.3 Mapping Types

**Button → button:**
```
xbox360.a = first
```

**Axis → axis** (+ or - for direction):
```
xbox360.left_x = left_x
xbox360.left_x = left_x-    # inverted
```

**Button → axis** (button sets the axis to maximum in the chosen direction):
```
xbox360.a = left_x+
```

**Axis → two buttons** (negative extreme = first button, positive = second):
```
xbox360.left_x = left,right
```

**Button → relative event** (generates events periodically while held):
```
xbox360.a = rel_x+
```

**Inverted input** (add `-` to the end of the input event name):
```
xbox360.left_x- = right_x    # invert the input axis
```

**Multiple outputs from one input:**
```
xbox360.a = multi(start,select)
```

**Redirect to keyboard slot:**
```
xbox360.a = key(key_a)
```

**Redirect to mouse pointer:**
```
xbox360.left_x = mouse(rel_x)
```

### 5.4 Profile Commands

```
print profiles              # List all active profiles
print profiles xbox360      # Show all mappings in the xbox360 profile
print events xbox360        # Show all events a driver/device exposes
print aliases xbox360       # Show all aliases for a driver/device
print devices xbox1         # Show information about a device, including events
```

### 5.5 Saving and Loading Profiles

```
save profiles to "myprofile"    # Saves all driver profiles to profiles/myprofile
load profiles from "myprofile"  # Loads a profile file
```

**Headers in profile files** – lets you group mappings:

```ini
[xbox360]
a = first
b = second
left_x = left_x
left_y = left_y
```

This is equivalent to writing `xbox360.a = first` etc., but more readable in files.

---

## 6. Output Slots

Output slots are the virtual devices that games read from. By default:

- `virtpad1` through `virtpad4` – virtual gamepads
- `keyboard` – virtual keyboard
- `blank` – empty dummy slot (ignores all events)

An input source is automatically assigned to the first available virtpad slot on the first "notable" event (a button press or large axis movement).

### 6.1 Moving Devices Between Slots

```
move xbox1 to virtpad2     # Move to a specific slot
move xbox1 to nothing      # Remove from all slots
move xbox1 to auto         # Force automatic assignment
move all to nothing        # Remove all devices from slots
print slots                # See all slots and their contents
print devices              # See all connected input sources
```

### 6.2 Slot Settings

Displayed with `print options slots`, changed with `set slots <name> = <value>`:

| Setting | Description |
|---|---|
| `auto_assign` | Whether devices are automatically assigned a slot at startup (true/false) |
| `active_pads` | Max number of slots to consider during automatic assignment |
| `min_pads` | Minimum number of open virtpads |
| `press_start_on_disconnect` | Send a virtual start button when a device disconnects (`any`/`last`/off) |
| `press_start_ms` | Duration in ms for the virtual start button event |

---

## 7. Startup and Configuration File

### 7.1 moltengamepad.cfg

Created at `~/.config/moltengamepad/moltengamepad.cfg`. Same options as command line arguments, but with underscores instead of hyphens:

```ini
# ~/.config/moltengamepad/moltengamepad.cfg

# Make virtual gamepads look like Xbox 360 controllers (recommended)
mimic_xpad = true

# Create a FIFO for scripting
make_fifo = true

# Load custom profile mappings at startup
load profiles from "my_mappings"
```

See all available options with:
```bash
moltengamepad --print-cfg
```

### 7.2 Dynamic Settings (options/*.cfg)

For settings that can be changed while MG is running, create `.cfg` files in the `options/` directory. The filename corresponds to the category name:

```ini
# ~/.config/moltengamepad/options/slots.cfg
auto_assign = true
```

---

## 8. Running and Sending Commands

```bash
moltengamepad                    # Start normally
moltengamepad --mimic-xpad       # Recommended: appear as Xbox 360
moltengamepad --help             # Show all arguments
```

### 8.1 Interactive Commands

MG reads commands from standard input while running:

```
help                        # Show available commands
print drivers               # Show all loaded drivers
print profiles              # Show all profiles
print slots                 # Show output slots and their connected devices
print devices               # Show all connected input sources
print events <driver>       # Show events for a driver/device
print options slots         # Show slot settings
set slots auto_assign = true
```

### 8.2 Sending Commands to a Running Instance

**Via FIFO** (one-way, send commands only):
```bash
moltengamepad --make-fifo   # Create FIFO at startup
echo "gamepad.select = start" > /path/to/fifo
```

**Via socket** (two-way, requires a client such as `moltengamepadctl`):
```bash
moltengamepad --make-socket
```

---

## 9. Advanced: Group Translators

Some mappings need to read two events simultaneously, for example to handle a thumbstick with a deadzone correctly.

### Thumbstick

```
xbox360.(left_x,left_y) = stick(left_x,left_y)
xbox360.(right_x,right_y) = stick(right_x,right_y)
```

The `stick` translator looks at both axes simultaneously and filters out jitter within the deadzones. This is the default mapping in the gamepad profile and is set up automatically if your device has `left_x`/`left_y` aliases.

### D-pad from Analog Hat

```
xbox360.(leftright,updown) = dpad
```

Converts a hat axis into digital d-pad events.

### Clear a Group Mapping

```
xbox360.(left_x,left_y) = nothing
```

### Aliases for Groups

An alias can point to a group of events, allowing shorter syntax:

```
xbox360.left_stick = dpad    # left_stick is an alias for (left_x,left_y)
```

### Chords

```
xbox360.(a,b) = chord(tr)        # Sends tr when BOTH a and b are held
xbox360.(a,b) = exclusive(tr)    # Like chord, but a and b are NOT sent separately
```
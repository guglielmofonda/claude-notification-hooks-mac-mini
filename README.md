# Claude Code Notification Hooks for macOS

Never miss a Claude Code prompt again. When the agent needs your attention — permission dialogs, idle prompts, task completions — your **MacBook camera LED blinks** and a **voice announcement tells you which terminal window needs you**.

```
"Your agent needs you at ODF HQ"
```

Both fire simultaneously so you notice even when you're away from the screen.

---

## What it does

| Signal | How | Why |
|--------|-----|-----|
| Camera LED blinks 5× | Briefly activates the FaceTime camera 5 times | The LED is hardwired to the sensor — the only way to flash it |
| Voice says tab name | `say -v Daniel "Your agent needs you at <tab name>"` | Audible even when headphones are on or screen is off |

---

## Requirements

### Hardware & OS
- **macOS** (tested on macOS 15 Sequoia, Apple Silicon)
- **MacBook with built-in FaceTime camera** (for the LED blink feature)

### Software
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** — the Anthropic CLI this hooks into
- **[Homebrew](https://brew.sh)** — to install `imagesnap`
- **[imagesnap](https://github.com/rharder/imagesnap)** — command-line camera capture tool used to toggle the LED
- **Python 3** — ships with macOS, used by the Ghostty tab-name resolver
- **`say`** — built into macOS, no installation needed

### Terminal

The tab-name announcement works with all three major macOS terminals:

| Terminal | How tab name is read | Extra setup |
|----------|---------------------|-------------|
| **Ghostty** | OSC marker + Accessibility API | Grant Accessibility to `/usr/bin/osascript` (one-time, see below) |
| **iTerm2** | `$ITERM_SESSION_ID` + AppleScript | None — works automatically |
| **Terminal.app** | AppleScript frontmost window | None — works automatically |

If you use a different terminal the hook falls back gracefully to *"Your agent needs you"* (no tab name).

---

## Installation

### 1. Install imagesnap

```bash
brew install imagesnap
```

### 2. Create the hooks directory

```bash
mkdir -p ~/.claude/hooks
```

### 3. Copy the hook files

Copy these three files into `~/.claude/hooks/`:

- `camera-blink.sh` — blinks the camera LED
- `notify.sh` — speaks the tab name
- `ghostty-tab-name.py` — resolves the correct Ghostty window title (Ghostty users only)

Make the scripts executable:

```bash
chmod +x ~/.claude/hooks/camera-blink.sh
chmod +x ~/.claude/hooks/notify.sh
chmod +x ~/.claude/hooks/ghostty-tab-name.py
```

### 4. Update the hardcoded path in `notify.sh`

`notify.sh` calls `ghostty-tab-name.py` with an absolute path. Open `notify.sh` and replace the path on line 12 to match your home directory:

```bash
# Change this:
TAB_NAME=$(python3 /Users/guglielmofonda/.claude/hooks/ghostty-tab-name.py "/dev/$tty_val" 2>/dev/null)

# To this (replace YOUR_USERNAME):
TAB_NAME=$(python3 /Users/YOUR_USERNAME/.claude/hooks/ghostty-tab-name.py "/dev/$tty_val" 2>/dev/null)
```

Or just use `$HOME`:

```bash
TAB_NAME=$(python3 "$HOME/.claude/hooks/ghostty-tab-name.py" "/dev/$tty_val" 2>/dev/null)
```

### 5. Configure `~/.claude/settings.json`

Add the Notification hook to your Claude Code settings. Create the file if it doesn't exist:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/camera-blink.sh & ~/.claude/hooks/notify.sh; wait"
          }
        ]
      }
    ]
  }
}
```

> The `&` runs camera-blink and notify in parallel. `wait` ensures Claude Code waits for both to finish before continuing.

### 6. Grant camera access

The first time the hook fires, macOS will prompt for camera access for your terminal app. Click **Allow**, or go to:

**System Settings → Privacy & Security → Camera** → enable your terminal app.

---

## Ghostty only: grant Accessibility permission

Ghostty has no queryable title API — it does not respond to standard OSC title queries and doesn't ship a traditional AppleScript dictionary. Instead, `ghostty-tab-name.py` identifies the correct window using an **OSC marker trick** via the macOS Accessibility API:

1. Snapshots all current Ghostty window titles
2. Writes a unique invisible marker to the shell's PTY via an OSC escape sequence
3. Ghostty interprets it and updates that window's title to the marker
4. Compares before/after to find which window is ours
5. Returns the original title and restores it

This requires `/usr/bin/osascript` to have Accessibility permission.

**One-time setup:**

1. Open **System Settings → Privacy & Security → Accessibility**
2. Click the **`+`** button
3. Press **Cmd + Shift + G** in the file picker
4. Type `/usr/bin/osascript` and press **Go**
5. Click **Open**

Once granted, tab names are read automatically. You can rename tabs natively in Ghostty (right-click the tab bar, or use the keyboard shortcut `Cmd + Shift + ,` on some builds) and the hook picks up the new name immediately — no shell commands needed.

---

## How the camera LED trick works

The MacBook camera LED is **hardwired to the image sensor at the hardware level**. There is no software API to control it independently — the LED can only turn on when the camera is actively capturing frames. This is a deliberate security design: you can always trust the LED as a true indicator of camera activity.

`camera-blink.sh` exploits this by using `imagesnap` to capture a single frame 5 times in a loop:

```bash
for _ in 1 2 3 4 5; do
  imagesnap -w 0.5 /tmp/claude-snap.jpg &>/dev/null   # activate camera → LED on
  rm -f /tmp/claude-snap.jpg
  sleep 0.5                                            # release camera → LED off
done
```

- `-w 0.5` is the camera warm-up time before capture
- The hardware needs ~0.5s per cycle to produce a visibly distinct flash
- The captured frames are immediately deleted — nothing is saved

---

## How the tab-name announcement works

### Ghostty

Ghostty does not expose tab titles through any of the standard mechanisms:

- **OSC `\033[21t`** (xterm title query) — Ghostty does not respond to this sequence
- **`CGWindowListCopyWindowInfo`** — returns empty titles on macOS 15 without Screen Recording permission
- **AppleScript scripting dictionary (`sdef`)** — not available; Ghostty uses App Intents instead
- **`$GHOSTTY_SURFACE_ID`** — not inherited by Claude Code's subprocess environment

The solution (`ghostty-tab-name.py`) works in three stages:

1. **Find the parent TTY**: Walk the process tree from the hook subprocess upward until a TTY device is found (e.g. `/dev/ttys006`). This is the pseudo-terminal that Ghostty allocated for the shell running Claude Code.

2. **Identify the window**: Write a unique OSC 0 title-change sequence to the PTY slave. Ghostty reads it from the PTY master and updates that window's title. By snapshotting all window titles before and after, we can identify exactly which window responded — even when that window is in the background behind other apps.

3. **Restore and return**: The original title is taken from the pre-marker snapshot. It is written back to the PTY so the window title is restored. The name is stripped of any leading status decorators (e.g. Ghostty's braille-dot spinner `⠂`, `✳`) before being passed to `say`.

### iTerm2

iTerm2 sets `$ITERM_SESSION_ID` in every shell it spawns (e.g. `w0t0p0:GUID`). `notify.sh` passes this ID to AppleScript, which iterates iTerm2's window/tab/session hierarchy to find the exact session and return its tab label. This works correctly even when the iTerm2 window is not focused.

### Terminal.app

Terminal.app is queried via AppleScript for `name of selected tab of front window`. This is best-effort: if Terminal.app is not the frontmost application, it returns the most recently active window's selected tab name.

---

## Customization

### Change the number of blinks

Edit `camera-blink.sh`:

```bash
for _ in 1 2 3; do   # 3 blinks instead of 5
```

### Change blink speed

Adjust the `-w` warm-up and `sleep` durations. Lower than ~0.4s per phase makes the flashes imperceptible:

```bash
imagesnap -w 0.3 /tmp/claude-snap.jpg &>/dev/null
sleep 0.3
```

### Change the voice

List all available macOS voices:

```bash
say -v '?'
```

Edit the `say` lines in `notify.sh`:

```bash
say -v Samantha "Your agent needs you at $TAB_NAME"
```

### Change the message

```bash
say -v Daniel "Hey, Claude needs your attention at $TAB_NAME"
```

### Narrow which events trigger the hook

By default the hook fires on all notification types. Use a `matcher` in `settings.json` to limit it to specific events:

```json
"matcher": "permission_prompt"
```

Available matchers: `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`.

---

## Troubleshooting

### Camera LED doesn't blink

- Verify imagesnap is installed: `which imagesnap` (install with `brew install imagesnap`)
- Check camera permission: **System Settings → Privacy & Security → Camera** — your terminal app must be listed and enabled
- Test manually: `imagesnap -w 0.5 /tmp/test.jpg && rm /tmp/test.jpg`
- Confirm the script is executable: `ls -la ~/.claude/hooks/camera-blink.sh`

### No voice announcement

- Test manually: `say -v Daniel "test"`
- Check that system volume isn't muted or that output isn't routed to a device that isn't playing
- Confirm `notify.sh` is executable: `chmod +x ~/.claude/hooks/notify.sh`

### Ghostty: announces "Your agent needs you" without a tab name

- Check Accessibility permission is granted: **System Settings → Privacy & Security → Accessibility** → `/usr/bin/osascript` must be listed and toggled **on**
- Test the Python helper manually from a Ghostty tab: `python3 ~/.claude/hooks/ghostty-tab-name.py /dev/$(ps -p $$ -o tty= | tr -d ' ')`
- Verify the path in `notify.sh` line 12 matches your actual username
- Make sure `ghostty-tab-name.py` is executable: `chmod +x ~/.claude/hooks/ghostty-tab-name.py`

### Hook doesn't fire at all

- Run `/hooks` inside Claude Code to reload hook configuration
- Check `~/.claude/settings.json` for JSON syntax errors: `python3 -m json.tool ~/.claude/settings.json`
- Verify all scripts are executable: `ls -la ~/.claude/hooks/`
- Check that the paths in `settings.json` are absolute (not `~`-expanded, depending on your Claude Code version)

---

## File reference

```
~/.claude/hooks/
├── camera-blink.sh        # Blinks the MacBook camera LED 5 times
├── notify.sh              # Speaks "Your agent needs you at <tab name>"
└── ghostty-tab-name.py    # Resolves Ghostty window title via OSC marker trick

~/.claude/settings.json    # Wires the hooks into Claude Code
```

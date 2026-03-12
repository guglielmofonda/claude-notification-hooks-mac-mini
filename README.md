# Claude Code Notification Hooks for Mac Mini

Voice announcements + system alerts so you always know what Claude is doing — even when you're looking away from the screen.

```
"Your agent needs you at ODF HQ"   ← needs your input
"Finished at ODF HQ"               ← completed a task
```

A macOS notification banner and system sound also fire whenever Claude needs your attention.

> Adapted from [claude-notification-hooks](https://github.com/guglielmofonda/claude-notification-hooks) (MacBook version with camera LED blink).

---

## What it does

| Event | Hook type | Signal |
|-------|-----------|--------|
| Claude needs your input (permission prompts, idle) | `Notification` | System sound + notification banner + voice: *"Your agent needs you at \<tab\>"* |
| Claude finishes a task | `Stop` | Voice: *"Finished at \<tab\>"* |

Both announcements include the name of the terminal window Claude is running in, so you know which one to switch back to when you have multiple sessions open.

---

## Requirements

### Hardware & OS
- **Mac Mini** (or any Mac without a built-in camera)
- **macOS** (tested on macOS 15 Sequoia, Apple Silicon)

### Software
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** — the Anthropic CLI this hooks into
- **Python 3** — ships with macOS, used by the Ghostty tab-name resolver
- **`say`** — built into macOS, no installation needed
- **`afplay`** — built into macOS, no installation needed

### Terminal

The tab-name announcement works with all three major macOS terminals:

| Terminal | How tab name is read | Extra setup |
|----------|---------------------|-------------|
| **Ghostty** | OSC marker + Accessibility API | Grant Accessibility to `/usr/bin/osascript` (one-time, see below) |
| **iTerm2** | `$ITERM_SESSION_ID` + AppleScript | None — works automatically |
| **Terminal.app** | AppleScript frontmost window | None — works automatically |

If you use a different terminal both hooks fall back gracefully to the announcement without a tab name (e.g. *"Finished"*).

---

## Installation

### 1. Create the hooks directory

```bash
mkdir -p ~/.claude/hooks
```

### 2. Copy the hook files

Copy these four files into `~/.claude/hooks/`:

- `alert.sh` — plays a system sound + shows a macOS notification banner
- `notify.sh` — speaks *"Your agent needs you at \<tab\>"*
- `stop.sh` — speaks *"Finished at \<tab\>"*
- `ghostty-tab-name.py` — resolves the correct Ghostty window title (Ghostty users only)

Make them executable:

```bash
chmod +x ~/.claude/hooks/alert.sh
chmod +x ~/.claude/hooks/notify.sh
chmod +x ~/.claude/hooks/stop.sh
chmod +x ~/.claude/hooks/ghostty-tab-name.py
```

### 3. Configure `~/.claude/settings.json`

Add both hooks to your Claude Code settings. Create the file if it doesn't exist:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/stop.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/alert.sh & ~/.claude/hooks/notify.sh; wait"
          }
        ]
      }
    ]
  }
}
```

> For the `Notification` hook, `&` runs alert and notify in parallel. `wait` ensures Claude Code waits for both to finish.

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

Once granted, tab names are read automatically. You can rename tabs natively in Ghostty (right-click the tab bar) and both hooks pick up the new name immediately — no shell commands needed.

---

## How the alert works

Since Mac Mini has no built-in camera, the camera LED trick from the MacBook version is replaced with two built-in macOS mechanisms:

1. **System sound** — `afplay /System/Library/Sounds/Glass.aiff` plays the Glass chime through your speakers
2. **Notification banner** — `display notification` shows a banner in the top-right corner of your screen via Notification Center

Both fire in parallel so you get immediate audio + visual feedback.

### Choosing a different sound

macOS ships with several built-in sounds. List them:

```bash
ls /System/Library/Sounds/
```

Common options: `Basso.aiff`, `Blow.aiff`, `Bottle.aiff`, `Frog.aiff`, `Funk.aiff`, `Glass.aiff`, `Hero.aiff`, `Morse.aiff`, `Ping.aiff`, `Pop.aiff`, `Purr.aiff`, `Sosumi.aiff`, `Submarine.aiff`, `Tink.aiff`.

Edit `alert.sh` to use a different sound:

```bash
afplay /System/Library/Sounds/Hero.aiff &
```

---

## Customization

### Change the voice

List all available macOS voices:

```bash
say -v '?'
```

Edit the `say` lines in `notify.sh` and `stop.sh`:

```bash
say -v Samantha "Your agent needs you at $TAB_NAME"
```

### Change the messages

In `notify.sh`:
```bash
say -v Daniel "Hey, Claude needs your attention at $TAB_NAME"
```

In `stop.sh`:
```bash
say -v Daniel "Claude is done at $TAB_NAME"
```

### Narrow which events trigger the Notification hook

By default the hook fires on all notification types. Use a `matcher` in `settings.json` to limit it:

```json
"matcher": "permission_prompt"
```

Available matchers: `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`.

---

## Troubleshooting

### No sound plays

- Test manually: `afplay /System/Library/Sounds/Glass.aiff`
- Check that system volume isn't muted
- Confirm the script is executable: `ls -la ~/.claude/hooks/alert.sh`

### No notification banner

- Check **System Settings → Notifications → Script Editor** — make sure banners are enabled
- Test manually: `osascript -e 'display notification "test" with title "test"'`

### No voice announcement

- Test manually: `say -v Daniel "test"`
- Check that system volume isn't muted
- Confirm the scripts are executable: `chmod +x ~/.claude/hooks/notify.sh ~/.claude/hooks/stop.sh`

### Ghostty: announces without a tab name

- Check Accessibility permission: **System Settings → Privacy & Security → Accessibility** → `/usr/bin/osascript` must be listed and toggled **on**
- Test the Python helper manually: `python3 ~/.claude/hooks/ghostty-tab-name.py /dev/$(ps -p $$ -o tty= | tr -d ' ')`
- Make sure `ghostty-tab-name.py` is executable: `chmod +x ~/.claude/hooks/ghostty-tab-name.py`

### Hook doesn't fire at all

- Run `/hooks` inside Claude Code to reload the configuration
- Check `~/.claude/settings.json` for JSON syntax errors: `python3 -m json.tool ~/.claude/settings.json`
- Verify all scripts are executable: `ls -la ~/.claude/hooks/`

---

## Differences from the MacBook version

| Feature | MacBook | Mac Mini |
|---------|---------|----------|
| Visual alert | Camera LED blinks 5× | macOS notification banner |
| Audio alert | — | System sound (Glass chime) |
| Voice announcement | ✓ | ✓ |
| Tab name detection | ✓ | ✓ |
| Dependencies | `imagesnap` via Homebrew | None (all built-in) |

---

## File reference

```
~/.claude/hooks/
├── alert.sh               # System sound + notification banner (replaces camera blink)
├── notify.sh              # "Your agent needs you at <tab>" (Notification hook)
├── stop.sh                # "Finished at <tab>" (Stop hook)
└── ghostty-tab-name.py    # Resolves Ghostty window title via OSC marker trick

~/.claude/settings.json    # Wires the hooks into Claude Code
```

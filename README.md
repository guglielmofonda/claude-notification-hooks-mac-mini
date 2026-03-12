# Claude Code Notification Hooks for Mac Mini

Voice announcements + a system alert so you always know what Claude is doing — even when you're looking away from the screen.

```
"Need help"   ← Claude needs your input
"Done"        ← Claude finished a task
```

A macOS notification banner and system sound also fire whenever Claude needs your attention.

> Adapted from [claude-notification-hooks](https://github.com/guglielmofonda/claude-notification-hooks) (MacBook version with camera LED blink).

---

## What it does

| Event | Hook type | Signal |
|-------|-----------|--------|
| Claude needs your input (permission prompts, idle) | `Notification` | System sound + notification banner + voice: *"Need help"* |
| Claude finishes a task | `Stop` | Voice: *"Done"* |

---

## Requirements

### Hardware & OS
- **Mac Mini** (or any Mac without a built-in camera)
- **macOS** (tested on macOS 15 Sequoia, Apple Silicon)

### Software
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** — the Anthropic CLI this hooks into
- **`say`** — built into macOS, no installation needed
- **`afplay`** — built into macOS, no installation needed

---

## Installation

### 1. Create the hooks directory

```bash
mkdir -p ~/.claude/hooks
```

### 2. Copy the hook files

Copy these three files into `~/.claude/hooks/`:

- `alert.sh` — plays a system sound + shows a macOS notification banner
- `notify.sh` — speaks *"Need help"*
- `stop.sh` — speaks *"Done"*

Make them executable:

```bash
chmod +x ~/.claude/hooks/alert.sh
chmod +x ~/.claude/hooks/notify.sh
chmod +x ~/.claude/hooks/stop.sh
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

## Customization

### Change the system sound

macOS ships with several built-in sounds. List them:

```bash
ls /System/Library/Sounds/
```

Common options: `Basso.aiff`, `Blow.aiff`, `Bottle.aiff`, `Frog.aiff`, `Funk.aiff`, `Glass.aiff`, `Hero.aiff`, `Morse.aiff`, `Ping.aiff`, `Pop.aiff`, `Purr.aiff`, `Sosumi.aiff`, `Submarine.aiff`, `Tink.aiff`.

Edit `alert.sh` to use a different sound:

```bash
afplay /System/Library/Sounds/Hero.aiff &
```

### Change the voice

List all available macOS voices:

```bash
say -v '?'
```

Edit the `say` lines in `notify.sh` and `stop.sh`:

```bash
say -v Samantha "Need help"
```

### Change the messages

In `notify.sh`:
```bash
say -v Daniel "Hey, Claude needs your attention"
```

In `stop.sh`:
```bash
say -v Daniel "All done"
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

### Hook doesn't fire at all

- Run `/hooks` inside Claude Code to reload the configuration
- Check `~/.claude/settings.json` for JSON syntax errors: `python3 -m json.tool ~/.claude/settings.json`
- Verify all scripts are executable: `ls -la ~/.claude/hooks/`

---

## File reference

```
~/.claude/hooks/
├── alert.sh       # System sound + notification banner
├── notify.sh      # "Need help" (Notification hook)
└── stop.sh        # "Done" (Stop hook)

~/.claude/settings.json    # Wires the hooks into Claude Code
```

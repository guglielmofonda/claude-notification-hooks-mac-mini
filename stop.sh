#!/bin/bash
TAB_NAME=""

if [ -n "$GHOSTTY_RESOURCES_DIR" ] || [ "$TERM_PROGRAM" = "ghostty" ]; then
    parent_pid=$$
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        parent_pid=$(ps -p "$parent_pid" -o ppid= 2>/dev/null | tr -d ' ')
        [ -z "$parent_pid" ] || [ "$parent_pid" -le 1 ] && break
        tty_val=$(ps -p "$parent_pid" -o tty= 2>/dev/null | tr -d ' ')
        if [ -n "$tty_val" ] && [ "$tty_val" != "??" ]; then
            TAB_NAME=$(python3 "$HOME/.claude/hooks/ghostty-tab-name.py" "/dev/$tty_val" 2>/dev/null)
            break
        fi
    done

elif [ "$TERM_PROGRAM" = "iTerm.app" ] && [ -n "$ITERM_SESSION_ID" ]; then
    TAB_NAME=$(osascript -e 'tell application "iTerm2"
        set sid to (system attribute "ITERM_SESSION_ID")
        repeat with w in windows
            repeat with t in tabs of w
                repeat with s in sessions of t
                    if unique id of s = sid then return name of t
                end repeat
            end repeat
        end repeat
    end tell' 2>/dev/null)

elif [ "$TERM_PROGRAM" = "Apple_Terminal" ]; then
    TAB_NAME=$(osascript -e 'tell application "Terminal" to name of selected tab of front window' 2>/dev/null)
fi

if [ -n "$TAB_NAME" ]; then
    say -v Daniel "Finished at $TAB_NAME"
else
    say -v Daniel "Finished"
fi

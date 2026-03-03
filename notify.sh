#!/bin/bash
TAB_NAME=""

if [ "$TERM_PROGRAM" = "iTerm.app" ] && [ -n "$ITERM_SESSION_ID" ]; then
    # Precisely find the session by its unique ID — not affected by window focus
    TAB_NAME=$(osascript <<'APPLESCRIPT' 2>/dev/null
tell application "iTerm2"
    set sid to (system attribute "ITERM_SESSION_ID")
    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                if unique id of s = sid then
                    return name of t
                end if
            end repeat
        end repeat
    end repeat
end tell
APPLESCRIPT
)
elif [ "$TERM_PROGRAM" = "Apple_Terminal" ]; then
    # Best-effort: get the front window's selected tab name
    TAB_NAME=$(osascript -e 'tell application "Terminal" to name of selected tab of front window' 2>/dev/null)
fi

if [ -n "$TAB_NAME" ]; then
    say -v Daniel "Your agent needs you at $TAB_NAME"
else
    say -v Daniel "Your agent needs you"
fi

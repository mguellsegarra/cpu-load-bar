on run argv
    set mountPath to item 1 of argv
    set diskFolder to (POSIX file mountPath) as alias
    set backgroundFile to (POSIX file (mountPath & "/.background/background.png")) as alias

    tell application "Finder"
        tell folder diskFolder
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {200, 160, 840, 560}

            tell icon view options of container window
                set icon size to 112
                set text size to 13
                set arrangement to not arranged
                set background picture to backgroundFile
            end tell

            set position of item "CPU Load Bar.app" of container window to {166, 175}
            set position of item "Applications" of container window to {474, 175}
            update without registering applications
            close
        end tell
    end tell
end run

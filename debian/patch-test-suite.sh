#!/bin/sh

set -e

TEST=Test/C02cond.ztst

if [ "$1" = "--reverse" ]; then
    TTY="$2"

    # Unpatch
    if [ "$TTY" = "/dev/tty" ]; then
        exit 0;
    elif [ -n "$TTY" ]; then
        echo "Replacing $TTY with /dev/tty in $TEST"
        sed -e "s:$TTY:/dev/tty:" -i $TEST || true
    else
        echo "Patch back in that check that needs /dev/tty. (Failures are ok.)"
        patch -R -f --no-backup-if-mismatch -F0 -r- -s -p1 < debian/patches/disable-tests-which-need-dev-tty.patch || true
    fi
else
    TTY="$1"

    if [ "$TTY" = "/dev/tty" ]; then
        # Sanity check
        if [ -c /dev/tty ]; then
            echo "/dev/tty exists and is a character device, hence no patching needed."
            exit 0;
        else

            echo "$MAKE's -c test in debian/rules said /dev/tty is"
            echo "a character device, but $0's checks says it's not:"
            ls -l /dev/tty
            exit 1
        fi
    elif [ -n "$TTY" ]; then
        echo "Replacing /dev/tty with $TTY in $TEST"
        sed -e "s:/dev/tty:$TTY:" -i $TEST
    else
        echo "Huh? No character device named tty* found at all in /dev/"
        # Reality check
        find /dev/ -name 'tty*' -type c || true

        echo "Well, then let's patch out that check that needs"
        echo "/dev/tty to be a character device."

        patch -f --no-backup-if-mismatch -F0 -r- -s -p1 < debian/patches/disable-tests-which-need-dev-tty.patch
    fi
fi

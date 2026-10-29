# NOTE:
# - `adb exec-out` (backup) & `adb shell -T ... < file` (restore) stream raw binary without pty.
# - `su --no-pty` & `adb -T` are required to prevent PTY ONLCR CRLF corruption on binary streams.
# apatch seem to be allocating pty

##--------------------------------------/data/local/tmp/archl
###------------------------Quick
#### backup
adb exec-out su --no-pty -c 'tar --numeric-owner --sparse -cf - -C /data/local/tmp .' > tmp-backup.tar
# restore
adb shell -T 'su --no-pty -c "tar --numeric-owner --sparse -xpf - -C /data/local/tmp"' < tmp-backup.tar

##--------------------------------------/data/media/0
# backup
adb exec-out su --no-pty -c 'tar --numeric-owner --selinux --sparse -cf - -C /data/media/0 .' > media0-backup.tar
# restore
adb shell -T 'su --no-pty -c "tar --numeric-owner --selinux --sparse -xpf - -C /data/media/0"' < media0-backup.tar

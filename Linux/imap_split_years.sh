###################################################################
# Copyright (c) 2025 AdrenSnyder https://github.com/adrensnyder
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# DISCLAIMER:
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
###################################################################

#!/bin/bash

# The cur you want to split in years
MAILDIR="/home/[ACCOUNT_ORIG]/Maildir/cur"
# The destination Maildir
DEST_BASE="/home/[ACCOUNT_DEST]/Maildir"
# Base mailbox. (Ex. .INBOX)
DEST_MAILBOX="$DEST_BASE/[.MAILBOX]"
# Permissions (Ex. accountname:users)
RSYNC_OWNER="[user]:[group]"  
# If set the mails after this date will be ignored. (Ex. 2025-07-06)
CUTOFF_DATE=""
# The tmp file to save the copied Message-Id. If a message contain the same Id will be ignored
ID_LIST="/tmp/copied_ids.txt"

# Main
if [[ -n "$CUTOFF_DATE" ]]; then
    cutoff_ts=$(date -d "$CUTOFF_DATE" +%s)
fi

if [[ -n "$ID_LIST" ]]; then
    [ -f "$ID_LIST" ] && rm -f "$ID_LIST"
    touch "$ID_LIST"
fi

last_year=""

find "$MAILDIR" -type f | while read -r file; do
    if [[ -n "$cutoff_ts" ]]; then
        file_ts=$(stat -c %Y "$file")
        [[ "$file_ts" -ge "$cutoff_ts" ]] && continue
    fi

    msgid=$(grep -i -m1 '^Message-Id:' "$file" | sed -E 's/^[Mm]essage-[Ii]d:[[:space:]]*//I' | tr -d '\r')

    if [[ -n "$msgid" ]] && grep -Fxq "$msgid" "$ID_LIST"; then
        continue
    fi

    year=$(date -r "$file" +"%Y")

    if [[ "$year" != "$last_year" ]]; then
        dest_maildir="$DEST_MAILBOX.$year"
        mkdir -p "$dest_maildir/cur" "$dest_maildir/new" "$dest_maildir/tmp"
        chown -R "$RSYNC_OWNER" "$dest_maildir"
        last_year="$year"
        echo "YEAR: $year"
        echo "PATH: $dest_maildir/cur"
    fi

    if rsync -a --chown="$RSYNC_OWNER" "$file" "$dest_maildir/cur/"; then
        [[ -n "$msgid" ]] && echo "$msgid" >> "$ID_LIST"
    fi
done

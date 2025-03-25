###################################################################
# Copyright (c) 2023 AdrenSnyder https://github.com/adrensnyder
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


#!/bin/sh

LOGPATH=$1
RED='\033[0;31m'
NC='\033[0m' # No Color

if [[ "X$LOGPATH" == "X" ]]; then
    echo "Enter a valid path for migration logs"
    echo "Ex. /var/log/imapsync/job/data"
    exit
fi

if [ ! -d $LOGPATH ]; then
        echo "Enter a valid path for migration logs"
        echo "Ex. /var/log/imapsync/job/data"
    exit
fi

LIST=$(ls -1 $LOGPATH/*%*)

LIST_NEW=""
LIST_UNIQUE=""
for file in $LIST; do
    EMAIL=`echo $file | awk -F '%' '{ print $1 }'`
    LIST_NEW="$LIST_NEW $EMAIL"
done

LIST_UNIQUE=`echo $LIST_NEW | tr ' ' '\n' | sort -u`

MESSAGESOK_COUNT=0
GOOD_COUNT=0
NOTSTRICT_COUNT=0
NOTFINISHED_COUNT=0

LASTLOGS=()  # inizializza array
echo -e "- ${RED}File list${NC}"

for file in $LIST_UNIQUE; do
    ((COUNT_LIST++))
    LASTLOG=$(ls -1 -r "$LOGPATH/$file%"* | head -n1)
    [[ -n "$LASTLOG" ]] && LASTLOGS+=("$LASTLOG")

    echo "$file -> $LASTLOG"
done
echo "----"

for file in "${LASTLOGS[@]}"; do

    MESSAGESOK=$(grep -a "Messages found in host1 not in host2" "$file"|grep ": 0 messages" |wc -l)
    GOOD=$(grep -a "The sync looks good" "$file"|wc -l)
    NOTSTRICT=$(grep -a "The sync is not strict" "$file"| wc -l)
    NOTFINISHED=$(grep -a "The sync is not finished" "$file"|wc -l)

        if [ "$MESSAGESOK" -gt "0" ]; then
                let "MESSAGESOK_COUNT=MESSAGESOK_COUNT+1"
        fi

    if [ "$GOOD" -gt "0" ]; then
        let "GOOD_COUNT=GOOD_COUNT+1"
    fi

    if [ "$NOTFINISHED" -gt "0" ]; then
        let "NOTFINISHED_COUNT=NOTFINISHED_COUNT+1"
    fi

    if [[ "$NOTSTRICT" -gt "0" && "$GOOD" -eq "0" && "$NOTFINISHED" -eq "0" ]]; then
        let "NOTSTRICT_COUNT=NOTSTRICT_COUNT+1"
    fi

done

ALL_GOOD_NOTFINISHED=`grep -a "Exiting with return value" $LOGPATH/* |wc -l`

echo -e "- ${RED}General Stats${NC}"
echo "Total emails in check: $COUNT_LIST"
echo "Emails with all messages copied and in sync:"
echo "- Tag 'The sync looks good: $GOOD_COUNT"
echo "- Tag 'Messages found in host1 not in host2 : 0 messages': $MESSAGESOK_COUNT"
echo "Emails copied but with some additional messages in host2 (Only if a unique warning): $NOTSTRICT_COUNT"
echo "Emails with some elements not copied: $NOTFINISHED_COUNT"
echo "Total emails copied, complete or with errors: $ALL_GOOD_NOTFINISHED"

echo "----"
echo -e "${RED}Emails not completed:${NC}"

for file in "${LASTLOGS[@]}"; do
    GREP_COLORS='fn=01;34:ln=01;32:mt=01;35' grep -a --colour -iTHn "The sync is not finished" "$file"
done

echo "----"
echo -e "${RED}- CHECK ERROR LOGIN${NC}"

for file in "${LASTLOGS[@]}"; do
    GREP_COLORS='fn=01;34:ln=01;32:mt=01;35' grep -a --colour -iTHn "Error login" "$file"
done
echo "----"
echo -e "${RED}- CHECK BAD USER (O365)${NC}"

for file in "${LASTLOGS[@]}"; do
    GREP_COLORS='fn=01;34:ln=01;32:mt=01;35' grep -a --colour -iTHn "bad user" "$file"
done
echo "----"
echo -e "${RED}- CHECK EX_OK${NC}"
EXOK_COUNT=0

for file in "${LASTLOGS[@]}"; do
    EXOK=`grep -a -i "EX_OK" "$file"|wc -l`
    if [ "$EXOK" -gt "0" ]; then
        let "EXOK_COUNT=EXOK_COUNT+1"
    fi
done
echo $EXOK_COUNT
echo -e "${RED}- CHECK EXIT_ERR_APPEND${NC}"

for file in "${LASTLOGS[@]}"; do
    GREP_COLORS='fn=01;34:ln=01;32:mt=01;35' grep -a --colour -iTHn "EXIT_ERR" "$file"
    GREP_COLORS='fn=01;34:ln=01;32:mt=01;35' grep -a --colour -iTHn "Maximum number of errors.*reached|reached.*Maximum number of errors" "$file"
done
echo -e "${RED}- CHECK Err${NC}"

for file in "${LASTLOGS[@]}"; do
    GREP_COLORS='fn=01;34:ln=01;32:mt=01;35' grep -a --colour -iTHn -E 'msg.*Err |Err .*msg' "$file"
done
echo -e "${RED}- CHECK skipped${NC}"

for file in "${LASTLOGS[@]}"; do
    GREP_COLORS='fn=01;34:ln=01;32:mt=01;35' grep -a --colour -iTHn -E 'msg.*skipped|skipped.*msg' "$file"
done
echo -e "${RED}- CHECK Status${NC}"

for file in "${LASTLOGS[@]}"; do
        GREP_RESULT=""
        GREP_RESULT=`grep -a --colour -iTHn -E 'Exiting with return value' "$file" |wc -l`
        if [ "$GREP_RESULT" -eq "0" ]; then
                PS_TEST=`ps auxwf |grep -a imapsync |grep "$file"|wc -l`
                if [ "$PS_TEST" -gt "0" ]; then
                        echo "--> "$file" Imapsync process is running"
                else
                        echo "--> "$file" Not completed. Probably terminated cause of an 'Out of memory' error. Try to limit attachments size with --maxsize 150_000_000"
                fi
        else
                GREP_COLORS='fn=01;34:ln=01;32:mt=01;35' grep -a --colour -iTHn -E 'Exiting with return value' "$file"
        fi

done

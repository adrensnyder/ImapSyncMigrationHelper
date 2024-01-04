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

# Use at last python3.8. You can install and set the correct path of the executable like /opt/rh/rh-python38/root/usr/bin/python
PYTHON="/usr/bin/python"

# NOTE:
# You can use PARAMETER1 to declare another token name if use more than one
#
# To create the token, run python38 mutt_oauth2.py $TOKEN_NAME_token_auth --verbose --authorize
# Or /opt/rh/rh-python38/root/usr/bin/python depending on how Python is installed
# Select: microsoft, localhostauth, admin@domain.com
# 1 - Copy the link to the browser with the mentioned user's login.
# 2 - It will result in an error as the page http://localhost:XXXX/XXXXX won't be found.
#     Copy that path from the console where mutt was started and type
#     curl "copied_link"

AT=`which at 2>/dev/null`
if [ "$?" -ne "0" ]; then
    echo "Install first latest version of at command"
    exit
fi

if [ ! -f main.conf ]; then
    echo "File main.conf missing. Redownload it from GIT"
    exit
fi

# Load configuration
source main.conf

# If declared it will ignore the JOBNAME variable
TOKEN_NAME=$1

# Program
me=`basename "$0"`
PROJECTPATH="$JOBPATH/$JOBNAME"
if [[ "X$TOKEN_NAME" == "X" ]]; then
	TOKEN_NAME=$JOBNAME
fi
RETOKEN=retoken_$TOKEN_NAME
MUTT=$PROJECTPATH/$MUTT

cd $PROJECTPATH

DATETIME=`jq '.access_token_expiration' "$TOKEN_NAME"_token_auth`

#"2022-10-21T11:14:30.986119"
DATETIME=`echo "${DATETIME/\"/}"`
DATETIME=`echo "${DATETIME/T/ }"`

DATE=`echo $DATETIME | awk '{ print $1 }' `
TIMEFULL=`echo $DATETIME | awk '{ print $2 }'`

TIMEH=`echo $TIMEFULL | awk -F  ':' '{ print $1 }'`
TIMEM=`echo $TIMEFULL | awk -F  ':' '{ print $2 }'`
TIMESFULL=`echo $TIMEFULL | awk -F  ':' '{ print $3 }'`
TIMES=`echo $TIMESFULL | awk -F '.' '{ print $1 }'`
let "TIMES=TIMES+10"

TIME="$TIMEH:$TIMEM"

#echo $TIME $DATE

# Create the token immediately
$PYTHON $MUTT "$TOKEN_NAME"_token_auth > $PROJECTPATH/"$TOKEN_NAME"_token_imapsync

# (retoken) Request the token immediately
echo "$PYTHON $MUTT ""$TOKEN_NAME""_token_auth > $PROJECTPATH/""$TOKEN_NAME""_token_imapsync" > $PROJECTPATH/$RETOKEN.sh
# (retoken) Request the token after $TIMES seconds
echo "sleep $TIMES" >> $PROJECTPATH/$RETOKEN.sh
echo "$PYTHON $MUTT ""$TOKEN_NAME""_token_auth > $PROJECTPATH/""$TOKEN_NAME""_token_imapsync" >> $PROJECTPATH/$RETOKEN.sh
# (retoken) Request the token again after 60 seconds for additional security
echo sleep 60 >> $PROJECTPATH/$RETOKEN.sh
echo "$PYTHON $MUTT ""$TOKEN_NAME""_token_auth > $PROJECTPATH/""$TOKEN_NAME""_token_imapsync" >> $PROJECTPATH/$RETOKEN.sh
# (retoken) Wait for 60 seconds before creating the new job
echo sleep 60 >> $PROJECTPATH/$RETOKEN.sh
# (retoken) Schedule the creation of the new at job
echo "$PROJECTPATH/$me" >> $PROJECTPATH/$RETOKEN.sh
# (retoken) Assign execution rights
chmod 777 $PROJECTPATH/$RETOKEN.sh

# (retoken) Create the at job file
echo "$PROJECTPATH/$RETOKEN.sh" > $PROJECTPATH/$RETOKEN-job.txt

# (retoken-job.txt) Activate the job with at
$AT $TIME $DATE < $PROJECTPATH/$RETOKEN-job.txt

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

RETOKEN_NAME=$1

if [ "X$RETOKEN_NAME" == "X" ]; then
	echo "Enter the full path and name of the file retoken_client.sh"
	exit
fi

if [ ! -f "$RETOKEN_NAME" ]; then
	echo "The file $RETOKEN_NAME not exist"
	exit
fi	

DIRNAME=`dirname $RETOKEN_NAME`

LISTJOBS=`atq | awk '{ print $1 }'`

for job in $LISTJOBS; do
	TEST=`at -c $job|grep $RETOKEN_NAME|wc -l`
	if [ "$TEST" -gt "0" ]; then
		JOBOK=`atq |grep $job`
		MONTH=`echo $JOBOK| awk '{ print $3 }'`	
		DAY=`echo $JOBOK| awk '{ print $4 }'`
		HOUR_FULL=`echo $JOBOK| awk '{ print $5 }'`
		HOUR=`echo $HOUR_FULL| awk -F ':'  '{ print $1 }'`
		MIN=`echo $HOUR_FULL| awk -F ':' '{ print $2 }'`
			
		ATTIME="$HOUR:$MIN $MONTH $DAY"
		
	fi
done

echo "sleep 60" > "$DIRNAME/cronjob.txt"
echo "$DIRNAME/imapsync.sh &" >> "$DIRNAME/cronjob.txt"

at $ATTIME < "$DIRNAME/cronjob.txt"

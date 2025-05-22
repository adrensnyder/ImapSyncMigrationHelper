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

#!/bin/bash

# PROGRAMS
CAT=`which cat 2>/dev/null`
AWK=`which awk 2>/dev/null`
YUM=`which yum 2>/dev/null`
MKDIR=`which mkdir 2>/dev/null`

IMAPSYNC=`which imapsync 2>/dev/null`
if [ "$?" -ne "0" ]; then
    echo "Install first latest version of imapsync"
    exit
fi

if [ ! -f main.conf ]; then
    echo "File main.conf missing. Redownload it from GIT"
    exit	
fi

# Load configuration
source main.conf

DATE=`which date 2>/dev/null`
DATENOW=$($DATE '+%Y-%m-%d_%H%M%S')

PROJECTPATH="$JOBPATH/$JOBNAME"
EXECS="Execs"

FILE_RUN="$FILE_RUN$DATENOW"
FILE_CREDS="$JOBPATH/$JOBNAME/$FILE_CREDS"

LOGDIR="$LOGDIR/$JOBNAME/$DATENOW"

# Initial checks
if [ ! -d "$PROJECTPATH" ]; then
    echo "All GIT files have to be copied in $PROJECTPATH folder. The folder has been created now"
    $MKDIR -p $PROJECTPATH
    exit
fi

# Enter in project path
cd $PROJECTPATH

# Check files
FILES_NEEDED="atstart.sh check_migration.sh create_next_schedule.sh main.conf mutt_oauth2.py mail_list"
FILES_MISSING=""
for files_needed in $FILES_NEEDED; do
    if [ ! -f "$files_needed" ]; then
	FILES_MISSING="$FILES_MISSING $files_needed"
    fi
done

if [ "X$FILES_MISSING" != "X" ]; then
	echo "Missing files in path $PROJECTPATH:$FILES_MISSING"
	echo "Please copy all the GIT files in the folder $PROJECTPATH"
	exit
fi

# Parsing options
ERRORS_VARS=0
if [[ "X$JOBNAME" == "X" ]]; then
	echo "Change variable name JOBNAME"
	ERRORS_VARS=1
fi

if [ ! -f $FILE_CREDENTIALS ]; then
	echo "File $FILE_CREDS missing"
	ERRORS_VARS=1
fi

if [[ "X$IP_SOURCE" == X || "X$IP_DEST" == X ]]; then
	echo "Missing IP_SOURCE or IP_DEST variable"
	ERRORS_VARS=1
fi

if [ "$ERRORS_VARS" -eq "1" ]; then
	exit
fi

if [ "$LISTFOLDERS" -eq "1" ]; then
    LOGDIR="$LOGDIR""_listforders"
fi

if [ "$ADDHEADER" -eq "1" ]; then
    if [[ "X$PARAM" == "X" ]]; then
    	PARAM="--addheader"
    else
        PARAM="$PARAM --addheader"
    fi
fi

if [ "$DRY" -eq "1" ]; then
    if [[ "X$PARAM" == "X" ]]; then
   		PARAM="--dry"
    else
        PARAM="$PARAM --dry"
    fi
fi

if [ "$LISTFOLDERS" -eq "1" ]; then
    if [[ "X$PARAM" == "X" ]]; then
    	PARAM="--justfoldersizes"
    else
        PARAM="$PARAM --justfoldersizes"
    fi
fi

if [ "$AUTOMAP" -eq "1" ]; then
    if [[ "X$PARAM" == "X" ]]; then
    	PARAM="--automap"
    else
        PARAM="$PARAM --automap"
    fi
fi

if [ "$DISABLEREADCONFIRM" -eq "1" ]; then
    if [[ "X$PARAM" == "X" ]]; then
		PARAM="--disarmreadreceipts"
    else
        PARAM="$PARAM --disarmreadreceipts"
    fi
fi

if [[ "$OFFICE365_SOURCE" -eq "1" || "$OFFICE365_DEST" -eq "1" ]]; then
	if [[ "X$PARAM" == "X" ]]; then
		PARAM="--maxmessagespersecond 4 --f1f2 \"Files=Files_renamed_by_imapsync\" --regexmess \"s,(.{10239}),\\\$1\r\n,g\""
	else
		PARAM="$PARAM --maxmessagespersecond 4 --f1f2 \"Files=Files_renamed_by_imapsync\" --regexmess \"s,(.{10239}),\\\$1\r\n,g\""	
	fi
fi
	
if [ "$OFFICE365_SOURCE" -eq "1" ]; then
	if [[ "X$PARAM" == "X" ]]; then
		#PARAM="--office1" # Rimosso in quanto alcuni valori come maxsize li configuriamo già a 150m e qui vengono limitati a 45m
		PARAM="--ssl1"
	else
		#PARAM="$PARAM --office1" # Rimosso in quanto alcuni valori come maxsize li configuriamo già a 150m e qui vengono limitati a 45m
		PARAM="$PARAM --ssl1"
	fi
fi

if [ "$OFFICE365_DEST" -eq "1" ]; then
    if [[ "X$PARAM" == "X" ]]; then
    	#PARAM="--office2" # Rimosso in quanto alcuni valori come maxsize li configuriamo già a 150m e qui vengono limitati a 45m
		PARAM="--ssl2"	
    else
        #PARAM="$PARAM --office2" # Rimosso in quanto alcuni valori come maxsize li configuriamo già a 150m e qui vengono limitati a 45m
		PARAM="$PARAM --ssl2"
    fi
fi

TOKEN_ORIG="$PROJECTPATH/$TOKEN_ORIG"
TOKEN_DEST="$PROJECTPATH/$TOKEN_DEST"
TOKEN=0

if [[ "X$TOKEN_ORIG" != "X" ]]; then
    if [ -f "$TOKEN_ORIG" ]; then
    	if [[ "X$PARAM" == "X" ]]; then
        	PARAM="--oauthaccesstoken1 $TOKEN_ORIG"
        else
            PARAM="$PARAM --oauthaccesstoken1 $TOKEN_ORIG"
        fi
		TOKEN=1
    fi
fi

if [[ "X$TOKEN_DEST" != "X" ]]; then
    if [ -f "$TOKEN_DEST" ]; then
    	if [[ "X$PARAM" == "X" ]]; then
        	PARAM="--oauthaccesstoken2 $TOKEN_DEST"
        else
            PARAM="$PARAM --oauthaccesstoken2 $TOKEN_DEST"
        fi
		TOKEN=1
    fi
fi

if [[ "X$MAXSIZE" != "X" ]]; then
	PARAM="$PARAM --maxsize $MAXSIZE"
fi

if [[ "X$MAXLINE" != "X" ]]; then
	PARAM="$PARAM --maxlinelength $MAXLINE"
fi

if [ ! -d $LOGDIR ]; then
	$MKDIR -p $LOGDIR > /dev/null
fi

PORT_TAG_SOURCE=""
PORT_TAG_DEST=""
SSL_TAG_SOURCE=""
SSL_TAG_DEST=""

if [ "$?" -ne "0" ]; then
	echo "Imapsync not found, and it was not possible to install it. Install the package manually!"
	exit
fi

if [[ "$SSL_SOURCE" -eq "1" && "$TLS_SOURCE" -eq "1" ]]; then
	echo "Do not enable SSL and TLS simultaneously for a single host"
	exit
fi

if [[ "$SSL_DEST" -eq "1" && "$TLS_DEST" -eq "1" ]]; then
    echo "Do not enable SSL and TLS simultaneously for a single host"
    exit
fi

if [ "$OFFICE365_SOURCE" -eq "0" ]; then
	if [ "$SSL_SOURCE" -eq "1" ]; then
		SSL_TAG_SOURCE="--ssl1"
	else
		SSL_TAG_SOURCE="--nosslcheck"
	fi
fi

if [ "$OFFICE365_DEST" -eq "0" ]; then
	if [ "$SSL_DEST" -eq "1" ]; then
		SSL_TAG_DEST="--ssl2"
	else
		SSL_TAG_DEST="--nosslcheck"
	fi
fi

if [ "$TLS_SOURCE" -eq "1" ]; then
        TLS_TAG_SOURCE="--tls1"
else
        TLS_TAG_SOURCE="--notls1"
fi

if [ "$TLS_DEST" -eq "1" ]; then
        TLS_TAG_DEST="--tls2"
else
        TLS_TAG_DEST="--notls2"
fi

if [[ "X$PORT_SOURCE" != "X" ]]; then
	PORT_TAG_SOURCE="--port1 $PORT_SOURCE"
fi

if [[ "X$PORT_DEST" != "X" ]]; then
	PORT_TAG_DEST="--port2 $PORT_DEST"
fi

VAR_CREDS=`$CAT $FILE_CREDS`

# Add @
if [[ "X$DOMAIN_SOURCE" != "X" ]]; then
        DOMAIN_SOURCE="@$DOMAIN_SOURCE"
fi
if [[ "X$DOMAIN_DEST" != "X" ]]; then
        DOMAIN_DEST="@$DOMAIN_DEST"
fi

if [ ! -d "Execs" ]; then
   mkdir "Execs"
fi

EXEC_FOLDER="$EXECS/Exec_$DATENOW"

if [ ! -d "$EXEC_FOLDER" ]; then
    mkdir -p "$EXEC_FOLDER"
fi

if [[ "X$TOKEN_JOB" == "X" ]]; then
	TOKEN_JOB=$JOBNAME
fi

# Start JOB

LINES=($(grep -vE '^#' "$FILE_CREDS" |wc -l))
DIGITS=${#LINES}

COUNT=0

IFS=$'\n'
for line in $VAR_CREDS; do
	if [[ $line =~ ^# ]]; then
    	continue
    fi

    ((COUNT++))

    PADDED=$(printf "%0${DIGITS}d" "$COUNT")
    FILE_RUN_BASE="$PADDED""_""$FILE_RUN"

    #echo "---"

	MAIL_SOURCE=`echo $line| $AWK '{ print $1 }'`
    PASS_SOURCE=`echo $line| $AWK '{ print $2 }'`

	MAIL_DEST=""
	PASS_DEST=""

	MAIL_DEST=`echo $line| $AWK '{ print $3 }'`
	PASS_DEST=`echo $line| $AWK '{ print $4 }'`

	if [[ "$MAIL_DEST" == "" ]]; then
		MAIL_DEST=$MAIL_SOURCE
		PASS_DEST=$PASS_SOURCE
	fi
		
	PASS_SOURCE_OK="\"$PASS_SOURCE\""
	if [ "$PASS_COMP_ORIG" -eq "1" ]; then
		PASS_SOURCE_OK="'"'"'$PASS_SOURCE'"'"'"
	fi
	PASS_DEST_OK="\"$PASS_DEST\""
	if [ "$PASS_COMP_DEST" -eq "1" ]; then
		PASS_DEST_OK="'"'"'$PASS_DEST'"'"'"
	fi

    # Creation of a file with the imapsync startup string
    echo "#!/bin/sh" > "$EXEC_FOLDER/$FILE_RUN_BASE-$MAIL_SOURCE.sh"
    echo "" >> "$EXEC_FOLDER/$FILE_RUN_BASE-$MAIL_SOURCE.sh"
	echo 'DATE_NOW=$(date +"%Y-%m-%d_%H-%M")' >> "$EXEC_FOLDER/$FILE_RUN_BASE-$MAIL_SOURCE.sh"
    echo "$IMAPSYNC $PARAM --host1 $IP_SOURCE --user1 \"$MAIL_SOURCE$DOMAIN_SOURCE\" --password1 $PASS_SOURCE_OK $SSL_TAG_SOURCE $TLS_TAG_SOURCE $PORT_TAG_SOURCE --host2 $IP_DEST --user2 \"$MAIL_DEST$DOMAIN_DEST\" --password2 $PASS_DEST_OK $SSL_TAG_DEST $TLS_TAG_DEST $PORT_TAG_DEST --logdir $LOGDIR --logfile \"$LOGFILE$MAIL_SOURCE""_$COUNT"'%$DATE_NOW'\" >> "$EXEC_FOLDER/$FILE_RUN_BASE-$MAIL_SOURCE.sh"

    # Granting execution rights for the file
    chmod 777 "$EXEC_FOLDER/$FILE_RUN_BASE-$MAIL_SOURCE.sh"

    if [ "$TOKEN" -eq "1" ]; then

    	$CAT << EOF >> "$EXEC_FOLDER/$FILE_RUN_BASE-$MAIL_SOURCE.sh"

TEST=\`ps auxw |grep ATE-$MAIL_SOURCE.sh|grep -v grep| wc -l\`

if [ "\$TEST" -gt 0 ]; then
        exit
fi

EOF
		if [[ "$LISTFOLDERS" -eq "0" && "$DRY" -eq "0" ]]; then
                	echo "$PROJECTPATH/$EXEC_FOLDER/$FILE_RUN_BASE-ATE-$MAIL_SOURCE.sh &" >> "$EXEC_FOLDER/$FILE_RUN_BASE-$MAIL_SOURCE.sh"
		fi

        $CAT << EOF > "$EXEC_FOLDER/$FILE_RUN_BASE-ATE-$MAIL_SOURCE.sh"
#!/bin/sh

NUM_PROCESS=$NUM_PROCESS

# Check for the latest log file, and if it exists, perform a safety search using 'ls' in case nothing is found
LASTLOG=\`ls -1 -r "$LOGDIR$LOGFILE/$MAIL_SOURCE"* |head -n1\`
if [ ! -f "\$LASTLOG" ]; then
        exit
fi

# Check if 'AccessTokenExpired' is present in the log
ATE=\`grep -a AccessTokenExpired "\$LASTLOG" |wc -l\`
BYE=\`grep -a "BYE Connection closed" "\$LASTLOG" |wc -l\`

SYNC_LINE=\`grep -a "Folders synced" "\$LASTLOG" |awk '{ print \$4}'\`
if [ "X\$SYNC_LINE" == "X" ]; then
        exit
fi

FOLDERS_SOURCE=\`echo \$SYNC_LINE |awk -F '/' '{ print \$1 }'\`
FOLDERS_DEST=\`echo \$SYNC_LINE |awk -F '/' '{ print \$2 }'\`

if [ "\$FOLDERS_SOURCE" == "\$FOLDERS_DEST" ]; then
        exit
fi

if [[ "\$ATE" -gt 0 || "\$BYE" -gt 0 ]]; then
        # "Restart $EXEC_FOLDER/$FILE_RUN_BASE-$MAIL_SOURCE"
        echo -ne "Waiting for 1 minute before starting the new process $FILE_RUN_BASE-$MAIL_SOURCE.sh\r"
        sleep 60

        PROCESS_LIST=\`ps auxw |grep $IMAPSYNC|grep -v grep|wc -l\`

        while [ "\$PROCESS_LIST" -ge "\$NUM_PROCESS" ]; do
                echo -ne "Waiting for 10 seconds. Found \$PROCESS_LIST processes $IMAPSYNC running\r"
                sleep 10
                PROCESS_LIST=\`ps auxw |grep $IMAPSYNC|grep -v grep|wc -l\`
        done

        $PROJECTPATH/$EXEC_FOLDER/$FILE_RUN_BASE-$MAIL_SOURCE.sh &
fi

EOF

            # Concessione diritti di avvio per il file
            chmod 777 "$EXEC_FOLDER/$FILE_RUN_BASE-ATE-$MAIL_SOURCE.sh"

        fi

done

LIST_RUN=`ls -1 "$EXEC_FOLDER/"*  |grep -v '\-ATE\-'`
LIST_RUN_COUNT=`ls -1 "$EXEC_FOLDER/"*  |grep -v '\-ATE\-' |wc -l`
COUNT=0

for file in $LIST_RUN; do
	PROCESS_LIST_ATE=`ps auxw |grep '\-ATE\-'|grep -v grep|wc -l`
	PROCESS_LIST=`ps auxw |grep $IMAPSYNC|grep -v grep|wc -l`
	while [[ "$PROCESS_LIST" -ge "$NUM_PROCESS" || "$PROCESS_LIST_ATE" -gt "0" ]]; do
		if [ "$LISTFOLDERS" -eq "0" ]; then
			echo -ne "Waiting for 1 minute. Found $PROCESS_LIST processes $IMAPSYNC running\r"
			sleep 60
		else
			echo -ne "Waiting for 5 seconds. Found $PROCESS_LIST processes $IMAPSYNC running\r"
            sleep 5
		fi
		PROCESS_LIST_ATE=`ps auxw |grep '\-ATE\-'|grep -v grep|wc -l`
	    PROCESS_LIST=`ps auxw |grep $IMAPSYNC|grep -v grep|wc -l`
	done

	DATE_TIME=$($DATE '+%Y-%m-%d %H:%M')

	DATE_TIME=$($DATE '+%Y-%m-%d %H:%M')

    let "COUNT=COUNT+1"
    echo "$DATE_TIME ($COUNT/$LIST_RUN_COUNT - Running processes: $PROCESS_LIST): $file started"

    TEST=`ps auxw |grep $file|grep -v grep| wc -l`

    if [ "$TEST" -gt 0 ]; then
    	echo -ne "Waiting 5 seconds. I will proceed to the next job since the file $file is already present\r"
        sleep 5
        continue
    fi

    $file >/dev/null 2>/dev/null &
    if [ "$COUNT" -lt "$LIST_RUN_COUNT" ]; then
    	sleep 5
    fi
done

unset IFS

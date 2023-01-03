#!/bin/bash
#
# Command line interface for uploading to Strava.com
#
# Based on https://github.com/mpolla/stravaup
#
# Kim Wall kim@ductilebiscuit.net

# Devices to add "with barometer" to the creator tag of (this has not been tested on TCX files):
TCX_BAROMETERS=()
GPX_BAROMETERS=("eTrex 30" "eTrex 32x")

# Exit if something fails
set -e

# First run
if [ ! -f "${HOME}/.stravauprc" ]; then
    echo "To use the stravaup script, please to to https://www.strava.com/settings/api"
    echo "and register your own application to get a client id. Then create a file ~/.stravauprc containing"
    echo "  STRAVAUP_CLIENT_ID = [insert your own]"
    echo "  STRAVAUP_CLIENT_SECRET = [insert your own]"
    exit
fi
. "${HOME}/.stravauprc"

# Show useage
if [ $# -lt 1 ]; then
    echo "Usage: strava_upload.sh [options] file"
    echo "GPX, TCX and FIT files are supported (they may also be gzipped, eg. foobar.gpx.gz)"
    echo "Permitted command line options are:"
    echo " -a, --activity-type=type             One of ride, run, swim, workout, hike, walk, ebikeride, virtualride, etc."
    echo " -A, --archive=\"dir\"                  Save a copy of the file in directory"
    echo " -c, --commute                        Activity is a commute"
    echo " -d, --description=\"Description\"      Activity description"
    echo " -n, --name=\"Name\"                    Activity name"
    echo " -s, --silent                         Surpress status messages other than errors"
    echo " -t, --trainer                        Activity is indoor"
    echo " -z, --gzip                           Compress file with gzip before upload (if not already compressed)"
    exit 1
fi


# Build options from command line parameters
OPTIONS=()
GZIP=""
SILENT=""
ARCHIVE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -d) OPTIONS+=("-F" "description=$2"); shift; shift;;
	-n) OPTIONS+=("-F" "name=$2"); shift; shift;;
	-a|--activity-type) OPTIONS+=("-F" "activity_type=$2"); shift; shift;;
        -A|--archive) ARCHIVE=("$2"); shift; shift;;
	-c|--commute) OPTIONS+=("-F" "commute=true"); shift;;
	-t|--trainer) OPTIONS+=("-F" "trainer=true"); shift;;
	--description=*) OPTIONS+=("-F" "description=${1#*=}"); shift;;
	--name=*) OPTIONS+=("-F" "name=${1#*=}"); shift;;
	--activity-type=*) OPTIONS+=("-F" "activity_type=${1#*=}"); shift;;
        --archive=*) ARCHIVE=("${1#*=}"); shift;;
	-z|--gzip) GZIP=1; shift;;
	-s|--silent) SILENT=1; shift;;
	-*) echo "Unknown option: $1" >&2; exit 1;;
        *) if [ -n "$FILE" ]; then
		echo "Uploading multiple files is not supported! (Got $FILE and $1)"
		exit 1
	else
		FILE="$1"
		shift
	fi
    esac
done

# Test whether file exists
if [ ! -f "$FILE" ]; then
    echo "$FILE does not exist!"
    exit 1
fi

ORIGINALFILE=$FILE
echo "uploading $ORIGINALFILE"

# Make a temporary copy of the file
TIME=`date +%T`
FILENAME=$(basename "$FILE")
NAME="${FILENAME%%.*}"
SUFFIX="${FILENAME#*.}"
TEMPDIR=`mktemp -d --suffix=_strava_upload`
if [ -z "$SILENT" ]; then
    echo "$TIME Creating temporary file in $TEMPDIR/"
fi
cp -a "$FILE" "$TEMPDIR/stravaup_data.$SUFFIX"
FILE="$TEMPDIR/stravaup_data.$SUFFIX"

#Archive the file if enabled
if [ -n "$ARCHIVE" ]; then
    if [ ! -d "$ARCHIVE" ]; then
        echo "Archive target $ARCHIVE is not a directory!"
	rm $FILE
	rmdir $TEMPDIR
	exit 1
    fi
    DATE=`date -I`
    TARGET="$ARCHIVE"/"$DATE"_"$NAME"."$SUFFIX"
    COUNT=0
    while [ -f "$TARGET" ]
    do
        COUNT=$(($COUNT+1))
        TARGET="$ARCHIVE"/"$DATE"_"$NAME"."$COUNT"."$SUFFIX"
    done
    TIME=`date +%T`
    echo "$TIME Creating an archive copy in $TARGET"
    cp -a "$FILE" "$TARGET"
fi

# Check the filetype
DATATYPE=""
if [ "$SUFFIX" = "fit" ]; then
    if [ -n "$GZIP" ]; then
	TIME=`date +%T`
        if [ -z "$SILENT" ]; then
            echo "$TIME Compressing $FILE with gzip..."
        fi
        gzip $TEMPDIR/stravaup_data.$SUFFIX
        FILE=$TEMPDIR/stravaup_data.$SUFFIX.gz
        DATATYPE=$SUFFIX.gz
    else
        DATATYPE=$SUFFIX
    fi
fi
if [ "$SUFFIX" = "tcx" ]; then
    # UNTESTED: Add barometer to TCX creator for supported devices
    for i in "${TCX_BAROMETERS[@]}"
    do
        if grep "<Name>$i</Name>" "$FILE" >/dev/null; then
            TIME=`date +%T`
            if [ -z "$SILENT" ]; then
                echo "$TIME Editing $FILE to add \"with barometer\" (Strava needs this to use elevation data from the $i)..."
            fi
            sed --in-place "s#<Name>$i</Name>#<Name>$i with barometer</Name>#" "$FILE"
            break
        fi
    done
    if [ -n "$GZIP" ]; then
	TIME=`date +%T`
        if [ -z "$SILENT" ]; then
            echo "$TIME Compressing $FILE with gzip..."
        fi
        gzip $TEMPDIR/stravaup_data.$SUFFIX
        FILE=$TEMPDIR/stravaup_data.$SUFFIX.gz
        DATATYPE=$SUFFIX.gz
    else
        DATATYPE=$SUFFIX
    fi
fi
if [ "$SUFFIX" = "gpx" ]; then
    for i in "${GPX_BAROMETERS[@]}"
    do
        if grep "creator=\"$i\"" "$FILE" >/dev/null; then
            TIME=`date +%T`
            if [ -z "$SILENT" ]; then
                echo "$TIME Editing $FILE to add \"with barometer\" (Strava needs this to use elevation data from the $i)..."
            fi
            sed --in-place "s#creator=\"$i\"#creator=\"$i with barometer\"#" "$FILE"
            break
        fi
    done
    if [ -n "$GZIP" ]; then
        TIME=`date +%T`
        if [ -z "$SILENT" ]; then
            echo "$TIME Compressing $FILE with gzip..."
        fi
        gzip $TEMPDIR/stravaup_data.$SUFFIX
        FILE=$TEMPDIR/stravaup_data.$SUFFIX.gz
        DATATYPE=$SUFFIX.gz
    else
        DATATYPE=$SUFFIX
    fi
fi
if [ "$SUFFIX" = "fit.gz" ]; then
    DATATYPE="$SUFFIX"
fi
if [ "$SUFFIX" = "tcx.gz" ]; then
    DATATYPE="$SUFFIX"
fi
if [ "$SUFFIX" = "gpx.gz" ]; then
    DATATYPE="$SUFFIX"
fi
if [ "$DATATYPE" = "" ]; then
    echo "Unknown file type $SUFFIX"
    rm $FILE
    rmdir $TEMPDIR
    exit 1
fi

# Get authorization code
if [ "$STRAVAUP_CODE" = "" ]; then
    echo "Please open the following URL in a browser"
    echo -n "https://www.strava.com/oauth/authorize?client_id="
    echo -n "$STRAVAUP_CLIENT_ID"
    echo "&response_type=code&redirect_uri=http://localhost/index.php&approval_prompt=force&scope=activity:write"
    echo "Select 'Authorize' which will lead to a redirect into a localhost address. Copy the authorization"
    echo "code into .stravauprc"
    echo "  STRAVAUP_CODE = [insert your own]"
    exit 1
fi

# If needed, get refresh token
if [ "$STRAVAUP_REFRESH_TOKEN" = "" ]; then
	TIME=`date +%T`
	if [ -z "$SILENT" ]; then
            echo "$TIME Exchanging authorization token for refresh token..."
        fi
	STRAVAUP_REFRESH_TOKEN=$(curl -s -X POST https://www.strava.com/oauth/token -F client_id="$STRAVAUP_CLIENT_ID" -F client_secret="$STRAVAUP_CLIENT_SECRET" -F code="$STRAVAUP_CODE" -F grant_type=authorization_code | cut -d':' -f5 | cut -d',' -f1 | sed -e 's/[^a-z0-9]//g')
	echo "STRAVAUP_REFRESH_TOKEN=$STRAVAUP_REFRESH_TOKEN" >> ${HOME}/.stravauprc
fi

# Get auth token
if [ "$TOKEN" = "" ]; then
    TIME=`date +%T`
    if [ -z "$SILENT" ]; then
        echo "$TIME Getting auth token..."
    fi
    TOKEN=$(curl -s -X POST https://www.strava.com/oauth/token -F client_id="$STRAVAUP_CLIENT_ID" -F client_secret="$STRAVAUP_CLIENT_SECRET" -F grant_type=refresh_token -F refresh_token="$STRAVAUP_REFRESH_TOKEN" | grep access_token | cut -d':' -f3 | cut -d',' -f1 | sed -e 's/[^a-z0-9]//g')
fi

# Upload file
TIME=`date +%T`
if [ -z "$SILENT" ]; then
    echo "$TIME Attempting upload to Strava..."
fi
CURLOUTPUT=`curl -s -X POST https://www.strava.com/api/v3/uploads -H "Authorization: Bearer $TOKEN" -F data_type="$DATATYPE" "${OPTIONS[@]}" -F file=@$FILE`
ID=`echo $CURLOUTPUT | jq -r '.id'`
STATUS=`echo $CURLOUTPUT | jq -r '.status'`

# Delete temporary file and directory
rm $FILE
rmdir $TEMPDIR

# Wait for response
WAIT=1
while [ "$STATUS" = "Your activity is still being processed." ]
do
	TIME=`date +%T`
	if [ -z "$SILENT" ]; then
            echo "$TIME Waiting for Strava to process the upload (id=$ID)..."
        fi
	sleep $WAIT
	if [ $(($WAIT)) -lt 300 ]; then
		WAIT=$(($WAIT*2))
	else
		WAIT=300
	fi
	CURLOUTPUT=`curl -s -G https://www.strava.com/api/v3/uploads/$ID -H "Authorization: Bearer $TOKEN"`
	STATUS=`echo $CURLOUTPUT | jq -r '.status'`
done
ACTIVITY=`echo $CURLOUTPUT | jq -r '.activity_id'`
# Report status
TIME=`date +%T`
if [ -z "$SILENT" ]; then
    echo "$TIME Upload complete: $STATUS"
fi
ERROR=`echo $CURLOUTPUT | jq -r '.message'`
if [ "$ERROR" != "null" ]; then
    if [ "$ERROR" = "Rate Limit Exceeded" ]; then
    echo "Rate Limit Exceeded, will now wait 15 minutes before continuing upload"
        sleep 900
    fi
	echo $ERROR
	exit 1
elif [ -z "$SILENT" ]; then
	echo "You can see your activity at https://www.strava.com/activities/$ACTIVITY"
    if [ "$ACTIVITY" != "null" ]; then
    echo "Delete File $ORIGINALFILE"
    rm $ORIGINALFILE
    fi
fi

exit 0

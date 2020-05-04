
#!/bin/bash
#
# Command line interface for uploading to Strava.com
#
# Based on https://github.com/mpolla/stravaup
#
# Kim Wall kim@ductilebiscuit.net


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
    echo " -c, --commute                        Activity is a commute"
    echo " -d, --description=\"Description\"      Activity description"
    echo " -n, --name=\"Name\"                    Activity name"
    echo " -t, --trainer                        Activity is indoor"
    echo " -z, --gzip                           Compress file with gzip before upload (if not already compressed)"
    exit 1
fi


# Build options from command line parameters
OPTIONS=()
GZIP=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -d) OPTIONS+=("-F" "description=$2"); shift; shift;;
	-n) OPTIONS+=("-F" "name=$2"); shift; shift;;
	-a|--activity-type) OPTIONS+=("-F" "activity_type=$2"); shift; shift;;
	-c|--commute) OPTIONS+=("-F" "commute=true"); shift;;
	-t|--trainer) OPTIONS+=("-F" "trainer=true"); shift;;
	--description=*) OPTIONS+=("-F" "description=${1#*=}"); shift;;
	--name=*) OPTIONS+=("-F" "name=${1#*=}"); shift;;
	--activity-type=*) OPTIONS+=("-F" "activity_type=${1#*=}"); shift;;
	-z|--gzip) GZIP=1; shift;;
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

# Check file type
FILENAME=$(basename "$FILE")
SUFFIX="${FILENAME#*.}"
DATATYPE=""
if [ "$SUFFIX" = "fit" ]; then
    cp $FILE /tmp/stravaup_data.$SUFFIX
    FILE=/tmp/stravaup_data.$SUFFIX
    if [ -n "$GZIP" ]; then
	TIME=`date +%T`
        echo "$TIME Compressing $FILE with gzip..."
        gzip /tmp/stravaup_data.$SUFFIX
        FILE=/tmp/stravaup_data.$SUFFIX.gz
        DATATYPE=$SUFFIX.gz
    else
        DATATYPE=$SUFFIX
    fi
fi
if [ "$SUFFIX" = "tcx" ]; then
    cp $FILE /tmp/stravaup_data.$SUFFIX
    FILE=/tmp/stravaup_data.$SUFFIX
    if [ -n "$GZIP" ]; then
	TIME=`date +%T`
        echo "$TIME Compressing $FILE with gzip..."
        gzip /tmp/stravaup_data.$SUFFIX
        FILE=/tmp/stravaup_data.$SUFFIX.gz
        DATATYPE=$SUFFIX.gz
    else
        DATATYPE=$SUFFIX
    fi
fi
if [ "$SUFFIX" = "gpx" ]; then
    cp $FILE /tmp/stravaup_data.$SUFFIX
    FILE=/tmp/stravaup_data.$SUFFIX
    if grep "creator=\"eTrex 30\"" "$FILE" >/dev/null; then
        TIME=`date +%T`
        echo "$TIME Editing $FILE to add \"with barometer\" (Strava needs this to use elevation data from eTrex 30)..."
        #sed --in-place=.bak 's/creator="eTrex 30"/creator="eTrex 30 with barometer"/' "$FILE"
        sed --in-place 's/creator="eTrex 30"/creator="eTrex 30 with barometer"/' "$FILE"
    fi
    if [ -n "$GZIP" ]; then
        TIME=`date +%T`
        echo "$TIME Compressing $FILE with gzip..."
        gzip /tmp/stravaup_data.$SUFFIX
        FILE=/tmp/stravaup_data.$SUFFIX.gz
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
	echo "$TIME Exchanging authorization token for refresh token..."
	STRAVAUP_REFRESH_TOKEN=$(curl -s -X POST https://www.strava.com/oauth/token -F client_id="$STRAVAUP_CLIENT_ID" -F client_secret="$STRAVAUP_CLIENT_SECRET" -F code="$STRAVAUP_CODE" -F grant_type=authorization_code | cut -d':' -f5 | cut -d',' -f1 | sed -e 's/[^a-z0-9]//g')
	echo "STRAVAUP_REFRESH_TOKEN=$STRAVAUP_REFRESH_TOKEN" >> ${HOME}/.stravauprc
fi

# Get auth token
if [ "$TOKEN" = "" ]; then
    TIME=`date +%T`
    echo "$TIME Getting auth token..."
    TOKEN=$(curl -s -X POST https://www.strava.com/oauth/token -F client_id="$STRAVAUP_CLIENT_ID" -F client_secret="$STRAVAUP_CLIENT_SECRET" -F grant_type=refresh_token -F refresh_token="$STRAVAUP_REFRESH_TOKEN" | grep access_token | cut -d':' -f3 | cut -d',' -f1 | sed -e 's/[^a-z0-9]//g')
fi

# Upload file
TIME=`date +%T`
echo "$TIME Attempting upload to Strava..."
CURLOUTPUT=`curl -s -X POST https://www.strava.com/api/v3/uploads -H "Authorization: Bearer $TOKEN" -F data_type="$DATATYPE" "${OPTIONS[@]}" -F file=@$FILE`
ID=`echo $CURLOUTPUT | jq -r '.id'`
STATUS=`echo $CURLOUTPUT | jq -r '.status'`

# Delete temporary file
rm $FILE

# Wait for response
WAIT=1
while [ "$STATUS" = "Your activity is still being processed." ]
do
	TIME=`date +%T`
	echo "$TIME Waiting for Strava to process the upload (id=$ID)..."
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
echo "Upload complete: $STATUS"
ERROR=`echo $CURLOUTPUT | jq -r '.error'`
if [ "$ERROR" != "null" ]; then
	echo $ERROR
	exit 1
else
	echo "You can see your activity at https://www.strava.com/activities/$ACTIVITY"
fi

exit 0

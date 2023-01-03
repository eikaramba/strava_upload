# strava_upload
Strava uploader for GPX/TCX/FIT files.
Based on kimble4/strava_upload

# Changes
- I added deletion of the processed file
- handling rate limit exceeding, waiting 15 minutes before continuing

# Usage
I use the following terminal script to loop over files in a directory and upload them
```
 for i in `ls *.gpx`
   do ./uploader.sh -n "Lauf" --description="From runtastic" -z "$i"
 done
 ```

# Original readme

GPX files originating from a Garmin eTrex 30 will have "with barometer" added to the 'creator' field so that Strava uses their elevation readings.

## Prerequisites
* bash
* cURL
* jq


## Usage:
Upload a file:

  `strava_upload.sh [options] file`

Permitted options are:

`-a, --activity-type=type` One of ride, run, swim, workout, hike, walk, ebikeride, virtualride, etc.

`-A, --archive="dir"` Save a copy of the file in directory

`-c, --commute` Activity is a commute

`-d, --description="Activity description"` Activity description

`-n, --name="Activity name"` Activity name

`-s, --silent` Surpress status messages other than errors

`-t, --trainer` Activity is indoor

`-z, --gzip` Compress file with gzip before upload (if not already compressed)

eg:

  `strava_upload.sh -n "Daily permitted exercise" --description="Why are so many people driving around in cars?" -z Desktop/Current.gpx`

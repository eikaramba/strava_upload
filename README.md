# strava_upload
Strava uploader for GPX/TCX/FIT files.
Based on https://github.com/mpolla/stravaup

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

`-c, --commute` Activity is a commute

`-d, --description="Activity description"` Activity description

`-n, --name="Activity name"` Activity name

`-s, --silent` Surpress status messages other than errors

`-t, --trainer` Activity is indoor

`-z, --gzip` Compress file with gzip before upload (if not already compressed)

eg:

  `strava_upload.sh -n "Daily permitted exercise" --description="Why are so many people driving around in cars?" -z Desktop/Current.gpx`

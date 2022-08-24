#! /usr/bin/env bash
# Extract observations from a model output file into SQL database
#

DEBUG=${DEBUG:-1}
set -e
# set -x
DEBUG=${DEBUG:-1}
debug() {
    [[ $DEBUG -eq 1 ]] && echo "$@"
}

# Load bash library to deal with BirdNET-stream database
source ./daemon/database/scripts/database.sh

# Load config
source ./config/birdnet.conf
# Check config

if [[ -z ${LATITUDE} ]]; then
    echo "LATITUDE is not set"
    exit 1
fi

if [[ -z ${LONGITUDE} ]]; then
    echo "LONGITUDE is not set"
    exit 1
fi

source_wav() {
    model_output_path=$1
    model_output_dir=$(dirname $model_output_path)
    source_wav=$(basename $model_output_dir | rev | cut --complement -d"." -f1 | rev)
    echo $source_wav
}

record_datetime() {
    source_wav=$1
    source_base=$(basename $source_wav .wav)
    record_date=$(echo $source_base | cut -d"_" -f2)
    record_time=$(echo $source_base | cut -d"_" -f3)
    YYYY=$(echo $record_date | cut -c 1-4)
    MM=$(echo $record_date | cut -c 5-6)
    DD=$(echo $record_date | cut -c 7-8)
    HH=$(echo $record_time | cut -c 1-2)
    MI=$(echo $record_time | cut -c 3-4)
    SS=$(echo $record_time | cut -c 5-6)
    SSS="000"
    date="$YYYY-$MM-$DD $HH:$MI:$SS.$SSS"
    echo $date
}

save_observations() {
    model_output_path=$1
    source_audio=$(source_wav $model_output_path)
    debug "Audio source: $source_audio"
    observations=$(cat $model_output_path | tail -n +2)
    IFS=$'\n'
    for observation in $observations; do
        if [[ -z "$observation" ]]; then
            continue
        fi
        # debug "Observation: $observation"
        start=$(echo "$observation" | cut -d"," -f1)
        end=$(echo "$observation" | cut -d"," -f2)
        scientific_name=$(echo "$observation" | cut -d"," -f3)
        common_name=$(echo "$observation" | cut -d"," -f4)
        confidence=$(echo "$observation" | cut -d"," -f5)
        debug "Observation: $scientific_name ($common_name) from $start to $end with confidence $confidence"
        taxon_id=$(get_taxon_id "$scientific_name")
        if [[ -z $taxon_id ]]; then
            debug "Taxon not found: $scientific_name"
            debug "Inserting taxon..."
            insert_taxon "$scientific_name" "$common_name"
            taxon_id=$(get_taxon_id "$scientific_name")
        fi
        location_id=$(get_location_id "$LATITUDE" "$LONGITUDE")
        if [[ -z $location_id ]]; then
            debug "Location not found: $LATITUDE, $LONGITUDE"
            debug "Inserting location..."
            insert_location "$LATITUDE" "$LONGITUDE"
            location_id=$(get_location_id "$LATITUDE" "$LONGITUDE")
        fi
        datetime=$(record_datetime $source_audio)
        if [[ $(observation_exists "$source_audio" "$start" "$end" "$taxon_id" "$location_id") -eq 1 ]]; then
            debug "Observation already exists: $source_audio, $start, $end, $taxon_id, $location_id"
        else
            debug "Inserting observation: $source_audio, $start, $end, $taxon_id, $location_id, $datetime"
            insert_observation "$source_audio" "$start" "$end" "$taxon_id" "$location_id" "$confidence" "$datetime"
        fi
    done
}

model_output_path="$1"

save_observations $model_output_path
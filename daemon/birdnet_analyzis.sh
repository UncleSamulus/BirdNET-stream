#! /usr/bin/env bash
set -e

DEBUG=${DEBUG:-1}
debug() {
    [[ $DEBUG -eq 1 ]] && echo "$@"
}

config_filepath="./config/birdnet.conf"

if [ -f "$config_filepath" ]; then
    source "$config_filepath"
else
    echo "Config file not found: $config_filepath"
    exit 1
fi

PYTHON_EXECUTABLE="${PYTHON_VENV}/bin/python3"

check_prerequisites() {
    if [[ -z ${LATITUDE} ]]; then
        echo "LATITUDE is not set"
        exit 1
    fi
    if [[ -z ${LONGITUDE} ]]; then
        echo "LONGITUDE is not set"
        exit 1
    fi
    if [[ -z ${CHUNK_FOLDER} ]]; then
        echo "CHUNK_FOLDER is not set"
        exit 1
    else
        if [[ ! -d "${CHUNK_FOLDER}" ]]; then
            echo "CHUNK_FOLDER does not exist: ${CHUNK_FOLDER}"
            exit 1
        else
            if [[ ! -d "${CHUNK_FOLDER}/in" ]]; then
                echo "Input dir does not exist: ${CHUNK_FOLDER}/in"
                exit 1
            else
                if [[ ! -d "${CHUNK_FOLDER}/out" ]]; then
                    echo "Output dir does not exist: ${CHUNK_FOLDER}/out"
                    echo "Creating output dir"
                    mkdir -p "${CHUNK_FOLDER}/out"
                fi
            fi
        fi
    fi
    if [[ -z ${SPECIES_LIST} ]]; then
        echo "SPECIES_LIST is not set"
        exit 1
    fi
    if [[ -f ${PYTHON_EXECUTABLE} ]]; then
        if $verbose; then
            echo "Python executable found: ${PYTHON_EXECUTABLE}"
        fi
    else
        echo "Python executable not found: ${PYTHON_EXECUTABLE}"
        exit 1
    fi
}

# Get array of audio chunks to be processed
get_chunk_list() {
    chunk_list=($(ls ${CHUNK_FOLDER}/in))
    echo "${chunk_list}"
    # find "${CHUNK_FOLDER}/in" -type f -name '*.wav' -exec basename {} \; ! -size 0 | sort
}

# Perform audio chunk analysis on one chunk
analyze_chunk() {
    chunk_name=$1
    chunk_path="${CHUNK_FOLDER}/in/$chunk_name"
    output_dir="${CHUNK_FOLDER}/out/$chunk_name.d"
    mkdir -p "$output_dir"
    date=$(echo $chunk_name | cut -d'_' -f2)
    week=$(./daemon/weekof.sh $date)
    if [[ ! -z "${THREADS}" ]]; then
        threads="--threads ${THREADS}"
    else 
        threads=""
    fi
    $PYTHON_EXECUTABLE ./analyzer/analyze.py --i $chunk_path --o "$output_dir/model.out.csv" --lat $LATITUDE --lon $LONGITUDE --week $week --min_conf $CONFIDENCE $threads --rtype csv
    debug "Model output written to $output_dir/model.out.csv"
    bash ./daemon/birdnet_output_to_sql.sh "$output_dir/model.out.csv"
    debug "Dumped to SQL database"
}

# Perform audio chunk analysis on all recorded chunks
analyze_chunks() {
    local chunks
    chunks="${1}"
    for chunk_name in "${chunks}"; do
        if [[ -f "${CHUNK_FOLDER}/out/$chunk_name.d/model.out.csv" ]]; then
            debug "Skipping $chunk_name, as it has already been analyzed"
        else
            analyze_chunk $chunk_name
        fi
        chunk_path="${CHUNK_FOLDER}/in/$chunk_name"
        mv $chunk_path "${CHUNK_FOLDER}/out/$chunk_name"
    done
}

check_prerequisites

# Get list of current chunk in working directory
chunks=$(get_chunk_list)

# Analyze all chunks in working directory
analyze_chunks "$chunks"
#!/usr/bin/env bash

json_escape() {
    local value=${1-}
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    printf '%s' "$value"
}

load_settings() {
    local config_file=${1-} cli_color=${2-}
    TASKER_EFFECTIVE_COLOR=auto
    if [[ -n $config_file && -f $config_file ]]; then
        # Deliberate benchmark defect: task 02 asks the agent to fix paths containing spaces.
        # shellcheck disable=SC1090,SC2086
        source $config_file
        TASKER_EFFECTIVE_COLOR=${COLOR-$TASKER_EFFECTIVE_COLOR}
    fi
    TASKER_EFFECTIVE_COLOR=${TASKER_COLOR-$TASKER_EFFECTIVE_COLOR}
    [[ -z $cli_color ]] || TASKER_EFFECTIVE_COLOR=$cli_color
}

unpack_bundle() {
    local archive=$1 destination=$2
    mkdir -p -- "$destination"
    # Deliberate benchmark defect: task 04 asks for validation before extraction.
    tar -xf "$archive" -C "$destination"
}

tasker_main() {
    local config_file='' cli_color='' command='' tag=''
    local -a tags=()
    while (( $# )); do
        case $1 in
            --config) config_file=$2; shift 2 ;;
            --color) cli_color=$2; shift 2 ;;
            --tag) tag=$2; shift 2 ;;
            report|unpack) command=$1; shift; break ;;
            *) printf 'Unknown argument: %s\n' "$1" >&2; return 2 ;;
        esac
    done

    load_settings "$config_file" "$cli_color"
    [[ -z $tag ]] || tags=("$tag")

    case $command in
        report)
            if [[ ${1-} == --json ]]; then
                printf 'JSON reports are not implemented.\n' >&2
                return 2
            fi
            printf 'color=%s\n' "$TASKER_EFFECTIVE_COLOR"
            printf 'tags=%s\n' "${tags[*]-}"
            ;;
        unpack)
            [[ $# -eq 2 ]] || { printf 'Usage: tasker unpack ARCHIVE DESTINATION\n' >&2; return 2; }
            unpack_bundle "$1" "$2"
            ;;
        *) printf 'A command is required.\n' >&2; return 2 ;;
    esac
}

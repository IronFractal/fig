#!/bin/sh
set -e

OUTPUT=""
MODULE_DIRS=""

while getopts ":ho:i:" OPT; do
    case "${OPT}" in
        h)
            echo "Usage: build.sh [input file] <options>"
            echo ""
            echo "Options:"
            echo "  -h           Display help information"
            echo "  -o <output>  Output script"
            echo "  -i <dir>     Add module include path"
            exit 0
            ;;
        o)
            OUTPUT="${OPTARG}"
            ;;
        i)
            MODULE_DIRS="${MODULE_DIRS} ${OPTARG}"
            ;;
        \?)
            echo "error: invalid option: -${OPTARG}" >&2
            exit 1
            ;;
        :)
            echo "error: option -${OPTARG} requires an argument" >&2
            exit 1
            ;;
    esac
done

shift "$((OPTIND-1))"

INPUT="${1}"

if [ -z "${INPUT}" ]; then
    echo "No input file specified." >&2
    exit 1
fi

if [ -n "${OUTPUT}" ]; then
    exec >"${OUTPUT}"
fi

while IFS= read -r LINE ; do
    case "${LINE}" in
        '#{{'*'}}')
            MODULE="$(printf '%s\n' "${LINE}" | sed 's/^#{{\(.*\)}}$/\1/')"

            if [ -n "${MODULE}" ] ; then
                FOUND=false
                for MODDIR in ${MODULE_DIRS} ; do
                    if [ -e "${MODDIR}/${MODULE}.sh.in" ] ; then
                        FOUND=true
                        cat "${MODDIR}/${MODULE}.sh.in"
                    fi
                done

                if ! "${FOUND}" && [ -e "./${MODULE}.sh.in" ] ; then
                    cat "./${MODULE}.sh.in"
                elif ! "${FOUND}" ; then
                    echo "error: module '${MODULE}' not found" >&2
                fi
            fi
            ;;
        *)
            printf '%s\n' "${LINE}"
            ;;
    esac
done <"${INPUT}"

if [ -n "${OUTPUT}" ]; then
    chmod 775 "${OUTPUT}"
fi


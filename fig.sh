#!/bin/bash
# MIT License
#
# Copyright (c) 2025 James Hatfield
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Description:
# A bash script for generating generic configuration scripts.
#
# Usage:
# Source from your "fig" script.
# ```
# #!/usr/bin/env fig.sh
# ```
# or
# ```
# #!/bin/bash
#
# if ! ${FIG_DEFINED:-false} ; then
#     exec "$(dirname "$(readlink -f "${0}")")/fig.sh" ${0} ${@}
# fi
# ```
#
# Git Repository: https://github.com/IronFractal/fig
#
set -e

# shellcheck disable=SC2034
FIG_DEFINED=true

__FIG_SRC_SCRIPT="${1}"
shift

###############################################################################
# CORE
###############################################################################

__FIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
__FIG_SCRIPT_DIR="$(cd -- "$(dirname -- "${__FIG_SRC_SCRIPT}")" &> /dev/null && pwd)"
__FIG_SCRIPT="#!/bin/bash
# THIS IS A GENERATED SCRIPT (DO NOT EDIT)!!
# Source: ${__FIG_SRC_SCRIPT}
set -e

SRC_DIR=\"\$(cd -- \"\$(dirname -- \"\${BASH_SOURCE[0]}\")\" &> /dev/null && pwd)\"
SRC_DIR_RELATIVE=\"\$(realpath --relative-to=\$(pwd) \"\${SRC_DIR}\")\"
BUILD_DIR=\"\$(pwd)\"
"
__FIG_EXPORTED=""

fig_log() {
    echo "${1}"
}

fig_log_err() {
    echo "error: ${1}" >&2
}

fig_get_script_path() {
    if [[ " ${1} " =~ ^\ /.* ]] ; then
        echo "${1}"
    else
        realpath "${__FIG_SCRIPT_DIR}"/"${1}"
    fi
}

fig_generate() {
    local SCRIPT_NAME
    local SCRIPT_PATH
    SCRIPT_NAME="$(basename "${1}")"
    SCRIPT_PATH="$(fig_get_script_path "${1}")"
    if [ -z "${SCRIPT_NAME}" ] ; then
        fig_log_err "configure script name cannot be empty!"
        return 1
    elif [ -e "${SCRIPT_PATH}" ] && ! "${FIG_ALLOW_OVERWRITE:-false}" ; then
        fig_log_err "cannot overwrite existing file '${SCRIPT_PATH}'!"
        return 1
    fi
    fig_export main
    mkdir -p "$(dirname "${SCRIPT_PATH}")"
    echo "${__FIG_SCRIPT}" > "${SCRIPT_PATH}"
    echo "main \${@}" >> "${SCRIPT_PATH}"
    echo "" >> "${SCRIPT_PATH}"
    chmod +x "${SCRIPT_PATH}"
}

fig_export() {
    if [[ " ${__FIG_EXPORTED} " =~ ( )${1}( ) ]] ; then
        return 0
    fi
    if [ -z "$(type -t "${1}")" ] ; then
        fig_log_err "function '${1}' does not exist!"
        return 1
    fi
    if [ "$(type -t "${1}")" != "function" ] ; then
        fig_log_err "'${1}' is not a function!"
        return 1
    fi
    __FIG_EXPORTED+=" ${1} "
    __FIG_SCRIPT="${__FIG_SCRIPT}
$(declare -f "${1}" | sed 's/[[:space:]]*$//')
"
}

fig_assert() {
    if ! command -v "${1}" &>/dev/null ; then
        fig_log_err "command '${1}' is not available!"
        return 1
    fi
    return 0
}

fig_assert_qq() {
    fig_assert "${@}" &>/dev/null
}

fig_assert_one() {
    local CHECKED=""
    for cmd in "${@}" ; do
        if which "${cmd}" &>/dev/null ; then
            echo "${cmd}"
            return 0
        fi
        CHECKED+=" '${cmd}' "
    done
    fig_log_err "one of${CHECKED}is not available!"
    return 1
}

fig_assert_one_q() {
    fig_assert_one "${@}" >/dev/null
}

fig_assert_one_qq() {
    fig_assert_one "${@}" &>/dev/null
}

###############################################################################
# CORE (run)
###############################################################################

fig_assert sed

fig_export fig_log
fig_export fig_log_err
fig_export fig_assert
fig_export fig_assert_qq
fig_export fig_assert_one_q
fig_export fig_assert_one_qq

###############################################################################
# PURE-GETOPT
###############################################################################

pure-getopt() {
  # pure-getopt, a drop-in replacement for GNU getopt in pure Bash.
  # version 1.4.5
  #
  # Copyright 2012-2021 Aron Griffis <aron@scampersand.com>
  #
  # Permission is hereby granted, free of charge, to any person obtaining
  # a copy of this software and associated documentation files (the
  # "Software"), to deal in the Software without restriction, including
  # without limitation the rights to use, copy, modify, merge, publish,
  # distribute, sublicense, and/or sell copies of the Software, and to
  # permit persons to whom the Software is furnished to do so, subject to
  # the following conditions:
  #
  # The above copyright notice and this permission notice shall be included
  # in all copies or substantial portions of the Software.
  #
  # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  # OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  # IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  # CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  # TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  # SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

  _getopt_main() {
    # Returns one of the following statuses:
    #   0 success
    #   1 error parsing parameters
    #   2 error in getopt invocation
    #   3 internal error
    #   4 reserved for -T
    #
    # For statuses 0 and 1, generates normalized and shell-quoted
    # "options -- parameters" on stdout.

    declare parsed status
    declare short long='' name flags=''
    declare have_short=false

    # Synopsis from getopt man-page:
    #
    #   getopt optstring parameters
    #   getopt [options] [--] optstring parameters
    #   getopt [options] -o|--options optstring [options] [--] parameters
    #
    # The first form can be normalized to the third form which
    # _getopt_parse() understands. The second form can be recognized after
    # first parse when $short hasn't been set.

    if [[ -n ${GETOPT_COMPATIBLE+isset} || $1 == [^-]* ]]; then
      # Enable compatibility mode
      flags=c$flags
      # Normalize first to third synopsis form
      set -- -o "$1" -- "${@:2}"
    fi

    # First parse always uses flags=p since getopt always parses its own
    # arguments effectively in this mode.
    parsed=$(_getopt_parse getopt ahl:n:o:qQs:TuV \
      alternative,help,longoptions:,name:,options:,quiet,quiet-output,shell:,test,version \
      p "$@")
    status=$?
    if [[ $status != 0 ]]; then
      if [[ $status == 1 ]]; then
        echo "Try 'getopt --help' for more information." >&2
        # Since this is the first parse, convert status 1 to 2
        status=2
      fi
      return $status
    fi
    eval "set -- $parsed"

    while [[ $# -gt 0 ]]; do
      case $1 in
        (-a|--alternative)
          flags=a$flags ;;

        (-h|--help)
          _getopt_help
          return 0
          ;;

        (-l|--longoptions)
          long="$long${long:+,}$2"
          shift ;;

        (-n|--name)
          name=$2
          shift ;;

        (-o|--options)
          short=$2
          have_short=true
          shift ;;

        (-q|--quiet)
          flags=q$flags ;;

        (-Q|--quiet-output)
          flags=Q$flags ;;

        (-s|--shell)
          case $2 in
            (sh|bash)
              flags=${flags//t/} ;;
            (csh|tcsh)
              flags=t$flags ;;
            (*)
              echo 'getopt: unknown shell after -s or --shell argument' >&2
              echo "Try 'getopt --help' for more information." >&2
              return 2 ;;
          esac
          shift ;;

        (-u|--unquoted)
          flags=u$flags ;;

        (-T|--test)
          return 4 ;;

        (-V|--version)
          echo "pure-getopt 1.4.4"
          return 0 ;;

        (--)
          shift
          break ;;
      esac

      shift
    done

    if ! $have_short; then
      # $short was declared but never set, not even to an empty string.
      # This implies the second form in the synopsis.
      if [[ $# == 0 ]]; then
        echo 'getopt: missing optstring argument' >&2
        echo "Try 'getopt --help' for more information." >&2
        return 2
      fi
      short=$1
      have_short=true
      shift
    fi

    if [[ $short == -* ]]; then
      # Leading dash means generate output in place rather than reordering,
      # unless we're already in compatibility mode.
      [[ $flags == *c* ]] || flags=i$flags
      short=${short#?}
    elif [[ $short == +* ]]; then
      # Leading plus means POSIXLY_CORRECT, unless we're already in
      # compatibility mode.
      [[ $flags == *c* ]] || flags=p$flags
      short=${short#?}
    fi

    # This should fire if POSIXLY_CORRECT is in the environment, even if
    # it's an empty string.  That's the difference between :+ and +
    flags=${POSIXLY_CORRECT+p}$flags

    _getopt_parse "${name:-getopt}" "$short" "$long" "$flags" "$@"
  }

  _getopt_parse() {
    # Inner getopt parser, used for both first parse and second parse.
    # Returns 0 for success, 1 for error parsing, 3 for internal error.
    # In the case of status 1, still generates stdout with whatever could
    # be parsed.
    #
    # $flags is a string of characters with the following meanings:
    #   a - alternative parsing mode
    #   c - GETOPT_COMPATIBLE
    #   i - generate output in place rather than reordering
    #   p - POSIXLY_CORRECT
    #   q - disable error reporting
    #   Q - disable normal output
    #   t - quote for csh/tcsh
    #   u - unquoted output

    declare name="$1" short="$2" long="$3" flags="$4"
    shift 4

    # Split $long on commas, prepend double-dashes, strip colons;
    # for use with _getopt_resolve_abbrev
    declare -a longarr
    _getopt_split longarr "$long"
    longarr=( "${longarr[@]/#/--}" )
    longarr=( "${longarr[@]%:}" )
    longarr=( "${longarr[@]%:}" )

    # Parse and collect options and parameters
    declare -a opts params
    declare o alt_recycled=false error=0

    while [[ $# -gt 0 ]]; do
      case $1 in
        (--)
          params=( "${params[@]}" "${@:2}" )
          break ;;

        (--*=*)
          o=${1%%=*}
          if ! o=$(_getopt_resolve_abbrev "$o" "${longarr[@]}"); then
            error=1
          elif [[ ,"$long", == *,"${o#--}"::,* ]]; then
            opts=( "${opts[@]}" "$o" "${1#*=}" )
          elif [[ ,"$long", == *,"${o#--}":,* ]]; then
            opts=( "${opts[@]}" "$o" "${1#*=}" )
          elif [[ ,"$long", == *,"${o#--}",* ]]; then
            if $alt_recycled; then o=${o#-}; fi
            _getopt_err "$name: option '$o' doesn't allow an argument"
            error=1
          else
            echo "getopt: assertion failed (1)" >&2
            return 3
          fi
          alt_recycled=false
          ;;

        (--?*)
          o=$1
          if ! o=$(_getopt_resolve_abbrev "$o" "${longarr[@]}"); then
            error=1
          elif [[ ,"$long", == *,"${o#--}",* ]]; then
            opts=( "${opts[@]}" "$o" )
          elif [[ ,"$long", == *,"${o#--}::",* ]]; then
            opts=( "${opts[@]}" "$o" '' )
          elif [[ ,"$long", == *,"${o#--}:",* ]]; then
            if [[ $# -ge 2 ]]; then
              shift
              opts=( "${opts[@]}" "$o" "$1" )
            else
              if $alt_recycled; then o=${o#-}; fi
              _getopt_err "$name: option '$o' requires an argument"
              error=1
            fi
          else
            echo "getopt: assertion failed (2)" >&2
            return 3
          fi
          alt_recycled=false
          ;;

        (-*)
          if [[ $flags == *a* ]]; then
            # Alternative parsing mode!
            # Try to handle as a long option if any of the following apply:
            #  1. There's an equals sign in the mix -x=3 or -xy=3
            #  2. There's 2+ letters and an abbreviated long match -xy
            #  3. There's a single letter and an exact long match
            #  4. There's a single letter and no short match
            o=${1::2} # temp for testing #4
            if [[ $1 == *=* || $1 == -?? || \
                  ,$long, == *,"${1#-}"[:,]* || \
                  ,$short, != *,"${o#-}"[:,]* ]]; then
              o=$(_getopt_resolve_abbrev "${1%%=*}" "${longarr[@]}" 2>/dev/null)
              case $? in
                (0)
                  # Unambiguous match. Let the long options parser handle
                  # it, with a flag to get the right error message.
                  set -- "-$1" "${@:2}"
                  alt_recycled=true
                  continue ;;
                (1)
                  # Ambiguous match, generate error and continue.
                  _getopt_resolve_abbrev "${1%%=*}" "${longarr[@]}" >/dev/null
                  error=1
                  shift
                  continue ;;
                (2)
                  # No match, fall through to single-character check.
                  true ;;
                (*)
                  echo "getopt: assertion failed (3)" >&2
                  return 3 ;;
              esac
            fi
          fi

          o=${1::2}
          if [[ "$short" == *"${o#-}"::* ]]; then
            if [[ ${#1} -gt 2 ]]; then
              opts=( "${opts[@]}" "$o" "${1:2}" )
            else
              opts=( "${opts[@]}" "$o" '' )
            fi
          elif [[ "$short" == *"${o#-}":* ]]; then
            if [[ ${#1} -gt 2 ]]; then
              opts=( "${opts[@]}" "$o" "${1:2}" )
            elif [[ $# -ge 2 ]]; then
              shift
              opts=( "${opts[@]}" "$o" "$1" )
            else
              _getopt_err "$name: option requires an argument -- '${o#-}'"
              error=1
            fi
          elif [[ "$short" == *"${o#-}"* ]]; then
            opts=( "${opts[@]}" "$o" )
            if [[ ${#1} -gt 2 ]]; then
              set -- "$o" "-${1:2}" "${@:2}"
            fi
          else
            if [[ $flags == *a* ]]; then
              # Alternative parsing mode! Report on the entire failed
              # option. GNU includes =value but we omit it for sanity with
              # very long values.
              _getopt_err "$name: unrecognized option '${1%%=*}'"
            else
              _getopt_err "$name: invalid option -- '${o#-}'"
              if [[ ${#1} -gt 2 ]]; then
                set -- "$o" "-${1:2}" "${@:2}"
              fi
            fi
            error=1
          fi ;;

        (*)
          # GNU getopt in-place mode (leading dash on short options)
          # overrides POSIXLY_CORRECT
          if [[ $flags == *i* ]]; then
            opts=( "${opts[@]}" "$1" )
          elif [[ $flags == *p* ]]; then
            params=( "${params[@]}" "$@" )
            break
          else
            params=( "${params[@]}" "$1" )
          fi
      esac

      shift
    done

    if [[ $flags == *Q* ]]; then
      true  # generate no output
    else
      echo -n ' '
      if [[ $flags == *[cu]* ]]; then
        printf '%s -- %s' "${opts[*]}" "${params[*]}"
      else
        if [[ $flags == *t* ]]; then
          _getopt_quote_csh "${opts[@]}" -- "${params[@]}"
        else
          _getopt_quote "${opts[@]}" -- "${params[@]}"
        fi
      fi
      echo
    fi

    return $error
  }

  _getopt_err() {
    if [[ $flags != *q* ]]; then
      printf '%s\n' "$1" >&2
    fi
  }

  _getopt_resolve_abbrev() {
    # Resolves an abbrevation from a list of possibilities.
    # If the abbreviation is unambiguous, echoes the expansion on stdout
    # and returns 0.  If the abbreviation is ambiguous, prints a message on
    # stderr and returns 1. (For first parse this should convert to exit
    # status 2.)  If there is no match at all, prints a message on stderr
    # and returns 2.
    declare a q="$1"
    declare -a matches=()
    shift
    for a; do
      if [[ $q == "$a" ]]; then
        # Exact match. Squash any other partial matches.
        matches=( "$a" )
        break
      elif [[ $flags == *a* && $q == -[^-]* && $a == -"$q" ]]; then
        # Exact alternative match. Squash any other partial matches.
        matches=( "$a" )
        break
      elif [[ $a == "$q"* ]]; then
        # Abbreviated match.
        matches=( "${matches[@]}" "$a" )
      elif [[ $flags == *a* && $q == -[^-]* && $a == -"$q"* ]]; then
        # Abbreviated alternative match.
        matches=( "${matches[@]}" "${a#-}" )
      fi
    done
    case ${#matches[@]} in
      (0)
        [[ $flags == *q* ]] || \
        printf "$name: unrecognized option %s\\n" >&2 \
          "$(_getopt_quote "$q")"
        return 2 ;;
      (1)
        printf '%s' "${matches[0]}"; return 0 ;;
      (*)
        [[ $flags == *q* ]] || \
        printf "$name: option %s is ambiguous; possibilities: %s\\n" >&2 \
          "$(_getopt_quote "$q")" "$(_getopt_quote "${matches[@]}")"
        return 1 ;;
    esac
  }

  _getopt_split() {
    # Splits $2 at commas to build array specified by $1
    declare IFS=,
    eval "$1=( \$2 )"
  }

  _getopt_quote() {
    # Quotes arguments with single quotes, escaping inner single quotes
    declare s space='' q=\'
    for s; do
      printf "$space'%s'" "${s//$q/$q\\$q$q}"
      space=' '
    done
  }

  _getopt_quote_csh() {
    # Quotes arguments with single quotes, escaping inner single quotes,
    # bangs, backslashes and newlines
    declare s i c space
    for s; do
      echo -n "$space'"
      for ((i=0; i<${#s}; i++)); do
        c=${s:i:1}
        case $c in
          (\\|\'|!)
            echo -n "'\\$c'" ;;
          ($'\n')
            echo -n "\\$c" ;;
          (*)
            echo -n "$c" ;;
        esac
      done
      echo -n \'
      space=' '
    done
  }

  _getopt_help() {
    cat <<-EOT

	Usage:
	 getopt <optstring> <parameters>
	 getopt [options] [--] <optstring> <parameters>
	 getopt [options] -o|--options <optstring> [options] [--] <parameters>

	Parse command options.

	Options:
	 -a, --alternative             allow long options starting with single -
	 -l, --longoptions <longopts>  the long options to be recognized
	 -n, --name <progname>         the name under which errors are reported
	 -o, --options <optstring>     the short options to be recognized
	 -q, --quiet                   disable error reporting by getopt(3)
	 -Q, --quiet-output            no normal output
	 -s, --shell <shell>           set quoting conventions to those of <shell>
	 -T, --test                    test for getopt(1) version
	 -u, --unquoted                do not quote the output

	 -h, --help                    display this help
	 -V, --version                 display version

	For more details see getopt(1).
	EOT
  }

  _getopt_version_check() {
    if [[ -z $BASH_VERSION ]]; then
      echo "getopt: unknown version of bash might not be compatible" >&2
      return 1
    fi

    # This is a lexical comparison that should be sufficient forever.
    if [[ $BASH_VERSION < 2.05b ]]; then
      echo "getopt: bash $BASH_VERSION might not be compatible" >&2
      return 1
    fi

    return 0
  }

  _getopt_version_check
  _getopt_main "$@"
  declare status=$?
  unset -f _getopt_main _getopt_err _getopt_parse _getopt_quote \
    _getopt_quote_csh _getopt_resolve_abbrev _getopt_split _getopt_help \
    _getopt_version_check
  return $status
}

###############################################################################
# ARG PARSING
###############################################################################

__FIG_PARSER=""
__FIG_PARSER_SHORT=""
__FIG_PARSER_LONG=""
__FIG_PARSER_ENV=false
__FIG_PARSER_ENV_DEFAULTS=""
__FIG_PARSER_USAGE=true
__FIG_PARSER_POS_ARGS=false
__FIG_PARSER_POS_ARGS_NAMES=""
__FIG_PARSER_DESC=""
__FIG_PARSER_PRE=""
__FIG_PARSER_CASE=""
__FIG_PARSER_HELP=""
__FIG_PARSER_HELP_ENV=""
__FIG_PARSER_HELP_POS=""

fig_parser_begin() {
    fig_assert fold

    __FIG_PARSER="${1}"
    __FIG_PARSER_SHORT="h"
    __FIG_PARSER_LONG="help,"
    __FIG_PARSER_ENV=false
    __FIG_PARSER_ENV_DEFAULTS=""
    __FIG_PARSER_USAGE=true
    __FIG_PARSER_POS_ARGS=false
    __FIG_PARSER_POS_ARGS_NAMES=""
    __FIG_PARSER_DESC=""
    __FIG_PARSER_PRE=""
    __FIG_PARSER_CASE=""
    __FIG_PARSER_HELP='Options:
  -h, --help
    Print this help information
'
    __FIG_PARSER_HELP_ENV='
Environment:
'
    __FIG_PARSER_HELP_POS='
Positional Arguments:'
}

fig_parser_enable_usage() {
    if ${1} ; then
        __FIG_PARSER_USAGE=true
    else
        __FIG_PARSER_USAGE=false
    fi
}

fig_parser_set_description() {
    __FIG_PARSER_DESC="${1}"
}

fig_parser_add_opt() {
    if [ -z "${__FIG_PARSER}" ] ; then
        fig_log_err "no active parser, did you forget to call fig_parser_begin!"
        return 1
    fi
    local TYPE ARG VALUE DEFAULT FLAGS SHORT LONG SHORT_US LONG_US PRIMARY \
          DESC CASE SHIFT HELP GETOPTARG
    TYPE="${1}"
    ARG="none"
    VALUE=""
    DEFAULT="$(echo "${2}" | tr '=' ' ' | awk '{print $2}')"
    FLAGS="$(echo "${2}" | tr '=' ' ' | awk '{print $1}')"
    SHORT="$(echo "${FLAGS}" | tr ',' ' ' | awk '{print $1}')"
    LONG="$(echo "${FLAGS}" | tr ',' ' ' | awk '{print $2}')"
    SHORT_US="$(echo "${SHORT}" | tr '-' '_')"
    LONG_US="$(echo "${LONG}" | tr '-' '_')"
    PRIMARY="${LONG_US}"
    DESC="${3}"
    CASE=""
    SHIFT=""
    HELP="  "
    GETOPTARG=""

    if [ "$(echo -n "${SHORT}" | wc -c)" -gt 1 ] ; then
        if [ -n "${LONG}" ] ; then
            fig_log_err "invalid short option '${SHORT}' provided!"
            return 1
        fi
        LONG="${SHORT}"
        LONG_US="${SHORT_US}"
        PRIMARY="${SHORT_US}"
        SHORT=""
        SHORT_US=""
    fi

    if [ -z "${LONG_US}" ] ; then
        PRIMARY="${SHORT_US}"
    fi

    case "${TYPE}" in
        flag)
            VALUE="=true"
            DEFAULT="false"
            ;;
        option)
            ARG="required"
            VALUE="=\"\${2}\""
            DEFAULT="\"${DEFAULT:-""}\""
            ;;
        array)
            ARG="required"
            VALUE="+=\" \${2} \""
            DEFAULT="\"${DEFAULT:-""}\""
            ;;
        *)
            fig_log_err "unknown option type '${TYPE}'!"
            return 1
            ;;
    esac

    case "${ARG}" in
        none)
            ;;
        required)
            GETOPTARG=":"
            SHIFT=" 2"
            ;;
        optional)
            GETOPTARG="::"
            SHIFT=" 2"
            ;;
    esac

    if [ -n "${SHORT}" ] ; then
        __FIG_PARSER_SHORT+="${SHORT}${GETOPTARG}"
        CASE="-${SHORT}"
        HELP+="-${SHORT}"
    fi
    if [ -n "${LONG}" ] ; then
        __FIG_PARSER_LONG+="${LONG}${GETOPTARG},"
        if [ -n "${SHORT}" ] ; then
            CASE+="|"
            HELP+=", "
        fi
        CASE+="--${LONG}"
        HELP+="--${LONG}"
    fi

    if [ "${ARG}" == "required" ] ; then
        HELP+=" <argument>"
    elif [ "${ARG}" == "optional" ] ; then
        HELP+=" [argument]"
    fi

    __FIG_PARSER_HELP+="${HELP}
$(echo "${DESC}" | fold -w 76 -s - | sed 's/[[:space:]]*$//' | sed 's/^/    /')
"

    __FIG_PARSER_PRE+="OPT_${__FIG_PARSER}_${PRIMARY}_set=false
OPT_${__FIG_PARSER}_${PRIMARY}=${DEFAULT}
"

    __FIG_PARSER_CASE+="${CASE})
    OPT_${__FIG_PARSER}_${PRIMARY}_set=true
    OPT_${__FIG_PARSER}_${PRIMARY}${VALUE}
    shift${SHIFT}
    ;;
"
}

fig_parser_add_env() {
    local NAME DEFAULT DESC HELP
    NAME="$(echo "${1}" | tr '=' ' ' | awk '{print $1}')"
    DEFAULT="$(echo "${1}" | tr '=' ' ' | awk '{print $2}')"
    DESC="${2}"
    HELP="<value>"

    __FIG_PARSER_ENV=true

    if [ -n "${DEFAULT}" ] ; then
        HELP="[value] (default: \\\"${DEFAULT}\\\")"
        __FIG_PARSER_ENV_DEFAULTS+="${NAME}=\"\${${NAME}:-\"${DEFAULT}\"}\"
"
    fi

    __FIG_PARSER_HELP_ENV+="  ${NAME}=${HELP}
$(echo "${DESC}" | fold -w 76 -s - | sed 's/[[:space:]]*$//' | sed 's/^/    /')
"
}

fig_parser_add_pos_arg() {
    local NAME DEFAULT DESC
    NAME="$(echo "${1}" | awk -F '=' '{print $1}')"
    DEFAULT="$(echo "${1}" | awk -F '=' '{print $2}')"
    DESC="${2}"

    __FIG_PARSER_POS_ARGS=true
    __FIG_PARSER_POS_ARGS_NAMES+=" ${NAME} "
    __FIG_PARSER_PRE+=$(cat <<EOF
OPT_${__FIG_PARSER}_pos_${NAME}_set=false
OPT_${__FIG_PARSER}_pos_${NAME}="${DEFAULT}"
EOF
    )
    __FIG_PARSER_PRE+=$'\n'
    if [ -n "${DEFAULT}" ] ; then
        DEFAULT=" (default: ${DEFAULT})"
    fi
    if [ -n "${DESC}" ] ; then
        DESC="$(echo "${DESC}" | fold -w 76 -s - | sed 's/[[:space:]]*$//' | sed 's/^/    /')"
    fi
    __FIG_PARSER_HELP_POS+=$'\n'
    __FIG_PARSER_HELP_POS+=$(cat <<EOF
  ${NAME}${DEFAULT}
${DESC}
EOF
    )
}

fig_parser_end() {
     if [ -z "${__FIG_PARSER}" ] ; then
        fig_log_err "no active parser, did you forget to call fig_parser_begin!"
        return 1
    fi

    __FIG_SCRIPT+='
# pure-getopt, a drop-in replacement for GNU getopt in pure Bash.
# version 1.4.5
#
# Copyright 2012-2021 Aron Griffis <aron@scampersand.com>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
'

    fig_export pure-getopt

    __FIG_SCRIPT+="
print_help_${__FIG_PARSER} ()
{
    echo \""
    if ${__FIG_PARSER_USAGE} ; then
        __FIG_SCRIPT+="Usage:
  \${0} [options]

"
    fi
    if [ -n "${__FIG_PARSER_DESC}" ] ; then
        __FIG_SCRIPT+="    ${__FIG_PARSER_DESC}

"
    fi
    __FIG_SCRIPT+="${__FIG_PARSER_HELP//^\n$/}"
    if ${__FIG_PARSER_ENV} ; then
        __FIG_SCRIPT+="
${__FIG_PARSER_HELP_ENV//^\n$/}"
    fi
    if ${__FIG_PARSER_POS_ARGS} ; then
        __FIG_SCRIPT+="${__FIG_PARSER_HELP_POS//^\n$/}"
    fi
    __FIG_SCRIPT+="\"
}
"
    __FIG_SCRIPT+="
parse_opts_${__FIG_PARSER} ()
{
    local ERR=\$(pure-getopt -Q -o ${__FIG_PARSER_SHORT} --long ${__FIG_PARSER_LONG} -- \"\$@\" 2>&1)
    local ARGS=\$(pure-getopt -q -o ${__FIG_PARSER_SHORT} --long ${__FIG_PARSER_LONG} -- \"\$@\")
    eval set -- \"\${ARGS}\"

    if [ -n \"\${ERR}\" ] ; then
        fig_log_err \"\$(echo \"\${ERR}\" | sed 's/getopt: //')\"
        print_help_${__FIG_PARSER}
        return 1
    fi

$(echo "${__FIG_PARSER_PRE}" | sed 's/^/    /' | sed 's/^[[:space:]]*$//' )

    while true ; do
        case \"\$1\" in
            -h|--help)
                print_help_${__FIG_PARSER}
                exit 0
                ;;
$(echo "${__FIG_PARSER_CASE}" | sed 's/^/            /' | sed 's/^[[:space:]]*$//')
            --)
                shift
                break
                ;;
            *)
                fig_log_err \"unknown argument!\"
                print_help_${__FIG_PARSER}
                return 1
                ;;
        esac
    done

"
    if ! "${__FIG_PARSER_POS_ARGS}" ; then
        __FIG_SCRIPT+=$(cat <<EOF
    if [ -n "\${1}" ] ; then
        fig_log_err "unhandled positional arguments!"
        return 1
    fi
}
EOF
        )
    else
        for POSARG in ${__FIG_PARSER_POS_ARGS_NAMES} ; do
            __FIG_SCRIPT+=$(cat <<EOF
    if [ -n "\${1}" ] ; then
        OPT_${__FIG_PARSER}_pos_${POSARG}_set=true
        OPT_${__FIG_PARSER}_pos_${POSARG}="\${1}"
        shift
    fi
EOF
            )
            __FIG_SCRIPT+=$'\n'
        done
        __FIG_SCRIPT+=$(cat <<EOF
    if [ -n "\${1}" ] ; then
        fig_log_err "extra positional arguments provided!"
        return 1
    fi
}
EOF
        )
    fi

    __FIG_SCRIPT+=$'\n'
}

###############################################################################
# ANSI
###############################################################################

fig_ansi_term_width() {
    tput cols
}

fig_ansi_term_height() {
    tput lines
}

fig_ansi_term_colors() {
    tput colors
}

fig_ansi_cursor_hide() {
    tput civis
}

fig_ansi_cursor_show() {
    tput cnorm
}

fig_ansi_cursor_home() {
    tput home
}

fig_ansi_cursor_move() {
    tput cup "${1}" "${2}"
}

fig_ansi_cursor_move_up() {
    while [ -n "${1}" ] && [ "${1}" -gt "0" ] ; do
        tput cuu1
        ((1--))
    done
}

fig_ansi_cursor_move_down() {
    while [ -n "${1}" ] && [ "${1}" -gt "0" ] ; do
        tput cud1
        ((1--))
    done
}

fig_ansi_cursor_move_right() {
    tput cuf "${1:-1}"
}

fig_ansi_cursor_move_left() {
    tput cub "${1:-1}"
}

fig_ansi_cursor_save() {
    tput sc
}

fig_ansi_cursor_restore() {
    tput rc
}

fig_ansi_erase_to_screen_end() {
    printf '\e[0J'
}

fig_ansi_erase_to_screen_begin() {
    printf '\e[1J'
}

fig_ansi_erase_screen() {
    tput clear
}

fig_ansi_erase_to_line_end() {
    tput el
}

fig_ansi_erase_to_line_begin() {
    tput el1
}

fig_ansi_erase_line() {
    printf '\e[2K'
}

fig_ansi_color_foreground() {
    tput setaf "${1:-0}"
}

fig_ansi_color_background() {
    tput setab "${1:-0}"
}

fig_ansi_color_clear_background() {
    if tput bce ; then
        clear
    else
        local blank_screen i term_width term_height
        term_width="$(tput cols)"
        term_height="$(tput lines)"
        blank_screen=""
        for ((i=0; i < (term_width * term_height); i++)) ; do
            blank_screen+=" "
        done
        tput home
        echo -n "${blank_screen}"
    fi
}

fig_ansi_rgb_foreground() {
    printf '\e[38;2;%s;%s;%sm' "${1:-0}" "${2:-0}" "${3:-0}"
}

fig_ansi_rgb_background() {
    printf '\e[48;2;%s;%s;%sm' "${1:-0}" "${2:-0}" "${3:-0}"
}

fig_ansi_style_bold() {
    tput bold
}

fig_ansi_style_dim() {
    tput dim
}

fig_ansi_style_italic() {
    tput sitm
}

fig_ansi_style_underline() {
    tput smul
}

fig_ansi_style_blink() {
    tput blink
}

fig_ansi_style_inverse() {
    printf '\e[7m'
}

fig_ansi_style_invisible() {
    tput invis
}

fig_ansi_style_strike() {
    printf '\e[9m'
}

fig_ansi_style_reset_bold() {
    printf '\e[22m'
}

fig_ansi_style_reset_dim() {
    printf '\e[22m'
}

fig_ansi_style_reset_italic() {
    tput ritm
}

fig_ansi_style_reset_underline() {
    tput rmul
}

fig_ansi_style_reset_blink() {
    printf '\e[25m'
}

fig_ansi_style_reset_inverse() {
    printf '\e[27m'
}

fig_ansi_style_reset_invisible() {
    printf '\e[28m'
}

fig_ansi_style_reset_strike() {
    printf '\e[29m'
}

fig_ansi_style_reset() {
    tput sgr0
}

fig_ansi_screen_save() {
    tput smcup
}

fig_ansi_screen_restore() {
    tput rmcup
}

fig_ansi_reset_all() {
    (
    tput sgr0
    tput cnorm
    tput rmcup
    ) || clear
}

fig_export_ansi() {
    fig_export fig_ansi_term_width
    fig_export fig_ansi_term_height
    fig_export fig_ansi_term_colors
    fig_export fig_ansi_cursor_hide
    fig_export fig_ansi_cursor_show
    fig_export fig_ansi_cursor_home
    fig_export fig_ansi_cursor_move
    fig_export fig_ansi_cursor_move_up
    fig_export fig_ansi_cursor_move_down
    fig_export fig_ansi_cursor_move_right
    fig_export fig_ansi_cursor_move_left
    fig_export fig_ansi_cursor_save
    fig_export fig_ansi_cursor_restore
    fig_export fig_ansi_erase_to_screen_end
    fig_export fig_ansi_erase_to_screen_begin
    fig_export fig_ansi_erase_screen
    fig_export fig_ansi_erase_to_line_end
    fig_export fig_ansi_erase_to_line_begin
    fig_export fig_ansi_erase_line
    fig_export fig_ansi_color_foreground
    fig_export fig_ansi_color_background
    fig_export fig_ansi_color_clear_background
    fig_export fig_ansi_rgb_foreground
    fig_export fig_ansi_rgb_background
    fig_export fig_ansi_style_bold
    fig_export fig_ansi_style_dim
    fig_export fig_ansi_style_italic
    fig_export fig_ansi_style_underline
    fig_export fig_ansi_style_blink
    fig_export fig_ansi_style_inverse
    fig_export fig_ansi_style_invisible
    fig_export fig_ansi_style_strike
    fig_export fig_ansi_style_reset_bold
    fig_export fig_ansi_style_reset_dim
    fig_export fig_ansi_style_reset_italic
    fig_export fig_ansi_style_reset_underline
    fig_export fig_ansi_style_reset_blink
    fig_export fig_ansi_style_reset_inverse
    fig_export fig_ansi_style_reset_invisible
    fig_export fig_ansi_style_reset_strike
    fig_export fig_ansi_style_reset
    fig_export fig_ansi_screen_save
    fig_export fig_ansi_screen_restore
    fig_export fig_ansi_reset_all
}

###############################################################################
# PROGRESS
###############################################################################

fig_progress() {
    fig_assert wc

    local CURRENT TOTAL PERCENT NUM_CHRS WIDTH i STRING MESSAGE STYLE MESSAGE_LEN
    local SEPERATOR SEPERATOR_LEN
    CURRENT="${1}"
    TOTAL="${2}"
    MESSAGE="${3}"
    WIDTH="${COLUMNS:-80}"
    PERCENT=$((CURRENT * 100 / TOTAL))
    STYLE="${FIG_PROGRESS_STYLE:-1}"
    SEPERATOR='  '

    if [[ "${STYLE}" =~ [^0-4] ]] ; then
        STYLE="1"
    fi

    case "${STYLE}" in
        0)
            MESSAGE=''
            SEPERATOR=''
            ;;
        1|2)
            if [ -z "${MESSAGE}" ] ; then
                local TOTAL_WIDTH FMT
                TOTAL_WIDTH="$(echo "${TOTAL}" | wc --chars)"
                FMT="%${TOTAL_WIDTH}s/%s (%3d%%)"
                # shellcheck disable=SC2059
                MESSAGE="$(printf "${FMT}" "${CURRENT}" "${TOTAL}" "${PERCENT}")"
            fi
            ;;
        3|4)
            MESSAGE="$(printf '%3d%%' "${PERCENT}")"
            ;;
    esac

    MESSAGE_LEN="$(echo "${MESSAGE}" | wc --chars)"
    SEPERATOR_LEN="$(echo "${SEPERATOR}" | wc --chars)"

    if [ "$((WIDTH - MESSAGE_LEN - SEPERATOR_LEN))" -lt 10 ] ; then
        STYLE='0'
        SEPERATOR=''
        SEPERATOR_LEN='0'
        MESSAGE=''
        MESSAGE_LEN='0'
    fi

    WIDTH=$((WIDTH - MESSAGE_LEN - SEPERATOR_LEN))
    NUM_CHRS=$((PERCENT * WIDTH / 100))

    local CHAR_BEGIN CHAR_END CHAR_FILL CHAR_EMPTY
    CHAR_BEGIN="${FIG_PROGRESS_CHAR_BEGIN:-[}"
    CHAR_END="${FIG_PROGRESS_CHAR_END:-]}"
    CHAR_FILL="${FIG_PROGRESS_CHAR_FILL:-=}"
    CHAR_EMPTY="${FIG_PROGRESS_CHAR_EMPTY:- }"

    local COLOR_BAR COLOR_MESSAGE
    COLOR_BAR="${FIG_PROGRESS_COLOR_BAR}"
    COLOR_MESSAGE="${FIG_PROGRESS_COLOR_MESSAGE}"

    MESSAGE="${COLOR_MESSAGE}${MESSAGE}$(fig_ansi_style_reset)"

    STRING="${COLOR_BAR}"
    STRING+="${CHAR_BEGIN}"

    for ((i = 0; i < NUM_CHRS; i++)) ; do
        STRING+="${CHAR_FILL}"
    done
    for ((i = NUM_CHRS; i < WIDTH; i++)) ; do
        STRING+="${CHAR_EMPTY}"
    done

    STRING+="${CHAR_END}"
    STRING+="$(fig_ansi_style_reset)"

    case "${STYLE}" in
        0)
            printf "\r%s" "${STRING}"
            ;;
        1|3)
            printf "\r%s%s%s" "${STRING}" "${SEPERATOR}" "${MESSAGE}"
            ;;
        2|4)
            printf "\r%s%s%s" "${MESSAGE}" "${SEPERATOR}" "${STRING}"
            ;;
    esac

    if [ "${PERCENT}" -eq 100 ] ; then
        echo
    fi
}

fig_export_progress() {
    fig_export_ansi
    fig_export fig_progress
}

# shellcheck disable=SC1090
. "${__FIG_SRC_SCRIPT}"

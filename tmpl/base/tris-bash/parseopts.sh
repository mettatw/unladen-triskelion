#!/usr/bin/env bash
# Parse command-line options in shell script
# This script is a derived work of "parse_options.sh" from Kaldi project
# ( http://kaldi.sourceforge.net/ )
# located at (root)/egs/wsj/s5/utils/
# which is released with Apache 2.0 license
# Copyright 2012  Johns Hopkins University (Author: Daniel Povey);
#                 Arnab Ghoshal, Karel Vesely

# Parse command-line options.
# To be sourced by another script (as in ". parse_options.sh").
# Option format is: --option-name=arg or option-name=arg
# and shell variable "option_name" gets set to value "arg"
# The exceptions are --help|-h, which takes no arguments, but prints the
# $tris_help_message variable (if defined), and --config, which reads a config file as options

if [ -z "${TRIS_VERSION-}" ]; then # only need to check if not already in TRIS environment
  if [ -z ${BASH+xxx} ]; then # Need compatibility in this part, since we aren't sure being in bash yet...
    echo "$0: you need real BASH to run this script, sh, zsh, tcsh or dash won't work" >&2
    exit 32
  fi
fi
set +o posix # or these weird function names will not work

# Simple function to check if the specified variable is array
__::is_array() {
  local dec="$(declare -p "$1" 2> /dev/null)"
  [[ "${dec:8:2}" == "-a" ]]
}

__::errexit() {
  local msg="$1"
  printf "%s\n" "${tris_help_message-}" >&2
  printf '%.0s-' {1..75} >&2
  printf '\n' >&2
  echo "Error: $1" >&2
  echo "Command line is:" >&2
  echo "$TRIS_COMMANDLINE_ORIGINAL" >&2
  exit 5
}

# $1 should be in the form of --name=value or name=value
__::parse_one_option() {
  local optionname="${1%%=*}"
  optionname="${optionname#--}"
  optionname="${optionname//-/_}"
  local value="${1#*=}"

  # Read a config file
  if [[ "${optionname}" == "config" ]]; then
    if [[ ! -f "${value}" && ! -h "${value}" ]]; then
      __::errexit "Config file ${value} not found"
    fi
    local thisline
    while IFS=$'\n' read -r thisline; do
      if [[ -n "${thisline}" ]]; then
        __::parse_one_option "${thisline}"
      fi
    done < <(cat "${value}"; echo) # to ensure newline
    return
  fi

  if __::is_array "$optionname"; then # Special situation: array
    eval "$optionname[\${#$optionname[@]}]=\"${value}\""
    return
  fi

  # Normal situation: not array
  if [[ -z "${!optionname+xxxx}" ]]; then  # if this option does not exist
    __::errexit "invalid option: $1"
  fi

  # Set the variable to the right value-- the escaped quotes make it work if
  # the option had spaces, like --cmd "queue.pl -sync y"
  eval "export $optionname=\"${value}\""
  return
}

export TRIS_COMMANDLINE_ORIGINAL="$0 $@"
# Get TRIS_DEFAULTARG_xxx from environment variable
for varArg in $(compgen -A variable TRIS_DEFAULTARG_); do
  nameArg="${varArg#TRIS_DEFAULTARG_}"
  if [[ -n "${!nameArg+xxxx}" ]]; then
    __::parse_one_option "$nameArg=${!varArg}"
  fi
  TRIS_COMMANDLINE_ORIGINAL+=" #(var:$nameArg=${!varArg})"
  unset nameArg
done; unset varArg

# Now start parsing the real command line options
__programargs=()
while true; do
  if [[ -z "${1:-}" ]]; then break; fi  # break if there are no arguments
  if [[ "${TRIS_DO_NOT_PARSE-}" == 1 ]]; then break; fi
  if [[ "$1" == "--" ]]; then # anything followed by -- is not parsed
    shift 1
    __programargs+=("$@")
    break
  fi

  case "$1" in
  # If the enclosing script is called with --help option, print the help
  # message and exit.  Scripts should put help messages in $tris_help_message
  --help|-h)
    if [[ -z "${tris_help_message-}" ]]; then
      echo "No help found." 1>&2
    else
      printf "%s\n" "$tris_help_message" 1>&2
    fi
    exit 0 ;;
  --*=*)
    __::parse_one_option "$1"
    shift 1
    ;;
  *=*) # No -- prefix: this also works
    __::parse_one_option "$1"
    shift 1
    ;;
  --*)
    __::parse_one_option "$1=true"
    shift 1
    ;;
  *)
    __programargs+=("$1")
    shift 1
    ;;
  esac
done
set -- "${__programargs[@]+${__programargs[@]}}"

unset __programargs
unset -f __::parse_one_option
unset -f __::errexit
unset -f __::is_array

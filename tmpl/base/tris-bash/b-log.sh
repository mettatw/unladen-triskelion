# extracted from https://github.com/idelsink/b-log
# which is published by Ingmar Delsink with MIT license
[ -n "${B_LOG_SH+x}" ] && return || readonly B_LOG_SH=1
B_LOG_APPNAME="b-log"
B_LOG_VERSION=1.2.0
readonly LOG_LEVEL_OFF=0        # none
readonly LOG_LEVEL_FATAL=100    # unusable, crash
readonly LOG_LEVEL_ERROR=200    # error conditions
readonly LOG_LEVEL_WARN=300     # warning conditions
readonly LOG_LEVEL_NOTICE=400   # Nothing serious, but notably nevertheless.
readonly LOG_LEVEL_INFO=500     # informational
readonly LOG_LEVEL_DEBUG=600    # debug-level messages
readonly LOG_LEVEL_TRACE=700    # see stack traces
readonly LOG_LEVEL_ALL=-1       # all enabled
B_LOG_DEFAULT_TEMPLATE="[@23:1@][@6:2@][@3@:@3:4@] @5@"  # default template
LOG_LEVELS=(
"${LOG_LEVEL_FATAL}"  "FATAL"  "${B_LOG_DEFAULT_TEMPLATE}" "\e[41;37m" "\e[0m"
"${LOG_LEVEL_ERROR}"  "ERROR"  "${B_LOG_DEFAULT_TEMPLATE}" "\e[1;31m" "\e[0m"
"${LOG_LEVEL_WARN}"   "WARN"   "${B_LOG_DEFAULT_TEMPLATE}" "\e[1;33m" "\e[0m"
"${LOG_LEVEL_NOTICE}" "NOTICE" "${B_LOG_DEFAULT_TEMPLATE}" "\e[1;32m" "\e[0m"
"${LOG_LEVEL_INFO}"   "INFO"   "${B_LOG_DEFAULT_TEMPLATE}" "\e[37m" "\e[0m"
"${LOG_LEVEL_DEBUG}"  "DEBUG"  "${B_LOG_DEFAULT_TEMPLATE}" "\e[1;34m" "\e[0m"
"${LOG_LEVEL_TRACE}"  "TRACE"  "${B_LOG_DEFAULT_TEMPLATE}" "\e[94m" "\e[0m"
)
readonly LOG_LEVELS_LEVEL=0
readonly LOG_LEVELS_NAME=1
readonly LOG_LEVELS_TEMPLATE=2
readonly LOG_LEVELS_PREFIX=3
readonly LOG_LEVELS_SUFFIX=4
LOG_LEVEL=${LOG_LEVEL_WARN}     # current log level
B_LOG_LOG_VIA_STDOUT=true       # log via stdout
B_LOG_LOG_VIA_FILE=""           # file if logging via file (file, add suffix, add prefix)
B_LOG_LOG_VIA_FILE_PREFIX=false # add prefix to log file
B_LOG_LOG_VIA_FILE_SUFFIX=false # add suffix to log file
B_LOG_LOG_VIA_SYSLOG=""         # syslog flags so that "syslog 'flags' message"
B_LOG_TS=""                     # timestamp variable
B_LOG_TS_FORMAT="%Y-%m-%d %H:%M:%S.%N" # timestamp format
B_LOG_LOG_LEVEL_NAME=""         # the name of the log level
B_LOG_LOG_MESSAGE=""            # the log message
function B_LOG_ERR() {
local return_code=${1:-0}
local return_message=${2:=""}
local prefix="\e[1;31m" # error color
local suffix="\e[0m"    # error color
if [ $return_code -eq 1 ]; then
echo -e "${prefix}${return_message}${suffix}"
fi
}
function B_LOG(){
local OPTIND=""
for arg in "$@"; do # transform long options to short ones
shift
case "$arg" in
"--help") set -- "$@" "-h" ;;
"--version") set -- "$@" "-V" ;;
"--log-level") set -- "$@" "-l" ;;
"--date-format") set -- "$@" "-d" ;;
"--stdout") set -- "$@" "-o" ;;
"--file") set -- "$@" "-f" ;;
"--file-prefix-enable") set -- "$@" "-a" "file-prefix-enable" ;;
"--file-prefix-disable") set -- "$@" "-a" "file-prefix-disable" ;;
"--file-suffix-enable") set -- "$@" "-a" "file-suffix-enable" ;;
"--file-suffix-disable") set -- "$@" "-a" "file-suffix-disable" ;;
"--syslog") set -- "$@" "-s" ;;
*) set -- "$@" "$arg"
esac
done
while getopts "hVd:o:f:s:l:a:" optname
do
case "$optname" in
"h")
PRINT_USAGE
;;
"V")
echo "${B_LOG_APPNAME} v${B_LOG_VERSION}"
;;
"d")
B_LOG_TS_FORMAT=${OPTARG}
;;
"o")
if [ "${OPTARG}" = true ]; then
B_LOG_LOG_VIA_STDOUT=true
else
B_LOG_LOG_VIA_STDOUT=false
fi
;;
"f")
B_LOG_LOG_VIA_FILE=${OPTARG}
;;
"a")
case ${OPTARG} in
'file-prefix-enable' )
B_LOG_LOG_VIA_FILE_PREFIX=true
;;
'file-prefix-disable' )
B_LOG_LOG_VIA_FILE_PREFIX=false
;;
'file-suffix-enable' )
B_LOG_LOG_VIA_FILE_SUFFIX=true
;;
'file-suffix-disable' )
B_LOG_LOG_VIA_FILE_SUFFIX=false
;;
*)
;;
esac
;;
"s")
B_LOG_LOG_VIA_SYSLOG=${OPTARG}
;;
"l")
LOG_LEVEL=${OPTARG}
;;
*)
B_LOG_ERR '1' "unknown error while processing B_LOG option."
;;
esac
done
shift "$((OPTIND-1))" # shift out all the already processed options
}
function B_LOG_get_log_level_info() {
local log_level=${1:-"$LOG_LEVEL_ERROR"}
LOG_FORMAT=""
LOG_PREFIX=""
LOG_SUFFIX=""
local i=0
for ((i=0; i<${#LOG_LEVELS[@]}; i+=$((LOG_LEVELS_SUFFIX+1)))); do
if [[ "$log_level" == "${LOG_LEVELS[i]}" ]]; then
B_LOG_LOG_LEVEL_NAME="${LOG_LEVELS[i+${LOG_LEVELS_NAME}]}"
LOG_FORMAT="${LOG_LEVELS[i+${LOG_LEVELS_TEMPLATE}]}"
LOG_PREFIX="${LOG_LEVELS[i+${LOG_LEVELS_PREFIX}]}"
LOG_SUFFIX="${LOG_LEVELS[i+${LOG_LEVELS_SUFFIX}]}"
return 0
fi
done
return 1
}
function B_LOG_convert_template() {
local template=${*:-}
local selector=0
local str_length=0
local to_replace=""
local log_layout_part=""
local found_pattern=true
B_LOG_CONVERTED_TEMPLATE_STRING=""
while $found_pattern ; do
if [[ "${template}" =~ @[0-9]+@ ]]; then
to_replace=${BASH_REMATCH[0]}
selector=${to_replace:1:(${#to_replace}-2)}
elif [[ "${template}" =~ @[0-9]+:[0-9]+@ ]]; then
to_replace=${BASH_REMATCH[0]}
if [[ "${to_replace}" =~ @[0-9]+: ]]; then
str_length=${BASH_REMATCH[0]:1:(${#BASH_REMATCH[0]}-2)}
else
str_length=0
fi
if [[ "${to_replace}" =~ :[0-9]+@ ]]; then
selector=${BASH_REMATCH[0]:1:(${#BASH_REMATCH[0]}-2)}
fi
else
found_pattern=false
fi
case "$selector" in
1) # timestamp
log_layout_part="${B_LOG_TS}"
;;
2) # log level name
log_layout_part="${B_LOG_LOG_LEVEL_NAME}"
;;
3) # function name
log_layout_part="${FUNCNAME[3]}"
;;
4) # line number
log_layout_part="${BASH_LINENO[2]}"
;;
5) # message
log_layout_part="${B_LOG_LOG_MESSAGE}"
;;
6) # space
log_layout_part=" "
;;
7) # file name
log_layout_part="$(basename ${BASH_SOURCE[3]})"
;;
*)
B_LOG_ERR '1' "unknown template parameter: '$selector'"
log_layout_part=""
;;
esac
if [ ${str_length} -gt 0 ]; then # custom string length
if [ ${str_length} -lt ${#log_layout_part} ]; then
log_layout_part=${log_layout_part:0:str_length}
elif [ ${str_length} -gt ${#log_layout_part} ]; then
printf -v log_layout_part "%-0${str_length}s" $log_layout_part
fi
fi
str_length=0 # set default
template="${template/$to_replace/$log_layout_part}"
done
B_LOG_CONVERTED_TEMPLATE_STRING=${template}
return 0
}
function B_LOG_print_message() {
local file_directory=""
local err_ret_code=0
B_LOG_TS=$(date +"${B_LOG_TS_FORMAT}") # get the date
log_level=${1:-"$LOG_LEVEL_ERROR"}
if [ ${log_level} -gt ${LOG_LEVEL} ]; then # check log level
if [ ! ${LOG_LEVEL} -eq ${LOG_LEVEL_ALL} ]; then # check log level
return 0;
fi
fi
shift
local message=${*:-}
if [ -z "$message" ]; then # if message is empty, get from stdin
message="$(cat /dev/stdin)"
fi
B_LOG_LOG_MESSAGE="${message}"
B_LOG_get_log_level_info "${log_level}" || true
B_LOG_convert_template ${LOG_FORMAT} || true
if [ "${B_LOG_LOG_VIA_STDOUT}" = true ]; then
echo -ne "$LOG_PREFIX" >&2
echo -ne "${B_LOG_CONVERTED_TEMPLATE_STRING}" >&2
echo -e "$LOG_SUFFIX" >&2
fi
if [ ! -z "${B_LOG_LOG_VIA_FILE}" ]; then
file_directory=$(dirname $B_LOG_LOG_VIA_FILE)
if [ ! -z "${file_directory}" ]; then
if [ ! -d "${B_LOG_LOG_VIA_FILE%/*}" ]; then # check directory
mkdir -p "${file_directory}" || err_ret_code=$?
B_LOG_ERR "${err_ret_code}" "Error while making log directory: '${file_directory}'. Are the permissions ok?"
fi
fi
if [ ! -e "${B_LOG_LOG_VIA_FILE}" ]; then # check file
if [ $err_ret_code -ne 1 ]; then
touch "${B_LOG_LOG_VIA_FILE}" || err_ret_code=$?
B_LOG_ERR "${err_ret_code}" "Error while making log file: '${B_LOG_LOG_VIA_FILE}'. Are the permissions ok?"
fi
else
message=""
if [ "${B_LOG_LOG_VIA_FILE_PREFIX}" = true ]; then
message="${message}${LOG_PREFIX}"
fi
message="${message}${B_LOG_CONVERTED_TEMPLATE_STRING}"
if [ "${B_LOG_LOG_VIA_FILE_SUFFIX}" = true ]; then
message="${message}${LOG_SUFFIX}"
fi
echo -e "${message}" >> ${B_LOG_LOG_VIA_FILE} || true
fi
fi
if [ ! -z "${B_LOG_LOG_VIA_SYSLOG}" ]; then
logger ${B_LOG_LOG_VIA_SYSLOG} "${B_LOG_CONVERTED_TEMPLATE_STRING}" || err_ret_code=$?
B_LOG_ERR "${err_ret_code}" "Error while logging with syslog. Where these flags ok: '${B_LOG_LOG_VIA_SYSLOG}'"
fi
}
function LOG_LEVEL_OFF()    { B_LOG --log-level ${LOG_LEVEL_OFF} "$@"; }
function LOG_LEVEL_FATAL()  { B_LOG --log-level ${LOG_LEVEL_FATAL} "$@"; }
function LOG_LEVEL_ERROR()  { B_LOG --log-level ${LOG_LEVEL_ERROR} "$@"; }
function LOG_LEVEL_WARN()   { B_LOG --log-level ${LOG_LEVEL_WARN} "$@"; }
function LOG_LEVEL_NOTICE() { B_LOG --log-level ${LOG_LEVEL_NOTICE} "$@"; }
function LOG_LEVEL_INFO()   { B_LOG --log-level ${LOG_LEVEL_INFO} "$@"; }
function LOG_LEVEL_DEBUG()  { B_LOG --log-level ${LOG_LEVEL_DEBUG} "$@"; }
function LOG_LEVEL_TRACE()  { B_LOG --log-level ${LOG_LEVEL_TRACE} "$@"; }
function LOG_LEVEL_ALL()    { B_LOG --log-level ${LOG_LEVEL_ALL} "$@"; }
function B_LOG_MESSAGE() { B_LOG_print_message "$@"; }
function FATAL()    { B_LOG_print_message ${LOG_LEVEL_FATAL} "$@"; }
function ERROR()    { B_LOG_print_message ${LOG_LEVEL_ERROR} "$@"; }
function WARN()     { B_LOG_print_message ${LOG_LEVEL_WARN} "$@"; }
function NOTICE()   { B_LOG_print_message ${LOG_LEVEL_NOTICE} "$@"; }
function INFO()     { B_LOG_print_message ${LOG_LEVEL_INFO} "$@"; }
function DEBUG()    { B_LOG_print_message ${LOG_LEVEL_DEBUG} "$@"; }
function TRACE()    { B_LOG_print_message ${LOG_LEVEL_TRACE} "$@"; }

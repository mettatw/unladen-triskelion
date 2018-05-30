# misc.sh: misc functions, license: Apache-2.0 {{{

isArray() {
  # This will only work with bash
  local dec="$(declare -p "$1" 2> /dev/null)"
  [[ "${dec:8:2}" == "-a" ]]
}

isFdOpen() {
  local fd
  for fd in "$@"; do
    if { true>&$fd; } >/dev/null 2>&1; then
      continue
    else
      return 1
    fi
  done
  return 0
}

getTimeStamp() {
  if command -v date >/dev/null; then
    date +'%y%m%d.%H%M%S'
  elif command -v cmd >/dev/null; then # maybe we are on windoze?
    cmd /c date /T
  else
    echo "(date unavailable)"
  fi
}

getProperDuration() {
  local sec="$1"
  if [[ $sec -lt 60 ]]; then printf "%ds" "$sec"; return; fi
  if [[ $sec -lt 3600 ]]; then printf "%dm%ds" "$((sec/60))" "$((sec%60))"; return; fi

  local hrs="$((sec/3600))"
  sec="$((sec%3600))"
  printf "%dh%dm%ds" "$hrs" "$((sec/60))" "$((sec%60))"
  return
}

rotateLog() {
  local fname="$1"
  local nRotate="$2"
  if [[ ! -f "$fname" && ! -h "$fname" ]]; then # No need to rotate if no log at all
    return
  fi
  for i in $(seq $((nRotate-1)) -1 1); do
    if [[ -f "$fname.$i.gz" ]]; then
      mv -f "$fname.$i.gz" "$fname.$((i+1)).gz"
    fi
  done
  gzip -9c "$fname" > "$fname.1.gz"
  rm -f "$fname"
}

requestTempDir() {
  local nameVar="$1"
  local tmpl="${2:-tmp.$TRIS_SCRIPTNAME.XXXXXXXX}"
  local tmproot="${TRIS_TMPROOT-/tmp}"
  if [[ ! -d "$tmproot" ]]; then
    mkdir -p "$tmproot"
  fi
  if [[ "$tmpl" == *XXX* ]]; then
    eval "$nameVar=\"$(mktemp -d -p "$tmproot" "$tmpl")\""
  else
    eval "$nameVar=\"$tmproot/$tmpl\""
  fi
  TRIS_TMPDIR+=("${!nameVar}")
}
# TODO: clear tmpdirs
TRIS_TMPDIR=()

__TRIS::HOOK::exit::zzzRemoveTmpdir() {
  local t
  for t in "${TRIS_TMPDIR[@]+${TRIS_TMPDIR[@]}}"; do
    if [[ -z "$t" ]]; then continue; fi
    if [[ "$1" == 0 || "${TRIS_TMPFORCEDELETE-}" == 1 ]]; then # success exit
      if [[ "$t" == */tmp/* || "$t" == */.tmp/* || ( -n "${TRIS_TMPROOT-}" && "$t" == "$TRIS_TMPROOT"* ) ]]; then
        rm -rfv "$t" >&6
      else
        printWarning "Not deleting tmpdir $t, it does not look like a tmpdir"
      fi
    else
      printWarning "tmpdir: $t"
    fi
done
}

# Shortcuts to invoke things

invokeIfExist() {
  local nameFunc="$1"
  shift;
  if declare -F "$nameFunc" > /dev/null; then
    "$nameFunc" "$@"
  fi
}

invokeTrisHook() {
  local nameHook="$1"
  shift;
  local func
  for func in $(compgen -A 'function' "__TRIS::HOOK::$nameHook::"); do
    if [[ -z "$func" ]]; then continue; fi
    "$func" "$@"
  done
}

# Message functions

printScriptHeader() {
  local dateThis="$(getTimeStamp)"
  local lvl="${TRIS_LEVEL:-1}"
  local cmd="${TRIS_COMMANDLINE_ORIGINAL:-$0}"

  # Decide a symbol to print
  local listSymbol=">*+#<%=@-&"
  local numSymbol=$((($lvl-1) % ${#listSymbol}))
  TRIS_HEADER_SYMBOL="${listSymbol:$numSymbol:1}"

  if isFdOpen 6 7; then
    printf "\033[1;35m %s [%d]\033[1;33m[%s] " "$TRIS_HEADER_SYMBOL" "$lvl" "$dateThis" >&7
    printf "\033[1;34m%s\033[m\n" "$cmd" >&7
    printf "[%d][%s] " "$lvl" "$dateThis" >&6
    printf "%s\n\n" "$cmd" >&6
  else
    printf " %s [%d][%s] " "$TRIS_HEADER_SYMBOL" "$lvl" "$dateThis" >&2
    printf "%s\n\n" "$cmd" >&2
  fi
}

printScriptFooter() {
  local rtn="${1:-0}"
  local dateThis="$(getTimeStamp)"
  local durThis="$(getProperDuration $SECONDS)"
  local lvl="${TRIS_LEVEL:-1}"
  local cmd="$0"

  TRIS_HEADER_SYMBOL="${TRIS_HEADER_SYMBOL- }"

  if isFdOpen 6 7; then
    printf "\033[0;35m %s [%d]\033[33m[%s] \033[34m%s" "$TRIS_HEADER_SYMBOL" "$lvl" "$dateThis" "$cmd" >&7
    printf "[%d][%s] %s " "$lvl" "$dateThis" "$cmd" >&6
    if [[ $rtn == 0 ]]; then
      printf "\033[1;32m%s\033[m\n" "(done in $durThis)" >&7
      printf "%s\n" "(done in $durThis)" >&6
    else
      printf "\033[1;31m%s\033[m\n" "(failed in $durThis code=$rtn)" >&7
      printf "%s\n" "(failed in $durThis code=$rtn)" >&6
    fi
    printf "\033[m" >&7
  else
    printf " %s [%d][%s] %s " "$TRIS_HEADER_SYMBOL" "$lvl" "$dateThis" "$cmd" >&2
    if [[ $rtn == 0 ]]; then
      printf "%s\n" "(done in $durThis)" >&2
    else
      printf "%s\n" "(failed in $durThis code=$rtn)" >&2
    fi
  fi

  if [[ $rtn != 0 ]]; then
    if [[ -n "${TRIS_LOGFILE-}" ]]; then
      printf "See log file: %s\n" "$TRIS_LOGFILE" >&2
    fi
  fi
}

logSectionHeader() {
  local msg="$1"
  if isFdOpen 6; then
    local dateThis="$(getTimeStamp)"
    printf '\n' >&6
    printf '=%.0s' {1..75} >&6
    printf '\n+ [%s] %s\n' "$dateThis" "$msg" >&6
    printf '=%.0s' {1..75} >&6
    printf '\n\n' >&6
  fi
}

printError() {
  local msg="$1"
  local rtn="${2:-1}"
  local dateThis="$(getTimeStamp)"
  if isFdOpen 5 6; then
    printf '\033[1;31m[%s] Error: %s\033[m\n' "$dateThis" "$msg" >&5
    printf '[%s] Error: %s\n' "$dateThis" "$msg" >&6
  else
    printf '[%s] Error: %s\n' "$dateThis" "$msg" >&2
  fi

  exit $rtn
}

printWarning() {
  local msg="$1"
  local dateThis="$(getTimeStamp)"
  if isFdOpen 5 6; then
    printf '\033[1;33m[%s] Warning: %s\033[m\n' "$dateThis" "$msg" >&5
    printf '[%s] Warning: %s\n' "$dateThis" "$msg" >&6
  else
    printf '[%s] Warning: %s\n' "$dateThis" "$msg" >&2
  fi
}

printInfo() {
  local msg="$1"
  local dateThis="$(getTimeStamp)"
  if isFdOpen 5 6; then
    printf '\033[1;37m[%s] %s\033[m\n' "$dateThis" "$msg" >&5
    printf '[%s] %s\n' "$dateThis" "$msg" >&6
  else
    printf '[%s] %s\n' "$dateThis" "$msg" >&2
  fi
}

promptUser() {
  local tosilence=0
  if [[ "$1" == "-s" ]]; then
    shift
    tosilence=1
  fi

  if [[ -n "${3:-}" ]]; then
    printf ' \033[1;36m?? %s\033[m' "$1 [$3]: " >&5
  else
    printf ' \033[1;36m?? %s\033[m' "$1: " >&5
  fi

  local ANS
  if [[ $tosilence == 1 ]]; then
    read -s ANS
  else
    read ANS
  fi

  if [ -n "${3:-}" -a -z "$ANS" ]; then
    export $2="$3"
  else
    export $2="$ANS"
  fi
}

checkUserSure() {
  printf '\033[1;33m%s\033[m\n' "$1" >&5
  printf '\033[1;33mAre you sure you want to continue? (y/n)\033[m ' >&5
  local ANS
  read ANS
  if [[ "$ANS" != "y" && "$ANS" != "Y" ]]; then
    printf '\033[1;31mUser interuppted.\033[m' >&5
    exit 1
  fi
  echo >&5
}

# }}} end misc.sh

# flow.sh: basic script flows, license: Apache-2.0

# Things before parsing command line
__TRIS::FLOW::pre_parse() {
  invokeTrisHook pre_parse "$@"
}

# Basic environment & file handler setting, and print script title if needed
__TRIS::FLOW::pre_script() {
  # Open file descriptor 5 (show only, no logging) if not yet done
  if ! isFdOpen 5; then
    exec 5>&2
  fi

  # Open file descriptor 6 (logging only, no show) if not yet done
  # This is default value, may be overriden by log files later
  if ! isFdOpen 6; then
    exec 6>/dev/null
  fi

  # Ending hooks, this only work when fd 5 & 6 are open
  if declare -F __TRIS::FLOW::sigint > /dev/null; then
    trap __TRIS::FLOW::sigint SIGINT
  fi

  # File descriptor for "magic" messages alone
  if ! isFdOpen 7; then
    if [[ "${TRIS_NOTITLE-}" == 1 || "${TRIS_PRINTTITLE-}" != 1 ]]; then
      exec 7>/dev/null
    else
      exec 7>&5
    fi
  fi

  # TRIS_LEVEL: support multi-level message showing
  if [[ -z "${TRIS_LEVEL-}" ]]; then
    export TRIS_LEVEL=1;
  else
    export TRIS_LEVEL=$((TRIS_LEVEL+1))
  fi

  invokeTrisHook post_parse "$@"

  # Setup log file: if TRIS_LOGFILE is not empty, then write logs
  if [[ -n "${TRIS_LOGFILE-}" ]]; then
    if [[ -d "$TRIS_LOGFILE" ]]; then
      printError "Cannot log to $TRIS_LOGFILE, it is a directory!"
    fi
    if [[ -n "${TRIS_LOGROTATE-}" ]]; then # Do log rotation first if needed
      rotateLog "$TRIS_LOGFILE" "$TRIS_LOGROTATE"
    fi
    exec 6>>"$TRIS_LOGFILE"
    exec &> >(tee -a /dev/fd/6) # this will redirect fd1 and fd2
  fi

  printScriptHeader
  if declare -F __TRIS::FLOW::exit > /dev/null; then
    trap __TRIS::FLOW::exit EXIT
  fi

  invokeIfExist __TRIS::FLOW::check_args "$@"
  invokeTrisHook pre_script "$@"
  logSectionHeader "Start of main script"
}

__TRIS::FLOW::post_script() {
  logSectionHeader "End of main script"
  invokeTrisHook post_script "$@"
  logSectionHeader "End of post-script hooks"
}

__TRIS::FLOW::exit() {
  local rtn="$?"
  set +e
  invokeTrisHook exit "$rtn"
  printScriptFooter $rtn
}

__TRIS::FLOW::sigint() {
  printf "\e[1;31m!!forcefully killed!!\e[m" >&5
  printf "!!forcefully killed!!" >&6
}

# checkargs.sh: generated parameter checker

# Compose help message
tris_help_message="Usage: $0 [options...] "$'\n\n'
if [[ -n "${tris_description-}" ]]; then
  tris_help_message+="$tris_description"$'\n\n'
fi
tris_help_message+="$(cat <<"__EOF__OF__TRIS__HELP__MESSAGE"
* Required arguments:

!%: if is_hash_ref($_args) {
!%:   for $_args.keys().sort() -> $key {
!%:     my $thisarg = $_args[$key];
!%:     if $thisarg.required == 1 {
[% $thisarg.name %]=[% $thisarg.value %]  [% $thisarg.desc %]
!%:     }
!%:   }
!%: }

* Options:

!%: if is_hash_ref($_args) {
!%:   for $_args.keys().sort() -> $key {
!%:     my $thisarg = $_args[$key];
!%:     if $thisarg.required != 1 {
[% $thisarg.name %]=[% $thisarg.value %]  [% $thisarg.desc %]
!%:     }
!%:   }
!%: }
__EOF__OF__TRIS__HELP__MESSAGE
)"
tris_help_message+=$'\n'

!%: enabletype("int");
__TRIS::TYPECHECK::int() {
  local value="$2"
  if [[ $value =~ ^[-+]?[0-9]+$ ]]; then
    return 0;
  fi
  return 1;
}

!%: enabletype("float");
__TRIS::TYPECHECK::float() {
  local value="$2"
  if [[ $value =~ ^[-+]?[0-9]+\.?[0-9]*$ ]]; then
    return 0;
  fi
  return 1;
}

!%: enabletype("bool");
__TRIS::TYPECHECK::bool() {
  local value="$2"
  if [[ "$value" == "true" || "$value" == "false" ]]; then
    return 0;
  fi
  return 1;
}

__TRIS::FLOW::check_args() {
  local thisElement
!%: if is_hash_ref($_args) {
!%:   for $_args.keys() -> $key {
!%:
!%:     my $thisarg = $_args[$key];
!%:     if $thisarg.required == 1 {
!%:       if $thisarg.isArray == 1 {
  if [[ -z "${[% $thisarg.varname %][*]-}" ]]; then
    printf "%s\n" "${tris_help_message-}" >&2
    printError "Required argument [% $thisarg.name %] is not given"
  fi
!%:       } else {
  if [[ -z "${[% $thisarg.varname %]-}" ]]; then
    printf "%s\n" "${tris_help_message-}" >&2
    printError "Required argument [% $thisarg.name %] is not given"
  fi
!%:       } # end check is Array
!%:     } # end if option is required
!%:
!%:     if defined $thisarg.typecheck {
!%:       if ! is_hash_ref($_typecheck) || ! defined $_typecheck[$thisarg.typecheck] {
!%:         error("Invalid typecheck " . $thisarg.typecheck);
!%:       }
  if declare -F __TRIS::TYPECHECK::[% $thisarg.typecheck %] >/dev/null; then
!%:       if $thisarg.isArray == 1 {
    for thisElement in "${[% $thisarg.varname %][@]+${[% $thisarg.varname %][@]}}"; do
      if ! __TRIS::TYPECHECK::[% $thisarg.typecheck %] "[% $thisarg.name %]" "$thisElement"; then
        printError "Type error: [% $thisarg.name %]=$thisElement is not of type [% $thisarg.typecheck %]"
      fi
    done; unset thisElement
!%:       } else {
    if ! __TRIS::TYPECHECK::[% $thisarg.typecheck %] "[% $thisarg.name %]" "$[% $thisarg.varname %]"; then
      printError "Type error: [% $thisarg.name %]=$[% $thisarg.varname %] is not of type [% $thisarg.typecheck %]"
    fi
!%:       } # end check is Array
  fi
!%:     } # end if need typecheck
!%:
!%:   } # end for each option
!%: }
}

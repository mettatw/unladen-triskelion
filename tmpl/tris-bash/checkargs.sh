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

__TRIS::FLOW::check_args() {
!%: if is_hash_ref($_args) {
!%:   for $_args.keys() -> $key {
!%:     my $thisarg = $_args[$key];
!%:     if $thisarg.required == 1 {
!%:       if $thisarg.isArray == 1 {
  if [[ -z "${[% $thisarg.varname %][*]-}" ]]; then
    printError "Required argument [% $thisarg.name %] is not given"
  fi
!%:       } else {
  if [[ -z "${[% $thisarg.varname %]-}" ]]; then
    printError "Required argument [% $thisarg.name %] is not given"
  fi
!%:       }
!%:     }
!%:   }
!%: }
  true
}

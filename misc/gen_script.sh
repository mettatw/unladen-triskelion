#!/usr/bin/env bash
set -euo pipefail

# Extract cmdarg.sh
if [[ ! -d cmdarg ]]; then
  git clone --depth=1 https://github.com/akesterson/cmdarg.git
fi
DEST=../tmpl/base/tris-bash/cmdarg.sh
echo '# extracted from https://github.com/akesterson/cmdarg' > "$DEST"
echo '# which is published by Andrew Kesterson with MIT license' >> "$DEST"
# Apply set -euo pipefail patch
sed -r 's/(\$\{[][}{!_A-Za-z0-9$'"''"']+)\}/\1-}/g' cmdarg/cmdarg.sh \
  | sed -r '/^\s*(#.*)?\s*$/d; s/^\s*//' \
  >> "$DEST"

# Extract b-log.sh
if [[ ! -d b-log ]]; then
  git clone --depth=1 https://github.com/idelsink/b-log.git
fi
DEST=../tmpl/base/tris-bash/b-log.sh
echo '# extracted from https://github.com/idelsink/b-log' > "$DEST"
echo '# which is published by Ingmar Delsink with MIT license' >> "$DEST"
# awk: delete usage message
sed -r '/^\s*(#.*)?\s*$/d; s/^\s*//' b-log/b-log.sh \
  | awk '/^function PRINT_USAGE/ {todel=1} todel!=1 {print $0} /^}/ {todel=0}' \
  >> "$DEST"

cd ../tmpl/base/tris-bash
patch -Np0 <<"EOF"
--- b-log.sh.bak	2018-06-22 13:19:16.846357847 +0800
+++ b-log.sh	2018-06-22 10:52:24.812893729 +0800
@@ -219,9 +219,9 @@
 B_LOG_get_log_level_info "${log_level}" || true
 B_LOG_convert_template ${LOG_FORMAT} || true
 if [ "${B_LOG_LOG_VIA_STDOUT}" = true ]; then
-echo -ne "$LOG_PREFIX"
-echo -ne "${B_LOG_CONVERTED_TEMPLATE_STRING}"
-echo -e "$LOG_SUFFIX"
+echo -ne "$LOG_PREFIX" >&2
+echo -ne "${B_LOG_CONVERTED_TEMPLATE_STRING}" >&2
+echo -e "$LOG_SUFFIX" >&2
 fi
 if [ ! -z "${B_LOG_LOG_VIA_FILE}" ]; then
 file_directory=$(dirname $B_LOG_LOG_VIA_FILE)
EOF

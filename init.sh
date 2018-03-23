#!/usr/bin/env bash
# Initialize the whole thing
#***************************************************************************
#  Copyright 2014-2017, mettatw <mettatw@users.noreply.github.com>
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#***************************************************************************
set -euo pipefail

export PATH="$PATH:local/bin"
if command -v carton >/dev/null; then
  carton
else
  if ! command -v cpanm >/dev/null; then
    mkdir -p local/bin
    if command -v curl >/dev/null; then
      curl -Lk https://cpanmin.us/ -o local/bin/cpanm
    elif command -v wget >/dev/null; then
      wget -O local/bin/cpanm --no-check-certificate https://cpanmin.us/
    fi
    chmod a+x local/bin/cpanm
  fi
  mkdir -p local/lib/perl5
  cpanm -n -L local --installdeps .
fi

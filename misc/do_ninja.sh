#!/usr/bin/env bash
# Build a statically-linked version of ninja
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

if ! docker images | grep 'ninja_builder\s*1.8.2' >/dev/null 2>&1; then
  docker build -t ninja_builder:1.8.2 ninja_builder
fi

if ! docker images | grep 'ninja_build\s*1.8.2' >/dev/null 2>&1; then
  docker build -t ninja_build:1.8.2 ninja_build
fi

id="$(docker create ninja_build:1.8.2)"
docker cp "$id:/ninja-1.8.2/ninja" ../deps/ninja-linux-x86_64
docker rm -v "$id"

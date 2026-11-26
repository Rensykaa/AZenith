#!/system/bin/sh

# Copyright 2024 Dcx400
# Modified by: Rensykaa (fork) - AZenith boot notification
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# One boot notification after sys.boot_completed=1. Started in the background by
# service.sh, so it never blocks boot. Opt-out: $D/no_boot_notify
# Once per boot: the marker holds the boot id, so a manual rerun does not post twice.
case "$0" in */*) _bd=${0%/*} ;; *) _bd=. ;; esac
. "$_bd/common.sh"

[ -f "$D/no_boot_notify" ] && exit 0

# 180s cap: a device that never reports boot_completed must not keep this shell alive
_w=0
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    [ "$_w" -ge 180 ] && exit 0
    sleep 2
    _w=$((_w + 2))
done

_mk="$D/boot_notified"
_bid=$(cut -d- -f1 /proc/sys/kernel/random/boot_id 2>/dev/null)
if [ -f "$_mk" ]; then
    [ -n "$_bid" ] && [ "$(cat "$_mk" 2>/dev/null)" = "$_bid" ] && exit 0
fi
echo "$_bid" > "$_mk" 2>/dev/null

sleep 5
case "$(getprop persist.sys.locale)" in
    id*|in*) notify azenith "Yahoo!! AZenith sudah aktif" "AZenith" ;;
    *) notify azenith "Yahoo!! AZenith is now active" "AZenith" ;;
esac
exit 0

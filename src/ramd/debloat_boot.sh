#!/system/bin/sh

# Copyright 2024 Dcx400
# Modified by: Rensykaa (fork) - AZenith boot port of transsiondebloat()
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

# One-shot debloat, driven by persist.sys.azenithconf.debloat (default 0, never auto-on).
# Transsion-only. Runs once: waits for sys.boot_completed, waits 120s, uninstalls the fixed
# package list for user 0, then drops $D/debloat.done so later boots skip it.
# Turning the toggle off removes the marker, so re-enabling schedules the run again.
# Started in the background by service.sh; never part of the boot critical path.
# usage: debloat_boot.sh
case "$0" in */*) _bd=${0%/*} ;; *) _bd=. ;; esac
. "$_bd/common.sh"

DONE="$D/debloat.done"
LOG="$D/debloat.log"

log() { echo "$(date +%H:%M:%S) $*" >> "$LOG"; }

is_transsion() {
    case "$(getprop ro.product.manufacturer | tr 'A-Z' 'a-z')" in
        *tecno*|*infinix*|*itel*) return 0 ;;
    esac
    return 1
}

# Same lists as transsiondebloat() in transsion_customize.sh. Do not add packages here.
googlelist="com.google.android.feedback com.google.android.onetimeinitializer "
aosplist="com.android.traceur com.google.android.adservices.api com.google.mainline.adservices"
facebooklist="com.facebook.system com.facebook.services com.facebook.appmanager"
mediateklist="com.mediatek.gnss.nonframeworklbs com.mediatek.location.mtkgeofence com.mediatek.mdmconfig com.mediatek.mdmlsample com.mediatek.voiceunlock com.mediatek.ygps com.mediatek.gbaservice"
transsionlist="com.talpa.hibrowser com.transsion.carlcare com.transsion.childmode com.transsion.childmode.resoverlay com.transsion.chromecustomization com.transsion.hamal com.transsion.iotservice com.transsion.statisticalsales com.transsion.trancare"
transsiontestlist="com.debug.loggerui com.transsion.agingfunction com.transsion.kolun.aiservice com.transsion.kolun.assistant com.transsion.quicktools com.transsion.teop com.transsion.tower com.reallytek.wg com.idea.questionnaire com.goodix.gftest"

debloat() {
    n_done=0; n_skip=0; n_fail=0
    for a in $googlelist $aosplist $facebooklist $mediateklist $transsionlist $transsiontestlist; do
        # not installed for user 0: nothing to remove
        pm path "$a" >/dev/null 2>&1 || { n_skip=$((n_skip + 1)); continue; }
        if pm uninstall -k --user 0 "$a" >/dev/null 2>&1; then
            log "removed $a"
            n_done=$((n_done + 1))
        else
            log "failed $a"
            n_fail=$((n_fail + 1))
        fi
    done
    log "debloat: $n_done removed, $n_skip not installed, $n_fail failed"
}

if [ "$(getprop persist.sys.azenithconf.debloat)" != "1" ]; then
    # toggle off: forget the marker so the next enable runs again
    rm -f "$DONE"
    exit 0
fi

[ -f "$DONE" ] && exit 0
is_transsion || { log "not a Transsion device, skipped"; exit 0; }

# never block the caller: the wait alone is two minutes
(
    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
    sleep 120
    # re-check: the marker or the toggle may have changed during the wait
    [ -f "$DONE" ] && exit 0
    [ "$(getprop persist.sys.azenithconf.debloat)" = "1" ] || exit 0
    debloat
    # Marker means "attempted once", not "everything removed": a package the ROM protects
    # must not make this run again on every boot. Toggling off then on re-arms it.
    touch "$DONE"
) >/dev/null 2>&1 &
exit 0

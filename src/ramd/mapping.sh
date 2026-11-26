#!/system/bin/sh

# Copyright 2024 Dcx400
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

#main define
command -v sp >/dev/null 2>&1 || . "${MODPATH:-$MODDIR}/system/functions/common.sh"
vixun="/data/local/tmp/vixun"
mappingversion="1.0"

abort_and_cleanup() {
    rm -rf "$MODPATH"
    abort "$1"
}

pick_random() {
    set -- "$1"/*
    [ "$#" -eq 0 ] && return
    echo "$@" | tr ' ' '\n' | awk 'BEGIN{srand()} {a[NR]=$0} END{print a[int(rand()*NR)+1]}'
}

framerate() {
if [ -f "$vixun/contentframerate" ];then
	cmd display set-match-content-frame-rate-pref 0
fi
}

#cache value
cacheprop() {
[ -f "$vixunfile" ] || return 0
# keys pinned in system.prop must not be reset to the stringslog default
_pinned=" $(sed -n 's/^\([A-Za-z0-9._-]*\)=.*/\1/p' "$MODDIR/system.prop" 2>/dev/null | tr '\n' ' ')"
while read -r key value; do
[ -n "$key" ] || continue
case "$key" in *[!A-Za-z0-9._-]*|*.|.*) continue ;; esac
case "$_pinned" in *" $key "*) continue ;; esac
setprop "$key" "$value" 2>/dev/null
done < "$vixunfile"
}


brevent() {
if pm list packages -3 | grep -q brevent;then
  setprop log.tag I
  sp persist.log.tag I
fi
}

main() {
cmd shortcut override-config icon_quality=70,save_delay_ms=95000,max_updates_per_interval=2
setprop debug.perf_cpu_time_max_percent 0;setprop debug.perf_event_max_sample_rate 1;setprop debug.perf_event_mlock_kb 0
if [ "$(getprop debug.debuggerd.disable)" = "0" ]; then setprop debug.debuggerd.disable 1;fi
atrace --async_stop 1>/dev/null
cmd looper_stats reset;cmd looper_stats disable
for a in --reset --disable --disable-detailed-tracking;do dumpsys binder_calls_stats $a;done
dumpsys procstats --stop-testing
for c in ab-logging-disable dwb-logging-disable dmd-logging-disable; do cmd display $c;done
# one dumpsys window call (Proto: + Logcat: group lists); the per-group loop already covers the bare disable/disable-text
for f in $(dumpsys window 2>/dev/null | sed -n -e 's/^  Proto: //p' -e 's/^  Logcat: //p' | tr ' ' '\n'); do wm logging disable "$f"; wm logging disable-text "$f"; done
[ "$IS_ROOT" = 1 ] && for a in /sys/kernel/tracing/buffer_size_kb /sys/kernel/tracing/saved_cmdlines_size;do wr 1 "$a";done
dumpsys media.metrics --clear
cmd statusbar tracing stop;cmd accessibility stop-trace;am untrack-associations
cmd autofill set log_level off;cmd voiceinteraction set-debug-hotword-logging false
wm tracing level critical;wm tracing size 0;ime tracing stop;cmd input_method tracing stop;wm logging stop
cmd wifi set-verbose-logging disabled

eval "$(getprop | awk -F'[][]' '/^\[log\.tag/ {print "setprop " $2 " S"}' )"
setprop log.tag S
brevent
logcat -c
pkill -x logcat   # -x: exact process name only (-f also matched any app whose cmdline contains "logcat")
}

dyn_check() {
    path="$1"
    pattern="$2"
    default_value="$3"

    for prop in $(
        for target in $path; do
            if [ -f "$target" ]; then
                strings "$target"
            elif [ -d "$target" ]; then
                find "$target" -type f -exec strings {} +
            fi
        done | grep -E "$pattern" | sort -u
    ); do
        case "$prop" in
            *.|.*|*[!A-Za-z0-9._-]*) continue ;;   # invalid key, e.g. the bare prefix "debug.sf."
            [!.]*.*) ;;
            *) continue ;;
        esac
        case "$prop" in
            debug.debuggerd.wait_for_debugger|debug.debuggerd.wait_for_gdb) printf '%s false\n' "$prop" ;;
            debug.debuggerd.disable) printf '%s 1\n' "$prop" ;;
            *.dump_debug_mem_enabled|*.dump_debug_enabled|*.dump_debug_mem_at_QSubmit|*.dump_blas_info_enabled|*.dump_analysis_enabled|*.dump_vk_api_enabled) printf '%s false\n' "$prop" ;;
            *.dump_debug_mem_size_KB) printf '%s 0\n' "$prop" ;;
            *)
                [ -n "$default_value" ] && printf '%s %s\n' "$prop" "$default_value"
            ;;

        esac

    done
}

normalize_bool_set() {
  prop="$1"
  want="$2"
  current="$(getprop "$prop")"
  case "$current" in
    1|0)
      sp "$prop" "$([ "$want" = on ] && echo 1 || echo 0)"
      ;;
    true|false)
      sp "$prop" "$([ "$want" = on ] && echo true || echo false)"
      ;;
  esac
}

restore_if_marked() {
    ns="$1"
    key="$2"
    value="$3"
    marker="$4"

    [ -f "$marker" ] || return 0

    settings put "$ns" "$key" "$value"
    rm -f "$marker"
}

persist_logic() {
normalize_bool_set persist.sys.lmk.reportkills off
normalize_bool_set persist.sys.exceptionreport.support off
sp persist.sys.mdlog_dumpback 0
}

glosec_error() {
for tables in global secure; do
		if [ "$(settings get $tables send_action_app_error)" = "1" ];then
			settings put --user 0 $tables send_action_app_error 0 default
		fi
done
}

# Heavy one-shot cleanup (was in main()/xos_tweak: ran every boot).
# Runs once per install ($vixun/.done_once) from service.sh, and on demand from action.sh ("force").
hv_blobs() { cmd blob_store clear-all-blobs >/dev/null 2>&1; cmd blob_store clear-all-sessions >/dev/null 2>&1; }
hv_art() { pm art cleanup >/dev/null 2>&1; }
hv_ota() { cmd otadexopt cleanup >/dev/null 2>&1; }
hv_procstats() { dumpsys procstats --clear >/dev/null 2>&1; }
# ~2 binder calls per package: heavy. (cek) log-visibility may be in-memory only -> re-run via the Action button after reboot
hv_pkgloop() {
    cmd package list packages 2>/dev/null | cut -d: -f2 | tr -d '\r' | while read -r app; do
        [ -n "$app" ] || continue
        cmd package log-visibility --disable "$app" >/dev/null 2>&1
        cmd usagestats clear-last-used-timestamps "$app" >/dev/null 2>&1
    done
}
# Action button only (never at boot): runs the background dexopt job now, in the background. (cek) Android 14
hv_bgdexopt() { ( cmd package bg-dexopt-job >/dev/null 2>&1 & ); }
heavy_once() {
    [ "$1" = force ] || [ ! -f "$vixun/.done_once" ] || return 0
    hv_blobs; hv_art; hv_ota; hv_procstats; hv_pkgloop
    touch "$vixun/.done_once"
}

# Remove vendor apps from the Doze sys-whitelist. Idempotent: safe to call every boot.
deviceidlewipe() {
state=$(dumpsys deviceidle sys-whitelist 2>/dev/null)
for a in com.transsnet.store com.orange.update com.transsion.phonemaster com.transsion.plat.appupdate com.scorpio.securitycom tech.palm.find;do
	printf '%s\n' "$state" | grep -Eq "$a" || continue
	dumpsys deviceidle sys-whitelist -"$a"
	grep -qxF "$a" "$vixun/deviceidlewhitelist" 2>/dev/null || echo "$a" >> "$vixun/deviceidlewhitelist"
done
}

# ---- opt-in tweaks (default OFF). Enable: touch $vixun/opt_<name>, then run the Action button or reboot.
# Disable: rm the flag -> the original value is restored on the next apply. Everything is restored on uninstall.
#   opt_hdr_off          cmd display set-user-disabled-hdr-types 1 2 3 4
#   opt_haptic_off       system haptic_feedback_enabled 0
#   opt_screensaver_off  secure screensaver_enabled / screensaver_activate_on_dock 0
#   opt_ble_scan_off     global ble_scan_always_enabled 0   (can break Find My Device)
#   opt_debloat_gearhead disable com.google.android.projection.gearhead (Android Auto)
# Undo everything this section did (used by uninstall.sh / cleanup.sh before $vixun is dropped):
#   sh mapping.sh restore_optin
bk_restore_one() {  # ns key
    f="$vixun/orig/$1.$2"; [ -f "$f" ] || return 0
    v=$(cat "$f")
    if [ "$v" = null ] || [ -z "$v" ]; then settings delete "$1" "$2"; else settings put "$1" "$2" "$v"; fi
    rm -f "$f"
}
optin_setting() {  # flag ns key value
    if [ -f "$vixun/opt_$1" ]; then bk_put "$2" "$3" "$4"; else bk_restore_one "$2" "$3"; fi
}
# ---- Facemoji (Transsion keyboard): disabled only while ANOTHER keyboard (e.g. Gboard) is the default IME ----
# Never disables the keyboard in use. Re-enabled automatically if Facemoji becomes the default again.
# Opt out: touch $D/no_facemoji_disable
facemoji_apply() {
    _fm=com.facemoji.lite.transsion
    pm path "$_fm" >/dev/null 2>&1 || return 0
    _ime=$(settings get secure default_input_method 2>/dev/null)
    _dl="$vixun/debloatlist"
    if [ ! -f "$vixun/no_facemoji_disable" ] && [ -n "$_ime" ] && [ "$_ime" != null ]; then
        case "$_ime" in
            *facemoji*) ;;
            *)  if ! grep -qxF "$_fm" "$_dl" 2>/dev/null; then
                    case " $(pm list packages -d --user 0 2>/dev/null | cut -d: -f2 | tr -d '\r' | tr '\n' ' ') " in
                        *" $_fm "*) return 0 ;;   # already disabled by the user: not ours, leave it
                    esac
                    echo "$_fm" >> "$_dl"; pm disable-user --user 0 "$_fm" >/dev/null 2>&1
                fi
                return 0 ;;
        esac
    fi
    if grep -qxF "$_fm" "$_dl" 2>/dev/null; then
        pm enable --user 0 "$_fm" >/dev/null 2>&1
        grep -vxF "$_fm" "$_dl" > "$_dl.tmp"; mv "$_dl.tmp" "$_dl"
    fi
}

optin_apply() {
    if [ -f "$vixun/opt_hdr_off" ]; then
        cmd display set-user-disabled-hdr-types 1 2 3 4; touch "$vixun/.hdr_off_on"
    elif [ -f "$vixun/.hdr_off_on" ]; then
        cmd display set-user-disabled-hdr-types; rm -f "$vixun/.hdr_off_on"
    fi
    # markers from old installs (value was forced to 0 without a flag) -> back to the original
    [ -f "$vixun/opt_haptic_off" ] || restore_if_marked system haptic_feedback_enabled 1 "$vixun/haptic"
    [ -f "$vixun/opt_screensaver_off" ] || { restore_if_marked secure screensaver_enabled 1 "$vixun/screensaver"; restore_if_marked secure screensaver_activate_on_dock 1 "$vixun/screensaverondock"; }
    optin_setting haptic_off system haptic_feedback_enabled 0
    optin_setting screensaver_off secure screensaver_enabled 0
    optin_setting screensaver_off secure screensaver_activate_on_dock 0
    optin_setting ble_scan_off global ble_scan_always_enabled 0
    _g=com.google.android.projection.gearhead
    if [ -f "$vixun/opt_debloat_gearhead" ]; then
        if pm path "$_g" >/dev/null 2>&1 && ! grep -qxF "$_g" "$vixun/debloatlist" 2>/dev/null; then
            echo "$_g" >> "$vixun/debloatlist"; pm disable-user --user 0 "$_g" >/dev/null 2>&1
        fi
    elif grep -qxF "$_g" "$vixun/debloatlist" 2>/dev/null; then
        pm enable --user 0 "$_g" >/dev/null 2>&1
        grep -vxF "$_g" "$vixun/debloatlist" > "$vixun/debloatlist.tmp"; mv "$vixun/debloatlist.tmp" "$vixun/debloatlist"
    fi
    facemoji_apply
}

# Undo for uninstall: re-enable every package this section disabled, restore the backed-up
# Settings values and the HDR types. Appended to, not called by optin_apply.
restore_optin() {
    if [ -f "$vixun/.hdr_off_on" ]; then
        cmd display set-user-disabled-hdr-types 2>/dev/null; rm -f "$vixun/.hdr_off_on"
    fi
    bk_restore
    for _key in haptic screensaver screensaverondock; do
        [ -f "$vixun/$_key" ] || continue
        case "$_key" in
            haptic) settings put system haptic_feedback_enabled 1 ;;
            screensaver) settings put secure screensaver_enabled 1 ;;
            screensaverondock) settings put secure screensaver_activate_on_dock 1 ;;
        esac
        rm -f "$vixun/$_key"
    done
    [ -f "$vixun/debloatlist" ] || return 0
    # debloatlist holds what ramd disabled; facemoji is only ours while it is in the list too
    _fm=com.facemoji.lite.transsion
    if [ -f "$vixun/no_facemoji_disable" ]; then
        grep -vxF "$_fm" "$vixun/debloatlist" > "$vixun/debloatlist.tmp"; mv "$vixun/debloatlist.tmp" "$vixun/debloatlist"
    fi
    while read -r _pkg; do
        [ -n "$_pkg" ] || continue
        pm enable --user 0 "$_pkg" >/dev/null 2>&1
    done < "$vixun/debloatlist"
    rm -f "$vixun/debloatlist"
}

if [ "${0##*/}" = mapping.sh ]; then
    case "$1" in
        restore_optin) restore_optin ;;
    esac
fi

#!/system/bin/sh

# Copyright 2024 Dcx400
# Modified by: Rensykaa (fork) - AZenith boot port of the Transsion toggles
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

# Boot layer for three preference toggles (persist.sys.azenithconf.<key>):
#   sysperf     -> xos_tweak.sh (without its telemetry section) + non-duplicate keys of transsion.prop
#   telemetry   -> telemetry.txt section
#   taskprofile -> profile.sh
# Every XOS part is Transsion-only; elsewhere the script exits before touching anything.
# NOT touched here on purpose: debug.sf timing/phase-offset keys, governor, GPU, thermal.
# Keys AZenith already attributes itself (prefs.rs / system.prop) are skipped when read from the sources.
# Opt-out: $D/no_tweaks_boot (everything) | $D/no_sysperf | $D/no_telemetry | $D/no_taskprofile
# usage: tweaks_boot.sh [sysperf|telemetry|taskprofile]   (no argument = every enabled toggle)
case "$0" in */*) _bd=${0%/*} ;; *) _bd=. ;; esac
. "$_bd/common.sh"

LOG="$D/tweaks_boot.log"
log() { echo "$(date +%H:%M:%S) $*" >> "$LOG"; }

[ -f "$D/no_tweaks_boot" ] && { log "opt-out"; exit 0; }

is_transsion() {
    case "$(getprop ro.product.manufacturer | tr 'A-Z' 'a-z')" in
        *tecno*|*infinix*|*itel*) return 0 ;;
    esac
    return 1
}

# Keys AZenith sets itself (prefs.rs apply_surfaceflinger / -logd, system.prop): never re-apply from the sources
AZENITH_OWN_KEYS=" debug.sf.predict_hwc_composition_strategy debug.hwui.filter_test_overhead debug.hwui.show_layers_updates debug.hwui.capture_skp_enabled debug.hwui.trace_gpu_resources debug.hwui.skia_tracing_enabled debug.hwui.nv_profiling debug.hwui.skia_use_perfetto_track_events "
# debug.sf.* keys owned by the SF timing layer: a plain setprop here is both late and out of scope
NEVER_SF_KEYS_RE='^debug\.sf\.(hint_margin_us|cached_set_max_defer_render_attmpts|phase_offset_threshold_for_next_vsync_ns|enable_advanced_sf_phase_offset|use_phase_offsets_as_durations|disable_hwc_vds)$'

applied="$D/sysperf.applied"
# enabled <key>: true when the toggle is 1, or unset/empty (backward compatible default)
enabled() { case "$(getprop persist.sys.azenithconf.$1)" in ''|1) return 0 ;; esac; return 1; }

# ---------------------------- sysperf ----------------------------
# Transsion-only: xos_tweak.sh is written against XOS settings/device_config keys.
sysperf() {
    [ -f "$D/no_sysperf" ] && return 0
    is_transsion || { log "sysperf: not a Transsion device, skipped"; return 0; }

    rm -f "$applied"
    {
        setprop debug.hwui.use_gpu_pixel_buffers true
        setprop debug.hwui.use_buffer_age true
        setprop debug.hwui.use_partial_updates true
        setprop debug.hwui.skip_empty_damage true
        setprop debug.hwui.use_hint_manager true
        setprop debug.hwui.show_dirty_regions false
        setprop debug.hwui.profile false
        setprop debug.hwui.overdraw false
        setprop debug.hwui.show_non_rect_clip hide
        setprop debug.hwui.webview_overlays_enabled false
        setprop debug.hwui.skip_eglmanager_telemetry true
        setprop debug.hwui.memory_dump_disable true
        setprop debug.adpf_cts_verbose_logging false
        setprop debug.adpf.use_report_actual_duration false
    } >/dev/null 2>&1
    for _k in debug.hwui.use_gpu_pixel_buffers debug.hwui.use_buffer_age debug.hwui.use_partial_updates \
              debug.hwui.skip_empty_damage debug.hwui.use_hint_manager debug.hwui.show_dirty_regions \
              debug.hwui.profile debug.hwui.overdraw debug.hwui.show_non_rect_clip \
              debug.hwui.webview_overlays_enabled debug.hwui.skip_eglmanager_telemetry \
              debug.hwui.memory_dump_disable debug.adpf_cts_verbose_logging debug.adpf.use_report_actual_duration
    do echo "prop $_k" >> "$applied"; done

    # Settings (originals backed up by common.sh, restored by uninstall.sh)
    {
        bk_put global activity_starts_logging_enabled 0
        bk_put global ambient_low_bit_enabled 1
        bk_put global ambient_low_bit_enabled_dev 1
        bk_put global audio_low_latency 1
        bk_put global game_mode_game_env 1
        bk_put global mobile_data_low_latency 1
        bk_put global tran_dual_mic_support 1
        bk_put global transsion_game_accleration 1
        bk_put system background_power_saving_enable 0
        bk_put system os_action_quick_start 1
    } >/dev/null 2>&1
    for _s in "global activity_starts_logging_enabled" "global ambient_low_bit_enabled" \
              "global ambient_low_bit_enabled_dev" "global audio_low_latency" "global game_mode_game_env" \
              "global mobile_data_low_latency" "global tran_dual_mic_support" "global transsion_game_accleration" \
              "system background_power_saving_enable" "system os_action_quick_start"
    do echo "setting $_s" >> "$applied"; done

    {
        device_config put systemui enable_hw_accelerated_canvas true
        device_config put package_native_code optimizable_apps true
    } >/dev/null 2>&1
    echo "device_config systemui enable_hw_accelerated_canvas" >> "$applied"
    echo "device_config package_native_code optimizable_apps" >> "$applied"

    # transsion.prop: only the keys neither this script nor AZenith already sets
    _tp="$_bd/transsion.prop"
    if [ -f "$_tp" ]; then
        while IFS= read -r _line; do
            case "$_line" in ''|'#'*) continue ;; esac
            _k=${_line%%=*}; _v=${_line#*=}
            [ "$_k" = "$_line" ] && continue
            case "$_k" in *[!A-Za-z0-9._-]*) continue ;; esac
            case "$AZENITH_OWN_KEYS" in *" $_k "*) continue ;; esac
            grep -qxF "prop $_k" "$applied" 2>/dev/null && continue
            printf '%s' "$_k" | grep -qE "$NEVER_SF_KEYS_RE" && continue
            resetprop "$_k" "$_v" >/dev/null 2>&1 || continue
            echo "prop $_k" >> "$applied"
        done < "$_tp"
    fi

    log "sysperf: $(wc -l < "$applied" 2>/dev/null | tr -d ' ') entries applied"
}

# ---------------------------- telemetry ----------------------------
# device_config keys from telemetry.txt (the section xos_tweak.sh applies).
telemetry() {
    [ -f "$D/no_telemetry" ] && return 0
    is_transsion || { log "telemetry: not a Transsion device, skipped"; return 0; }
    _tl="$_bd/telemetry.txt"
    [ -f "$_tl" ] || { log "telemetry: telemetry.txt missing"; return 0; }
    n=0
    while read -r _ns _k _v; do
        case "$_ns" in ''|'#'*) continue ;; esac
        [ -n "$_v" ] || continue
        device_config put "$_ns" "$_k" "$_v" >/dev/null 2>&1 && n=$((n + 1))
    done < "$_tl"
    log "telemetry: $n device_config keys applied"
}

# ---------------------------- taskprofile ----------------------------
# profile.sh pushes the vendor logger threads into SCHED_SP_BACKGROUND / CPUSET_SP_RESTRICTED.
# settaskprofile needs uid 0; as shell the helper exits 0 without doing anything.
taskprofile() {
    [ -f "$D/no_taskprofile" ] && return 0
    is_transsion || { log "taskprofile: not a Transsion device, skipped"; return 0; }
    [ "$IS_ROOT" = 1 ] || { log "taskprofile: root only, skipped"; return 0; }
    [ -f "$_bd/profile.sh" ] || { log "taskprofile: profile.sh missing"; return 0; }
    sh "$_bd/profile.sh" >/dev/null 2>&1
    log "taskprofile: applied"
}

restore() {
    rm -f "$applied"
    log "restore: dropped sysperf state"
}

case "$1" in
    restore) restore ;;
    sysperf) enabled sysperf && sysperf ;;
    telemetry) enabled telemetry && telemetry ;;
    taskprofile) enabled taskprofile && taskprofile ;;
    '')
        enabled sysperf && sysperf
        enabled telemetry && telemetry
        enabled taskprofile && taskprofile
        ;;
    *) echo "usage: tweaks_boot.sh [sysperf|telemetry|taskprofile|restore]" ;;
esac
exit 0

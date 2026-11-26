#!/system/bin/sh
# ======================
# System Performance Tweaks
# ======================
# Removed (placebo / unverified, not in default): bluetooth_a2dp_codec, os_quick_start_*, os_supreme_user_experience, user_experience,
# power_check_*, io.scheduler_slice_idle, transsion-opcode_background. ble_scan_always_enabled is now opt-in (mapping.sh optin_apply).
# Settings changes go through bk_put (common.sh): the original value is saved once and restored by uninstall.sh.
case "$0" in */*) _bd=${0%/*} ;; *) _bd=. ;; esac
. "$_bd/common.sh"
tweak_setprop() { setprop "$@"; }

set_config() {
    ns="$1"; key="$2"; value="$3"
    device_config put "$ns" "$key" "$value" >/dev/null 2>&1
}


# Power and thermal configuration

# Graphics and rendering optimization
# (static debug.sf.* props moved to system.prop: SurfaceFlinger reads them at start)

# HWUI configuration
tweak_setprop debug.hwui.use_gpu_pixel_buffers true
tweak_setprop debug.hwui.use_buffer_age true
tweak_setprop debug.hwui.use_partial_updates true
tweak_setprop debug.hwui.skip_empty_damage true
tweak_setprop debug.hwui.use_hint_manager true

# Disable debug features
{
    tweak_setprop debug.hwui.show_layers_updates false
    tweak_setprop debug.hwui.capture_skp_enabled false
    tweak_setprop debug.hwui.trace_gpu_resources false
    tweak_setprop debug.hwui.skia_tracing_enabled false
    tweak_setprop debug.hwui.nv_profiling false
    tweak_setprop debug.hwui.skia_use_perfetto_track_events false
    tweak_setprop debug.hwui.show_dirty_regions false
    tweak_setprop debug.hwui.profile false
    tweak_setprop debug.hwui.overdraw false
    tweak_setprop debug.hwui.show_non_rect_clip hide
    tweak_setprop debug.hwui.webview_overlays_enabled false
    tweak_setprop debug.hwui.skip_eglmanager_telemetry true
    tweak_setprop debug.hwui.memory_dump_disable true
} >/dev/null 2>&1

# ADPF configuration
{
    tweak_setprop debug.adpf_cts_verbose_logging false
    tweak_setprop debug.adpf.use_report_actual_duration false
} >/dev/null 2>&1

# ======================
# System Settings
# ======================

# Global settings optimization
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

# Device config updates
{
    set_config systemui enable_hw_accelerated_canvas true
    set_config package_native_code optimizable_apps true
} >/dev/null 2>&1

# Telemetry/logging off (list in telemetry.txt; trimmed from Astrax/dcx402, no behavior-changing keys)
{
    _tl="${0%/*}/telemetry.txt"
    [ -f "$_tl" ] && while read -r _ns _k _v; do
        case "$_ns" in ''|'#'*) continue ;; esac
        set_config "$_ns" "$_k" "$_v"
    done < "$_tl"
} >/dev/null 2>&1

# ======================
# Dynamic Configuration
# ======================

# get_max_display_hz / cached_max_hz / get_effective_hz live in common.sh
MAX_HZ="$(cached_max_hz)"   # reuses hz_max from $D/device.info (written by detect_device)

# Disk shader-cache limit: fixed 128 MiB (was MAX_HZ MiB: no technical link to the panel rate)
tweak_setprop debug.egl.blobcache.multifile_limit "$((128 * 1024 * 1024))"

if [ -n "$MAX_HZ" ]; then
    EFF_HZ="$(get_effective_hz "$MAX_HZ")"
    echo "Transsion Optimizer: max supported ${MAX_HZ} Hz, effective ${EFF_HZ} Hz"
    # debug.sf.hint_margin_us / cached_set_max_defer_render_attmpts: SurfaceFlinger reads them once at start, so a setprop here is too late.
    # post-fs-data.sh applies them from this cached value (effective from the next boot). A/B: touch $D/no_sf_timing.
    echo "$EFF_HZ" > "$D/eff_hz" 2>/dev/null
else
    echo "Transsion Optimizer: could not detect supported display modes; skipping refresh-rate-dependent tweaks."
    rm -f "$D/eff_hz" 2>/dev/null
fi





# System cleanup
# Removed broad cleanup command list: it could clear unrelated user/system state.

# Additional cleanup
# sm fstrim does NOT run at boot (IO is busy then, and ram_daemon already schedules it).
# It runs only from the Action button (action.sh sets XOS_TRIM=1); fstrim_last is updated so the daemon does not repeat it right after.
# Heavy one-shot cleanups (procstats --clear, blob store, art/otadexopt, per-package loops) live in heavy_once (mapping.sh).
if [ "$XOS_TRIM" = "1" ]; then
    { date +%s > "$D/fstrim_last"; sm fstrim; } >/dev/null 2>&1
fi

# Disable tracing
{
    # builtin echo in a read loop: no sh fork per tracefs node
    [ "$IS_ROOT" = 1 ] && find /sys/kernel/tracing -name "enable" 2>/dev/null | while IFS= read -r _tf; do echo 0 > "$_tf"; done
    tweak_setprop debug.tracing.enabled 0
    sp persist.traced.enable 0
} >/dev/null 2>&1

# Notification
# service.sh sets XOS_QUIET_NOTIFY=1 so boot shows a single notification.
[ "$XOS_QUIET_NOTIFY" = "1" ] || notify "" 'Tweaks have been successfully applied.' "Transsion Optimizer"

#!/system/bin/sh
# Early boot: SurfaceFlinger reads debug.sf.* once at start, so these cannot wait for service.sh.
# eff_hz is cached by xos_tweak.sh (previous boot / Action). No eff_hz yet (first boot after install/upgrade): skipped, never guessed from the panel max.
D=/data/local/tmp/vixun
[ -d "$D" ] || exit 0
command -v resetprop >/dev/null 2>&1 || exit 0
[ -f "$D/opt_sf_nobackpressure" ] && resetprop debug.sf.disable_backpressure 1
[ -f "$D/no_sf_timing" ] && exit 0
hz=$(cat "$D/eff_hz" 2>/dev/null | tr -dc 0-9)
case "$hz" in ''|*[!0-9]*) exit 0 ;; esac
[ "$hz" -ge 30 ] && [ "$hz" -le 1000 ] || exit 0
resetprop debug.sf.hint_margin_us $((hz * 50 / 6))
resetprop debug.sf.cached_set_max_defer_render_attmpts $((350 / hz))
exit 0

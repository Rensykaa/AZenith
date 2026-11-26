#!/system/bin/sh
# Root layer (light, logging only). usage: root_tweaks.sh base|restore|status
# NOT touched on purpose: vm.* / zram (ZRAM module), governor / GPU / thermal (kernel + perf module).
# Opt-out: $D/no_root_base (everything) | $D/no_quiet_logd (only the vendor log daemons)
case "$0" in */*) _rb=${0%/*} ;; *) _rb=. ;; esac
. "$_rb/common.sh"
[ "$IS_ROOT" = 1 ] || { echo "root_tweaks: root only"; exit 0; }

SYSB="$D/orig_sys.list"     # node|original value (first original kept until restore)
SVCB="$D/stopped_svc"       # services stopped by this module (restarted by restore)

sw() { # sw <value> <node>
    [ -w "$2" ] || return 1
    grep -q "^$2|" "$SYSB" 2>/dev/null || echo "$2|$(head -n 1 "$2" 2>/dev/null)" >> "$SYSB"
    echo "$1" > "$2" 2>/dev/null
}
quiet_logd() { # only services that are running right now
    for s in mobile_log_d connsyslogger emdlogger1 emdlogger2 emdlogger3 emdlogger5; do
        [ "$(getprop init.svc.$s)" = running ] || continue
        grep -qx "$s" "$SVCB" 2>/dev/null || echo "$s" >> "$SVCB"
        setprop ctl.stop "$s" 2>/dev/null
    done
}
base() {
    sw "0 0 0 0" /proc/sys/kernel/printk
    [ -f "$D/no_quiet_logd" ] || quiet_logd
}
restore() {
    [ -f "$SYSB" ] && while IFS='|' read -r n v; do [ -w "$n" ] && echo "$v" > "$n"; done < "$SYSB"
    rm -f "$SYSB"
    [ -f "$SVCB" ] && while read -r s; do [ -n "$s" ] && setprop ctl.start "$s" 2>/dev/null; done < "$SVCB"
    rm -f "$SVCB"
}
status() {
    echo "printk=$(head -n 1 /proc/sys/kernel/printk 2>/dev/null)"
    echo "stopped log services: $(cat "$SVCB" 2>/dev/null | tr '\n' ' ')"
    echo "backup: $(cat "$SYSB" 2>/dev/null | tr '\n' ' ')"
}
case "$1" in
    base) base ;;
    restore) restore ;;
    status) status ;;
    *) echo "usage: root_tweaks.sh base|restore|status" ;;
esac

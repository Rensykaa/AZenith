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

# Keep install logs visible
sleep 1

. "$MODPATH/system/functions/common.sh"
. "$MODPATH/system/functions/mapping.sh"
vixunfile="$vixun/stringslog"


lang=$(getprop persist.sys.locale | cut -d- -f1)
languagepath="$MODPATH"/language

if [ -f "$languagepath/${lang}.sh" ];then
	. "${languagepath}/${lang}.sh"
else
	. "${languagepath}/en.sh"
fi

klixr_found=0
_scan="/data/adb/modules"; [ -n "$AXERONDIR" ] && _scan="$_scan $AXERONDIR/plugins"
for _mp in $(find $_scan -maxdepth 2 -iname module.prop 2>/dev/null); do
	grep -iq klixr "$_mp" 2>/dev/null && klixr_found=1
done
if [ "$klixr_found" = "1" ];then
	abort_and_cleanup "$abort_upon_check"
fi
buffer=$(getprop ro.product.manufacturer | tr '[:upper:]' '[:lower:]')
if echo $buffer | grep -qEi 'tecno|xos|infinix|itel'; then
ui_print "$foundtranssiondevice"
if [ "$IS_ROOT" = 1 ]; then ui_print "${mode_root_echo:-Mode: root (uid 0) - all tweaks}"; else ui_print "${mode_nonroot_echo:-Mode: non-root (shell uid $(id -u)) - root-only tweaks skipped}"; fi
else
abort_and_cleanup "$nottranssiondevice"
fi


# ---- Device summary (from XOS Tweak) ----
get_prop() {
    local value
    value=$(getprop "$1" 2>/dev/null)
    echo "${value:-Unknown}"
}

# Device information
android_version=$(get_prop ro.build.version.release)
manufacturer=$(get_prop ro.product.manufacturer)
model=$(get_prop ro.product.model)
architecture=$(get_prop ro.product.cpu.abi)
kernel=$(uname -r 2>/dev/null | cut -d'-' -f1)
security_patch=$(get_prop ro.build.version.security_patch)
build_number=$(get_prop ro.build.display.id)

# System uptime
uptime_seconds=$(awk '{print $1}' /proc/uptime 2>/dev/null)
if [ -n "$uptime_seconds" ]; then
    hours=$(( ${uptime_seconds%%.*} / 3600 ))
    mins=$(( (${uptime_seconds%%.*} % 3600) / 60 ))
    uptime="${hours}h ${mins}m"
else
    uptime="Unknown"
fi

# Memory information
mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)
mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null)
if [ -n "$mem_total" ] && [ -n "$mem_avail" ]; then
    mem_used=$(( (mem_total - mem_avail) / 1024 ))
    mem_total=$(( mem_total / 1024 ))
    memory_info="${mem_used}MB / ${mem_total}MB"
else
    memory_info="Unknown"
fi

# Display information
resolution=$(wm size 2>/dev/null | awk -F': ' 'NR==1 {print $2}' | tr -d '\n')
density=$(wm density 2>/dev/null | awk -F': ' 'NR==1 {print $2}' | tr -d '\n')
if [ -n "$resolution" ] && [ -n "$density" ]; then
    display_info="${resolution} (${density} DPI)"
else
    display_info="Unknown"
fi

# Package count
sys_packages=$(cmd package list packages -s --user 0 2>/dev/null | wc -l)
user_packages=$(cmd package list packages -3 --user 0 2>/dev/null | wc -l)

# CPU information
cpu_info=$(get_prop ro.soc.model)
[ "$cpu_info" = "Unknown" ] && cpu_info=$(get_prop ro.hardware)
[ "$cpu_info" = "Unknown" ] && cpu_info=$(get_prop ro.board.platform)

# GPU information
gpu_info=$(dumpsys SurfaceFlinger 2>/dev/null |
    sed -n 's/^[[:space:]]*GLES:[[:space:]]*//p' | head -n 1)

[ -n "$gpu_info" ] || gpu_info="Unknown (GLES renderer not exposed)"

# GPU name = 2nd field of the GLES line ("<vendor>, <renderer>, <version>"), same as the dashboard
gpu_clean=$(printf '%s\n' "$gpu_info" | cut -d',' -f2 | xargs)
[ -n "$gpu_clean" ] || gpu_clean="Unknown"

# Device summary
echo ""
echo "Ｔｒａｎｓｓｉｏｎ Ｏｐｔｉｍｉｚｅｒ"
sleep 1

printf "%-16s: %s\n" "OS Version" "Android $android_version"
printf "%-16s: %s\n" "Device" "$manufacturer $model"
printf "%-16s: %s\n" "Architecture" "$architecture"
printf "%-16s: %s\n" "Kernel" "$kernel"
printf "%-16s: %s\n" "Author" "@Lykafkaa, @Droid_tweak & t.me/Dcx400"
printf "%-16s: %s\n" "System Uptime" "$uptime"
printf "%-16s: %s\n" "Memory" "$memory_info"
printf "%-16s: %s\n" "Display" "$display_info"
printf "%-16s: %s\n" "System Packages" "$sys_packages"
printf "%-16s: %s\n" "User Packages" "$user_packages"
printf "%-16s: %s\n" "CPU" "$cpu_info"
printf "%-16s: %s\n" "GPU" "$gpu_clean"
printf "%-16s: %s\n" "Security Patch" "$security_patch"
printf "%-16s: %s\n" "Build Number" "$build_number"

sleep 1
echo ""
echo "Transsion Only"
sleep 1

# Full GPU details
echo "Full GPU Details:"
if [ "$gpu_info" = "Unknown (GLES renderer not exposed)" ]; then
    echo "$gpu_info"
else
    printf '%s\n' "$gpu_info" |
        fold -s -w 60 2>/dev/null || printf '%s\n' "$gpu_info"
fi

echo ""
echo "Transsion Optimizer is a system optimization module specifically designed to maximize the performance of your Transsion device (Infinix, Tecno, itel). It combines XOS Tweak (by @Lykafkaaa and @Droid_Tweak, based on KFUNOSTWEAK) and Abandon-Engine (by t.me/Dcx400) into a single module."

sleep 1

mkdir -p "$vixun"


if [ -n "$description_echo" ]; then
    sed -i "s/^description=.*/description=$description_echo/" "$MODPATH/module.prop"
fi
echo "${tuned_for_echo:-Tuned for}" > "$vixun/tuned_for"
detect_device
update_description "$MODPATH/module.prop"
ui_print "Device: $DEV_NAME | ${DEV_SOC} | ${DEV_RAM_MB}MB | $(tier_label "$DEV_TIER") | ${DEV_MAXHZ:-?}Hz"

profiletimeout() {
	# migrate the value saved by older versions (first one wins), so a reflash never overwrites the original
	if [ ! -f "$vixun/orig/secure.long_press_timeout" ] && [ -f "$vixun/longpresstimeout" ];then
		mkdir -p "$vixun/orig"
		cp "$vixun/longpresstimeout" "$vixun/orig/secure.long_press_timeout"
	fi
	rm -f "$vixun/longpresstimeout"
	human_latency=${1:-250}
	hz=$(get_max_display_hz)
	if [ -z "$hz" ] || [ "$hz" -le 0 ];then
		hz=60
	fi
	frame_latency=$((1000 / hz))
	pipeline_frames=2
	long_press_timeout=$((human_latency + frame_latency * pipeline_frames))
	[ "$long_press_timeout" -lt 180 ] && long_press_timeout=200
	bk_put secure long_press_timeout "$long_press_timeout"
	ui_print "$press_timeout_echo : $long_press_timeout"

	if [ "$hz" -eq 60 ];then
		if [ "$(cmd display get-match-content-frame-rate-pref)" -eq 1 ];then
			touch "$vixun/contentframerate"
		fi
	fi

} 2>/dev/null


stringsfile() {
: # dyn_check scan removed: on tested devices every key was a default/logging-off no-op (see README R4)
} > "$vixunfile" 2>/dev/null

extrabytes() {
[ "$IS_ROOT" = 1 ] || return 0   # sys.sysctl.* is not settable from shell uid
[ -f "$vixun/no_extra_free" ] && return 0   # opt-out: never override the ROM / ZRAM module value
[ -w /proc/sys/vm/extra_free_kbytes ] || return 0   # kernel without the knob: nothing to do
if [ "$(getprop sys.sysctl.extra_free_kbytes)" -ge 1 ]; then 
res=$(wm size | grep "Physical size" | awk -F'[: x]+' '{print $3" "$4}')
width=$(echo "$res" | awk '{print $1}')
height=$(echo "$res" | awk '{print $2}')

if [ -z "$width" ]; then
    width=1080
    height=2400
fi

frames=$(getprop ro.surface_flinger.max_frame_buffer_acquired_buffers)
if [ -z "$frames" ]; then frames=4;fi

final_reserve=$(( width * height * 4 * frames / 1024 ))

setprop sys.sysctl.extra_free_kbytes "$final_reserve" && echo "sys.sysctl.extra_free_kbytes ${final_reserve}" >> "$vixunfile"
fi
} 2>/dev/null

transsiondebloat() {
googlelist="com.google.android.feedback com.google.android.onetimeinitializer "
aosplist="com.android.traceur com.google.android.adservices.api com.google.mainline.adservices"
facebooklist="com.facebook.system com.facebook.services com.facebook.appmanager"
mediateklist="com.mediatek.gnss.nonframeworklbs com.mediatek.location.mtkgeofence com.mediatek.mdmconfig com.mediatek.mdmlsample com.mediatek.voiceunlock com.mediatek.ygps com.mediatek.gbaservice"
transsionlist="com.talpa.hibrowser com.transsion.carlcare com.transsion.childmode com.transsion.childmode.resoverlay com.transsion.chromecustomization com.transsion.hamal com.transsion.iotservice com.transsion.statisticalsales com.transsion.trancare"
transsiontestlist="com.debug.loggerui com.transsion.agingfunction com.transsion.kolun.aiservice com.transsion.kolun.assistant com.transsion.quicktools com.transsion.teop com.transsion.tower com.reallytek.wg com.idea.questionnaire com.goodix.gftest"

# reflash-safe: skip apps that are already disabled, never duplicate debloatlist entries
[ -f "$vixun/debloatlist" ] && sort -u "$vixun/debloatlist" > "$vixun/debloatlist.tmp" && mv "$vixun/debloatlist.tmp" "$vixun/debloatlist"
disabled_now=" $(pm list packages -d --user 0 2>/dev/null | cut -d: -f2 | tr -d '\r' | tr '\n' ' ') "
n_done=0; n_skip=0

for a in $googlelist $aosplist $facebooklist $mediateklist $transsionlist $transsiontestlist;do
	pm path $a >/dev/null 2>&1 || continue
	case "$disabled_now" in
		*" $a "*) n_skip=$((n_skip + 1)); continue ;;
	esac
	grep -qxF "$a" "$vixun/debloatlist" 2>/dev/null || echo $a >> "$vixun/debloatlist"
	pm disable-user --user 0 $a
	n_done=$((n_done + 1))
done
ui_print "Debloat: $n_done disabled, $n_skip already disabled (skipped)"
}

################################################################################################################################################################################################

if [ "$(device_config get_sync_disabled_for_tests)" = "none" ]; then
	device_config set_sync_disabled_for_tests until_reboot   # service.sh re-applies it every boot; a disabled module no longer leaves sync off
	touch /data/local/tmp/persistentdevconfvixun
fi

getprop | grep '\[persist.log.tag' | while read -r line; do prop_name=$(echo "$line" | sed -n 's/^\[\(persist.log.tag[^]]*\)\].*/\1/p');if [ -n "$prop_name" ]; then sp "$prop_name" "S";fi;done
for key in fgs_start_allowed_log_sample_rate fgs_start_denied_log_sample_rate fgs_atom_sample_rate compact_statsd_sample_rate freeze_statsd_sample_rate; do { dumpsys activity settings | grep -q "$key" && device_config put activity_manager "$key" 0 || echo "$key not found."; } >/dev/null 2>&1; done
for a in dropbox_age_seconds dropbox_max_files dropbox_quota_kb dropbox_quota_percent;do bk_put global $a 0;done


normalize_bool_set persist.traced_perf.enable off
normalize_bool_set persist.traced.enable off


disable_if_enabled() {
    ns="$1"
    key="$2"
    marker="$3"

    val="$(settings get "$ns" "$key")"
    case "$val" in
				1)
			bk_put "$ns" "$key" 0
		;;
	esac
}

global_logic() {
bk_put global foreground_service_starts_logging_enabled 0
bk_put global activity_starts_logging_enabled 0
bk_put global enable_diskstats_logging 0
bk_put global binder_calls_stats detailed_tracking=false,enabled=false,upload_data=false,collect_latency_data=false,track_calling_uid=false




disable_if_enabled global ai_net_control_enable ainetcontrol

disable_if_enabled global upload_apk_enable uploadapkenable

if [ "$(settings get global gms_checkin_timeout_min 2>/dev/null)" = 6 ];then
	bk_put global gms_checkin_timeout_min 9
fi


if [ "$(dumpsys window | grep -o 'mBlurEnabled=[^ ]*' | cut -d= -f2)" = "true" ];then
		bk_put global disable_window_blurs 1
fi

cmd content dump | cut -d/ -f3 | grep -qo itel_user_analysis_enable && bk_put secure itel_user_analysis_enable 0

# migrate the value saved by older versions
if [ ! -f "$vixun/orig/global.wifi_power_save" ] && [ -f "$vixun/wifipowersave" ];then
	mkdir -p "$vixun/orig"; cp "$vixun/wifipowersave" "$vixun/orig/global.wifi_power_save"
fi
rm -f "$vixun/wifipowersave"
if [ "$(settings get global wifi_power_save 2>/dev/null)" -ge 100 ] 2>/dev/null; then
	bk_put global wifi_power_save 30
fi

}

animation() {
cpu_total=$(for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/cpuinfo_max_freq; do
  [ -f "$f" ] && cat "$f"
done | awk '{sum+=$1} END{printf "%.2f", sum/1000000}')

scale=$(awk -v t="$cpu_total" 'BEGIN {
  s = sqrt(t) / 8.0;
  if (s < 0.2) s = 0.2;
  if (s > 0.9) s = 0.9;
  printf "%.2f", s;
}')

bk_put global window_animation_scale $scale
bk_put global transition_animation_scale $scale
bk_put global animator_duration_scale $scale

ui_print "$animation_echo : $scale"
}

global_logic
transsiondebloat
stringsfile
animation
extrabytes
deviceidlewipe
profiletimeout 205

# permissions (KernelSU / Magisk installer)
if command -v set_perm_recursive >/dev/null 2>&1; then
    set_perm_recursive "$MODPATH" 0 0 0755 0644
    for _f in "$MODPATH"/*.sh "$MODPATH"/system/functions/*.sh "$MODPATH"/system/bin/*; do
        [ -f "$_f" ] && set_perm "$_f" 0 0 0755
    done
fi

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

#settaskprofile // thanks @reljawa and @AduhaiWelewele for informations
[ "$(id -u)" = 0 ] || exit 0   # root only


#find thread's cmdline along with that process
systemserver_tid() {
    local input=$1
	local grab=$2
    [ -z "$input" ] && return 1
    local pid=$(pidof -s $grab)
    [ -z "$pid" ] && return 1

    local tid=""
    for task_dir in /proc/$pid/task/*; do
        if [ "$input" = "$(< "$task_dir/comm")" ]; then
            tid="${task_dir##*/}"
            break
        fi
    done

    if [ -n "$tid" ]; then
        settaskprofile "$tid" SCHED_SP_BACKGROUND CPUSET_SP_RESTRICTED
    fi
}

#searching all threads (pidof can return several PIDs)
low_threads() {
    [ -z "$1" ] && return
    for pid in $(pidof "$1"); do
        for tid_path in /proc/$pid/task/*; do
            settaskprofile "${tid_path##*/}" SCHED_SP_BACKGROUND CPUSET_SP_RESTRICTED
        done
    done
}

loop_one() {
low_threads crashsplit
low_threads getgameserver
low_threads trandatacenter
low_threads incidentd
low_threads tombstoned
low_threads logd
low_threads connsyslogger
low_threads emdlogger
low_threads statsd
low_threads tranlog
low_threads tranlogconfig
low_threads mobile_log_d
}

loop_two() {
systemserver_tid TranLogService system_server
systemserver_tid NativeTombstone system_server
systemserver_tid CriticalEventLo system_server
systemserver_tid AppMetricsServi system_server
systemserver_tid TranResmonitorM system_server
}

loop_one 
loop_two 

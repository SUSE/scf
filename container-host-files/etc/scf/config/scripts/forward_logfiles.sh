#!/usr/bin/env bash

# This script sets up rsyslog to forward logs in /var/vcap/sys/log to a remote
# host

# used for initial config
CONF_OFFSET="10" # Before 50-default.conf to avoid re-logging our output
MAIN_CONFIG="${CONF_OFFSET}-vcap.conf"
RSYSLOG_CONF_DIR="/etc/rsyslog.d"
PID_FILE="/var/run/rsyslogd.monit.pid"

# used for adding individual logs
BACKUP_WATCH_DIR="/var/vcap/sys/log" #in case no ENV variable is set for RSYSLOG_FORWARDER_WATCH_DIR
RSYSLOG_CONF_PREFIX="$((CONF_OFFSET + 1))-vcap"
IGNORE_DIR="gocode"
TARGET_NAME=
TARGET_BASENAME=

SCRIPT_FILE="/usr/sbin/forward_logfiles.sh"
PB_OUT="/var/log/pb.out"

if [ ! -f "${SCRIPT_FILE}" ]; then
	echo "#log forwarding script" > "${PB_OUT}"
fi

if [ -z "${RSYSLOG_FORWARDER_WATCH_DIR:-}" ]; then
        RSYSLOG_FORWARDER_WATCH_DIR="${BACKUP_WATCH_DIR}"
        echo "RSYSLOG_FORWARDER_WATCH_DIR not set. Using default ${BACKUP_WATCH_DIR}" >> "${PB_OUT}"
fi

if [ ! -d "${RSYSLOG_FORWARDER_WATCH_DIR}" ]; then
        echo "${RSYSLOG_FORWARDER_WATCH_DIR} is not a valid directory" >> "${PB_OUT}"
fi

if [ -z "${SCF_LOG_HOST}" ]; then
    echo "SCF_LOG_HOST is not set" >> "${PB_OUT}"
    exit 0
fi

function appendToCron {
        echo appending to cron
        crontab -l > tempcrontab
        sed 's@^\s*@@' >>"${SCRIPT_FILE}" <<-EOF
                export RSYSLOG_FORWARDER_WATCH_DIR=${RSYSLOG_FORWARDER_WATCH_DIR}
                export SCF_LOG_HOST=${SCF_LOG_HOST}
                export SCF_LOG_PORT=${SCF_LOG_PORT}
                export SCF_LOG_PREFIX=${SCF_LOG_PREFIX}
                export SCF_LOG_PROTOCOL=${SCF_LOG_PROTOCOL}
	EOF
        cat "$0" >> "${SCRIPT_FILE}"
        echo "*/1 * * * * /usr/bin/env bash ${SCRIPT_FILE} >> /dev/null 2>&1" >> tempcrontab
        crontab tempcrontab
}

# check if cron has something in it
if crontab -l &>/dev/null ; then
        # Put the script in cron if it is not there already
        if ! { crontab -l | grep forward_logfiles.sh ; } ; then
                appendToCron
        fi
else
        echo "# Creating cron conf as it does not exist yet" >> "${PB_OUT}"
        appendToCron
fi


# create the file that will forward all messages to the configured log
# destination
function initialConfig {
        # Place to spool logs if the upstream server is down
        mkdir -p /var/vcap/sys/rsyslog/buffered
        chown syslog:adm /var/vcap/sys/rsyslog/buffered

	case "${SCF_LOG_PROTOCOL}" in
	    udp)
		SCF_LOG_PREFIX=
		;;
	    tcp)
		SCF_LOG_PREFIX=@
		;;
	    *)
                echo "Rsyslog forwarder: Bad protocol ${SCF_LOG_PROTOCOL}, could not create ${MAIN_CONFIG} in ${RSYSLOG_CONF_DIR}" >> "${PB_OUT}"
                exit 0
		;;
	esac

        if ! sed 's@^\s*@@' >"${RSYSLOG_CONF_DIR}/${MAIN_CONFIG}" <<-EOF ; then
                module(load="imfile" mode="polling")
                \$template RFC5424Format,"<%pri%>1 %timestamp:::date-rfc3339% %hostname% %app-name% - - - %msg:::drop-last-lf%"
                \$RepeatedMsgReduction on
                \$MaxMessageSize 4k                             # default is 2k
                \$WorkDirectory /var/vcap/sys/rsyslog/buffered  # where messages should be buffered on disk
                \$ActionResumeRetryCount -1                     # Try until the server becomes available
                \$ActionQueueType LinkedList                    # Allocate on-demand
                \$ActionQueueFileName agg_backlog               # Spill to disk if queue is full
                \$ActionQueueMaxDiskSpace 32m                   # Max size for disk queue
                \$ActionQueueLowWaterMark 2000                  # Num messages. Assuming avg size of 512B, this is 1MiB.
                \$ActionQueueHighWaterMark 8000                 # Num messages. Assuming avg size of 512B, this is 4MiB.
                                                                # (If this is reached, messages will spill to disk until the low watermark is reached).
                \$ActionQueueTimeoutEnqueue 0                   # Discard messages if the queue + disk is full
                \$ActionQueueSaveOnShutdown on                  # Save in-memory data to disk if rsyslog shuts down
                :app-name, startswith, "vcap." @${SCF_LOG_PREFIX}${SCF_LOG_HOST}:${SCF_LOG_PORT};RFC5424Format
                :app-name, startswith, "vcap." ~                # Stop writing SCF message logs to /var/log
	EOF
                echo "Rsyslog forwarder: Could not create ${MAIN_CONFIG} in ${RSYSLOG_CONF_DIR}" >> "${PB_OUT}"
                exit 0
        fi

        if [[ ! -f "${RSYSLOG_CONF_DIR}/${MAIN_CONFIG}" ]]; then
                echo "Rsyslog forwarder: File ${MAIN_CONFIG} not found in ${RSYSLOG_CONF_DIR}" >> "${PB_OUT}"
                exit 0
        fi
}

# check if more logs to be monitored by rsyslog have come into existence since the last run
function searchTargetDir {
        local dir file filesAdded=1
        local args=( "$1" )
        for dir in ${IGNORE_DIR} ; do
                args=( "${args[@]}" '(' -name "${dir}" -a -prune ')' -o )
        done
        args=( "${args[@]}" '(' -name '*.log' -a -type f -a -print0 ')' )
        while IFS= read -r -d '' file ; do
                TARGET_BASENAME="$(basename "${file}" .log)"
                TARGET_NAME="${RSYSLOG_CONF_DIR}/${RSYSLOG_CONF_PREFIX}-${TARGET_BASENAME}.conf"
                if checkConfigExists ; then
                        echo "${TARGET_NAME} exists"
                else
                        echo "Creating ${TARGET_NAME}"
                        createTargetConf "${file}"
                        filesAdded=0
                fi
        done < <(find "${args[@]}")
        return ${filesAdded}
}

#Create the rsyslog configuration file inside rsysconf.d
function createTargetConf {
        # We need to strip leading whitespace introduced by the heredoc (because
        # it doesn't strip leading spaces, just tabs)
        sed 's@^\s*@@' >"${TARGET_NAME}" <<-EOF
                input(type="imfile"
                File="${1}"
                Tag="vcap.${TARGET_BASENAME}"
                Severity="info"
                Facility="local7"
                PersistStateInterval="1000"
                reopenOnTruncate="on")
	EOF
}

function checkConfigExists {
        test -f "${TARGET_NAME}"
}

#check if the forwarding conf is set up
if [ ! -f "${RSYSLOG_CONF_DIR}/${MAIN_CONFIG}" ]; then
      echo creating initial config for forwarding
      initialConfig
else
      echo initial config for forwarding exists
fi

# make sure that configurations (per log-file) are added to the rsyslog.d folder
if searchTargetDir "${RSYSLOG_FORWARDER_WATCH_DIR}"; then
        if test -r "${PID_FILE}"; then
                if test -d "/proc/$(cat "${PID_FILE}")"; then
                        monit restart rsyslogd
                fi
        fi
fi

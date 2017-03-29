BASE_PATH="/var/vcap/jobs/bootstrap"
TARGET_NAME="${BASE_PATH}/cron.sh"
mkdir -p $BASE_PATH

cat >${TARGET_NAME} <<EOF

PID_FILE=/var/vcap/sys/run/bootstrap/bootstrap.pid
[ -f \$PID_FILE ] && {
   pid=\`cat \$PID_FILE\`
   ps -p \$pid && {
      echo Already running...
      exit
   }
   rm -rf \$PID_FILE
}
echo \$\$ > \$PID_FILE

/var/vcap/jobs/bootstrap/bin/run 

EOF

chmod +x ${TARGET_NAME}

function appendToCron {
	mkdir -p /var/vcap/sys/log/bootstrap/	
	mkdir -p /var/vcap/sys/run/bootstrap/	
	echo "appending to cron"
	crontab -l > tempcrontab
	echo "*/5 * * * * bash /var/vcap/jobs/bootstrap/cron.sh >> /var/vcap/sys/log/bootstrap/bootstrap.log 2>&1" >> tempcrontab
	crontab tempcrontab
}

#check if cron has something in it
if crontab -l &>/dev/null ; then
        #put the script in cron if it is not there already
        if ! { crontab -l | grep bootstrap ; } ; then
                appendToCron
        fi
else
        echo "#creating cron conf as it does not exist yet"
        appendToCron
fi

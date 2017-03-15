function appendToCron {
	mkdir -p /var/vcap/sys/log/bootstrap/	
	echo "appending to cron"
	crontab -l > tempcrontab
	echo "*/5 * * * * bash /var/vcap/jobs/bootstrap/bin/run >> /var/vcap/sys/log/bootstrap/bootstrap.log 2>&1" >> tempcrontab
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
set -e

SENTINEL="/var/vcap/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

# *********************************************
# doppler fix
# *********************************************
job_dir="/var/vcap/jobs-src/doppler/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  patch -t <<"PATCH"
--- doppler_ctl.erb
+++ doppler_ctl.erb
@@ -18,7 +18,10 @@ case $1 in

     echo $$ > $PIDFILE

+    <% if p("doppler.tweak_locked_memory") %>
     ulimit -l unlimited
+    <% end %>
+
     ulimit -n 65536

     <% p("doppler.debug") == true ? debug_string = "--debug " : debug_string = "" %>
PATCH
fi

# *********************************************
# loggregator_trafficcontroller fix
# *********************************************
job_dir="/var/vcap/jobs-src/loggregator_trafficcontroller/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  patch -t <<"PATCH"
--- loggregator_trafficcontroller_ctl.erb
+++ loggregator_trafficcontroller_ctl.erb
@@ -18,7 +18,10 @@ case $1 in

     echo $$ > $PIDFILE

+    <% if p("traffic_controller.tweak_locked_memory") %>
     ulimit -l unlimited
+    <% end %>
+
     ulimit -n 65536

     <% p("traffic_controller.debug") == true ? debug_string = "--debug " : debug_string = "" %>
PATCH
fi

# *********************************************
# syslog_drain_binder fix
# *********************************************
job_dir="/var/vcap/jobs-src/syslog_drain_binder/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  patch -t <<"PATCH"
--- syslog_drain_binder_ctl.erb
+++ syslog_drain_binder_ctl.erb
@@ -16,7 +16,10 @@ case $1 in

     chown vcap:vcap $LOG_DIR

+    <% if p("syslog_drain_binder.tweak_locked_memory") %>
     ulimit -l unlimited
+    <% end %>
+
     ulimit -n 65536

     <% p("syslog_drain_binder.debug") == true ? debug_string = "--debug " : debug_string = "" %>
PATCH
fi

touch "${SENTINEL}"

exit 0

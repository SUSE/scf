set -e

# *********************************************
# gorouter fix
# *********************************************
job_dir="/var/vcap/jobs-src/gorouter/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  if [ ! -f "gorouter_ctl.erb.sentinel" ]; then
    patch -t --forward <<"PATCH"
--- gorouter_ctl.erb
+++ gorouter_ctl.erb
@@ -24,6 +24,7 @@ case $1 in

     echo $$ > $PIDFILE

+    <% if p("router.tweak_proc_sys") %>
     if running_in_container; then
         echo "Not setting /proc/sys/net/ipv4 parameters, since I'm running inside a linux container"
     else
@@ -55,6 +56,7 @@ case $1 in

     # Allow a few more queued connections than are allowed by default
     echo 1024 > /proc/sys/net/core/somaxconn
+    <% end %>

     # Allowed number of open file descriptors
     ulimit -n 100000
PATCH

    touch "gorouter_ctl.erb.sentinel"
  fi
fi

# *********************************************
# doppler fix
# *********************************************
job_dir="/var/vcap/jobs-src/doppler/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  if [ ! -f "doppler_ctl.erb.sentinel" ]; then
    patch -t --forward <<"PATCH"
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

    touch "doppler_ctl.erb.sentinel"
  fi
fi

# *********************************************
# loggregator_trafficcontroller fix
# *********************************************
job_dir="/var/vcap/jobs-src/loggregator_trafficcontroller/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  if [ ! -f "loggregator_trafficcontroller_ctl.erb.sentinel" ]; then
    patch -t --forward <<"PATCH"
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

    touch "loggregator_trafficcontroller_ctl.erb.sentinel"
  fi
fi

# *********************************************
# syslog_drain_binder fix
# *********************************************
job_dir="/var/vcap/jobs-src/syslog_drain_binder/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  if [ ! -f "syslog_drain_binder_ctl.erb.sentinel" ]; then
    patch -t --forward <<"PATCH"
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

    touch "syslog_drain_binder_ctl.erb.sentinel"
  fi
fi

# *********************************************
# bbs fix
# *********************************************
job_dir="/var/vcap/jobs-src/bbs/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  if [ ! -f "bbs_ctl.erb.sentinel" ]; then
    patch -t --forward <<"PATCH"
--- bbs_ctl.erb
+++ bbs_ctl.erb
@@ -51,6 +51,7 @@ case $1 in

     echo $$ > $PIDFILE

+    <% if p("diego.bbs.tweak_proc_sys") %>
     if running_in_container; then
         echo "Not setting /proc/sys/net/ipv4 parameters, since I'm running inside a linux container"
     else
@@ -69,6 +70,7 @@ case $1 in

         echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
     fi
+    <% end %>

     # Allowed number of open file descriptors
     ulimit -n 100000
PATCH

    touch "bbs_ctl.erb.sentinel"
  fi
fi

# *********************************************
# cc_uploader fix
# *********************************************
job_dir="/var/vcap/jobs-src/cc_uploader/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  if [ ! -f "cc_uploader_ctl.erb.sentinel" ]; then
    patch -t --forward <<"PATCH"
--- cc_uploader_ctl.erb
+++ cc_uploader_ctl.erb
@@ -21,6 +21,7 @@ case $1 in

     echo $$ > $PIDFILE

+    <% if p("diego.cc_uploader.tweak_proc_sys") %>
     if running_in_container; then
         echo "Not setting /proc/sys/net/ipv4 parameters, since I'm running inside a linux container"
     else
@@ -39,6 +40,7 @@ case $1 in

         echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
     fi
+    <% end %>

     # Allowed number of open file descriptors
     ulimit -n 100000
PATCH

    touch "cc_uploader_ctl.erb.sentinel"
  fi
fi

# *********************************************
# file_server fix
# *********************************************
job_dir="/var/vcap/jobs-src/file_server/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  if [ ! -f "file_server_ctl.erb.sentinel" ]; then
    patch -t --forward <<"PATCH"
--- file_server_ctl.erb
+++ file_server_ctl.erb
@@ -21,9 +21,12 @@ case $1 in

     echo $$ > $PIDFILE

+    <% if p("diego.file_server.tweak_proc_sys") %>
     if running_in_container; then
         echo "Not setting /proc/sys/net/ipv4 parameters, since I'm running inside a linux container"
     else
+       echo "Setting /proc/sys/net/ipv4 parameters"
+
         # TCP_FIN_TIMEOUT
         # This setting determines the time that must elapse before TCP/IP can release a closed connection and reuse
         # its resources. During this TIME_WAIT state, reopening the connection to the client costs less than establishing
@@ -39,7 +42,8 @@ case $1 in

         echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
     fi
-
+    <% end %>
+
     # Allowed number of open file descriptors
     ulimit -n 100000

PATCH

    touch "file_server_ctl.erb.sentinel"
  fi
fi

# *********************************************
# rep fix
# *********************************************
job_dir="/var/vcap/jobs-src/rep/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  if [ ! -f "rep_ctl.erb.sentinel" ]; then
    patch -t --forward <<"PATCH"
--- rep_ctl.erb
+++ rep_ctl.erb
@@ -43,6 +43,7 @@ case $1 in
     mkdir -p $CACHE_DIR
     chown -R vcap:vcap $CACHE_DIR

+    <% if p("diego.rep.tweak_proc_sys") %>
     if running_in_container; then
         echo "Not setting /proc/sys/net/ipv4 parameters, since I'm running inside a linux container"
     else
@@ -61,6 +62,7 @@ case $1 in

         echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
     fi
+    <% end %>

     # Allowed number of open file descriptors
     ulimit -n 100000
PATCH

    touch "rep_ctl.erb.sentinel"
  fi
fi

# *********************************************
# stager fix
# *********************************************
job_dir="/var/vcap/jobs-src/stager/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  if [ ! -f "stager_ctl.erb.sentinel" ]; then
    patch -t --forward <<"PATCH"
--- stager_ctl.erb
+++ stager_ctl.erb
@@ -37,6 +37,7 @@ case $1 in

     echo $$ > $PIDFILE

+    <% if p("diego.stager.tweak_proc_sys") %>
     if running_in_container; then
         echo "Not setting /proc/sys/net/ipv4 parameters, since I'm running inside a linux container"
     else
@@ -55,6 +56,7 @@ case $1 in

         echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
     fi
+    <% end %>

     # Allowed number of open file descriptors
     ulimit -n 100000
PATCH

    touch "stager_ctl.erb.sentinel"
  fi
fi

# *********************************************
# cloud_controller_ng fix
# *********************************************
job_dir="/var/vcap/jobs-src/cloud_controller_ng/templates/"
if [ -d "$job_dir" ]; then
  cd $job_dir

  if [ ! -f "cloud_controller_api_ctl.erb.sentinel" ]; then
    patch -t --forward <<"PATCH"
--- cloud_controller_api_ctl.erb
+++ cloud_controller_api_ctl.erb
@@ -83,7 +83,9 @@ case $1 in
     # Configure the core file location
     mkdir -p /var/vcap/sys/cores
     chown vcap:vcap /var/vcap/sys/cores
+    <% if p("cc.tweak_proc_sys") %>
     echo /var/vcap/sys/cores/core-%e-%s-%p-%t > /proc/sys/kernel/core_pattern
+    <% end %>

     ulimit -c unlimited
PATCH


    touch "cloud_controller_api_ctl.erb.sentinel"
  fi
fi


exit 0

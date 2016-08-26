#!/bin/sh
# routing-release: various host names should not be .service.cf.internal
# https://github.com/cloudfoundry-incubator/routing-release/pull/31

set -e

dir() {
    local job=$1
    echo /var/vcap/jobs-src/${job}/templates
}
sentinel() {
    echo $(dir $1)/${0##*/}.sentinel
}

if [ -e $(dir gorouter)/gorouter.yml.erb -a ! -f $(sentinel gorouter) ]; then
    cd $(dir gorouter)
    patch -p0 --force <<'PATCH'
--- gorouter.yml.erb
+++ gorouter.yml.erb
@@ -40,7 +40,7 @@ droplet_stale_threshold: 120
 publish_active_apps_interval: 0 # 0 means disabled

 oauth:
-  token_endpoint: uaa.service.cf.internal
+  token_endpoint: <%= p("uaa.token_endpoint") %>
   client_name: "gorouter"
   client_secret: <%= p("uaa.clients.gorouter.secret") %>
   port: <%= p("uaa.ssl.port") %>
@@ -48,7 +48,7 @@ oauth:
 
 <% if p("routing_api.enabled") %>
 routing_api:
-  uri: http://routing-api.service.cf.internal
+  uri: <%= p("routing_api.uri") %>
   port: <%= p("routing_api.port") %>
   auth_disabled: <%= p("routing_api.auth_disabled") %>
 <% end %>
PATCH
    touch $(sentinel gorouter)
fi

if [ -e $(dir router_configurer)/router_configurer.yml.erb -a ! -f $(sentinel router_configurer) ]; then
    cd $(dir router_configurer)
    patch -p0 --force <<'PATCH'
--- router_configurer.yml.erb
+++ router_configurer.yml.erb
@@ -1,5 +1,5 @@
 oauth:
-  token_endpoint: uaa.service.cf.internal
+  token_endpoint: <%= p("uaa.token_endpoint") %>
   client_name: "tcp_router"
   client_secret: <%= p("router_configurer.oauth_secret") %>
   port: <%= p("uaa.tls_port") %>
@@ -9,8 +9,8 @@
   <% end %>
 
 routing_api:
-  uri: http://routing-api.service.cf.internal
-  port: 3000
+  uri: <%= p("routing_api.uri") %>
+  port: <%= p("routing_api.port") %>
   auth_disabled: <%= p("routing_api.auth_disabled") %>
 
 
PATCH
    touch $(sentinel router_configurer)
fi

if [ -e $(dir routing-api)/routing-api.yml.erb -a ! -f $(sentinel routing-api) ]; then
    cd $(dir routing-api)
    patch -p0 --force <<'PATCH'
--- routing-api.yml.erb
+++ routing-api.yml.erb
@@ -6,7 +6,7 @@ metron_config:
 metrics_reporting_interval: <%= p("routing_api.metrics_reporting_interval") %>
 statsd_endpoint: <%= p("routing_api.statsd_endpoint") %>
 oauth:
-  token_endpoint: uaa.service.cf.internal
+  token_endpoint: <%= p("uaa.token_endpoint") %>
   port: <%= p("uaa.tls_port") %>
   skip_ssl_validation: <%= p("skip_ssl_validation") %>
 debug_address: <%= p("routing_api.debug_address") %>
PATCH
    touch $(sentinel routing-api)
fi

if [ -e $(dir tcp_emitter)/tcp_emitter.yml.erb -a ! -f $(sentinel tcp_emitter) ]; then
    cd $(dir tcp_emitter)
    patch -p0 --force <<'PATCH'
--- tcp_emitter.yml.erb
+++ tcp_emitter.yml.erb
@@ -1,13 +1,13 @@
 oauth:
-  token_endpoint: uaa.service.cf.internal
+  token_endpoint: <%= p("uaa.token_endpoint") %>
   client_name: "tcp_emitter"
   client_secret: <%= p("tcp_emitter.oauth_secret") %>
   port: <%= p("uaa.tls_port") %>
   skip_ssl_validation: <%= p("skip_ssl_validation") %>
   <% if p("uaa.ca_cert") != "" %>
   ca_certs: "/var/vcap/jobs/tcp_emitter/config/certs/uaa/ca.crt"
   <% end %>
 routing_api:
-  uri: http://routing-api.service.cf.internal
-  port: 3000
+  uri: <%= p("routing_api.uri") %>
+  port: <%= p("routing_api.port") %>
   auth_disabled: <%= p("routing_api.auth_disabled") %>
 
 
PATCH
    touch $(sentinel tcp_emitter)
fi

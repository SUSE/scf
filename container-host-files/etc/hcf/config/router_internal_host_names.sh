#!/bin/sh
# routing-release: various host names should not be .service.cf.internal

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
@@ -41,7 +41,7 @@ droplet_stale_threshold: 120
 publish_active_apps_interval: 0 # 0 means disabled
 
 oauth:
-  token_endpoint: uaa.service.cf.internal
+  token_endpoint: <%= p("uaa.token_endpoint") %>
   client_name: "gorouter"
   client_secret: <%= p("uaa.clients.gorouter.secret") %>
   port: <%= p("uaa.ssl.port") %>
@@ -49,7 +49,7 @@ oauth:
 
 <% if p("routing_api.enabled") %>
 routing_api:
-  uri: http://routing-api.service.cf.internal
+  uri: <%= p("routing-api.uri") %>
   port: <%= p("routing-api.port") %>
   auth_disabled: <%= p("routing-api.auth_disabled") %>
 <% end %>
PATCH
    touch $(sentinel gorouter)
fi

if [ -e $(dir router_configurer)/router_configurer.yml.erb -a ! -f $(sentinel router_configurer) ]; then
    cd $(dir router_configurer)
    patch -p0 --force <<'PATCH'
--- router_configurer.yml.erb
+++ router_configurer.yml.erb
@@ -1,12 +1,12 @@
 oauth:
-  token_endpoint: uaa.service.cf.internal
+  token_endpoint: <%= p("router.router_configurer.uaa_token_endpoint") %>
   client_name: "tcp_router"
   client_secret: <%= p("router.router_configurer.tcp_router_secret") %>
   port: <%= p("router.router_configurer.uaa_ssl_port") %>
   skip_oauth_tls_verification: <%= p("router.router_configurer.skip_oauth_tls_verification") %>

 routing_api:
-  uri: http://routing-api.service.cf.internal
+  uri: <%= p("router.router_configurer.routing_api_uri") %>
   port: <%= p("router.router_configurer.routing_api_port") %>
   auth_disabled: <%= p("router.router_configurer.routing_api_auth_disabled") %>
 
PATCH
    touch $(sentinel router_configurer)
fi

if [ -e $(dir routing-api)/routing-api.yml.erb -a ! -f $(sentinel routing-api) ]; then
    cd $(dir routing-api)
    patch -p0 --force <<'PATCH'
--- routing-api.yml.erb
+++ routing-api.yml.erb
@@ -8,7 +8,7 @@ metron_config:
 metrics_reporting_interval: <%= p("routing-api.metrics_reporting_interval") %>
 statsd_endpoint: <%= p("routing-api.statsd_endpoint") %>
 oauth:
-  token_endpoint: uaa.service.cf.internal
+  token_endpoint: <%= p("routing-api.uaa_token_endpoint") %>
   port: <%= p("routing-api.uaa_ssl_port") %>
   skip_oauth_tls_verification: <%= p("routing-api.skip_oauth_tls_verification") %>
 debug_address: <%= p("routing-api.debug_address") %>
PATCH
    touch $(sentinel routing-api)
fi

if [ -e $(dir tcp_emitter)/tcp_emitter.yml.erb -a ! -f $(sentinel tcp_emitter) ]; then
    cd $(dir tcp_emitter)
    patch -p0 --force <<'PATCH'
--- tcp_emitter.yml.erb
+++ tcp_emitter.yml.erb
@@ -1,12 +1,12 @@
 oauth:
-  token_endpoint: uaa.service.cf.internal
+  token_endpoint: <%= p("router.tcp_emitter.uaa_token_endpoint") %>
   client_name: "tcp_emitter"
   client_secret: <%= p("router.tcp_emitter.tcp_emitter_secret") %>
   port: <%= p("router.tcp_emitter.uaa_ssl_port") %>
   skip_oauth_tls_verification: <%= p("router.tcp_emitter.skip_oauth_tls_verification") %>
 
 routing_api:
-  uri: http://routing-api.service.cf.internal
+  uri: <%= p("router.tcp_emitter.routing_api_uri") %>
   port: <%= p("router.tcp_emitter.routing_api_port") %>
   auth_disabled: <%= p("router.tcp_emitter.routing_api_auth_disabled") %>
 
PATCH
    touch $(sentinel tcp_emitter)
fi

set -e

PATCH_DIR="/var/vcap/jobs-src/doppler/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -d "${PATCH_DIR}" -a ! -f "${SENTINEL}" ]; then

  read -r -d '' setup_patch_doppler <<'PATCH' || true
--- doppler.json.erb.orig
+++ doppler.json.erb
@@ -9,7 +9,7 @@
     end

     if instance_id.nil?
-      instance_id = spec.index
+      instance_id = spec.index.to_s
     end

     if instance_zone.nil?
PATCH

  cd "$PATCH_DIR"

  echo -e "${setup_patch_doppler}" | patch --force

  touch "${SENTINEL}"
fi

PATCH_DIR="/var/vcap/jobs-src/loggregator_trafficcontroller/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -d "${PATCH_DIR}" -a ! -f "${SENTINEL}" ]; then

  read -r -d '' setup_patch_loggregator_trafficcontroller <<'PATCH' || true
--- loggregator_trafficcontroller.json.erb.orig
+++ loggregator_trafficcontroller.json.erb
@@ -8,7 +8,7 @@
     end

     if instance_id.nil?
-      instance_id = spec.index
+      instance_id = spec.index.to_s
     end

     # Handle renamed properties
PATCH

  cd "$PATCH_DIR"

  echo -e "${setup_patch_loggregator_trafficcontroller}" | patch --force

  touch "${SENTINEL}"
fi

PATCH_DIR="/var/vcap/jobs-src/metron_agent/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -d "${PATCH_DIR}" -a ! -f "${SENTINEL}" ]; then

  read -r -d '' setup_patch_metron_agent <<'PATCH' || true
--- metron_agent.json.erb.orig
+++ metron_agent.json.erb
@@ -16,7 +16,7 @@
     end

     if instance_id.nil?
-      instance_id = spec.index
+      instance_id = spec.index.to_s
     end

     if instance_zone.nil?
PATCH

  cd "$PATCH_DIR"

  echo -e "${setup_patch_metron_agent}" | patch --force

  touch "${SENTINEL}"
fi

PATCH_DIR="/var/vcap/jobs-src/metron_agent_windows/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -d "${PATCH_DIR}" -a ! -f "${SENTINEL}" ]; then

  read -r -d '' setup_patch_metron_agent_windows <<'PATCH' || true
--- metron_agent.json.erb.orig
+++ metron_agent.json.erb
@@ -16,7 +16,7 @@
     end

     if instance_id.nil?
-      instance_id = spec.index
+      instance_id = spec.index.to_s
     end

     if instance_zone.nil?
PATCH

  cd "$PATCH_DIR"

  echo -e "${setup_patch_metron_agent_windows}" | patch --force

  touch "${SENTINEL}"
fi

exit 0

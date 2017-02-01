set -e

PATCH_DIR="/var/vcap/jobs-src/doppler/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -d "${PATCH_DIR}" -a ! -f "${SENTINEL}" ]; then

  read -r -d '' setup_patch_doppler <<'PATCH' || true
--- doppler.json.erb.orig
+++ doppler.json.erb
@@ -2,7 +2,7 @@
     # try and set these properties from a BOSH 2.0 spec object
     job_name = spec.job.name
     instance_id = spec.id
-    instance_zone = spec.az
+    instance_zone = p("doppler.zone", spec.az)

     if job_name.nil?
       job_name = name
PATCH

  cd "$PATCH_DIR"

  echo -e "${setup_patch_doppler}" | patch --force

  touch "${SENTINEL}"
fi


PATCH_DIR="/var/vcap/jobs-src/metron_agent/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -d "${PATCH_DIR}" -a ! -f "${SENTINEL}" ]; then

  read -r -d '' setup_patch_metron_agent <<'PATCH' || true
--- metron_agent.json.erb.orig
+++ metron_agent.json.erb
@@ -2,7 +2,7 @@
     # try and set these properties from a BOSH 2.0 spec object
     job_name = spec.job.name
     instance_id = spec.id
-    instance_zone = spec.az
+    instance_zone = p("metron_agent.zone", spec.az)

     if job_name.nil?
       job_name = name
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
@@ -2,7 +2,7 @@
     # try and set these properties from a BOSH 2.0 spec object
     job_name = spec.job.name
     instance_id = spec.id
-    instance_zone = spec.az
+    instance_zone = p("metron_agent.zone", spec.az)

     if job_name.nil?
       job_name = name
PATCH

  cd "$PATCH_DIR"

  echo -e "${setup_patch_metron_agent_windows}" | patch --force

  touch "${SENTINEL}"
fi

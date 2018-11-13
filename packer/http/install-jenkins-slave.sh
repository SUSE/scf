#!/usr/bin/env bash

# This script installs the Jenkins slave related services
# This should be run on cloud-init as root

# Requires the following environment variables:
# JENKINS_URL — 
# JENKINS_AUTH_USER
# JENKINS_AUTH_PASS

set -o xtrace -o errexit -o nounset

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
JENKINS_LABEL="${JENKINS_LABEL:-${INSTANCE_ID}}"

mkdir -p /opt/jenkins

curl -Lo /opt/jenkins/slave.jar "${JENKINS_URL}/jnlpJars/slave.jar"
curl -Lo /opt/jenkins/cli.jar "${JENKINS_URL}/jnlpJars/jenkins-cli.jar"

cat <<EOF >/opt/jenkins/node.xml
<?xml version="1.0" encoding="UTF-8"?>
<slave>
  <name>${INSTANCE_ID}</name>
  <description></description>
  <remoteFS>/data/jenkins</remoteFS>
  <numExecutors>1</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
  <launcher class="hudson.slaves.JNLPLauncher">
    <workDirSettings>
      <disabled>false</disabled>
      <internalDir>remoting</internalDir>
      <failIfWorkDirIsMissing>false</failIfWorkDirIsMissing>
    </workDirSettings>
  </launcher>
  <label>${JENKINS_LABEL}</label>
  <nodeProperties/>
</slave>
EOF

cat <<EOF >/opt/jenkins/agent
#! /usr/bin/env bash
# -*- shell-script -*-
set -o xtrace
INSTANCE_ID=${INSTANCE_ID}
JENKINS_URL=${JENKINS_URL}
JENKINS_AUTH=${JENKINS_AUTH_USER}:${JENKINS_AUTH_PASS}
export JENKINS_URL
if ! java -jar /opt/jenkins/cli.jar -auth "\${JENKINS_AUTH}" get-node "\${INSTANCE_ID}"
then xml edit --update //slave/name --value "\${INSTANCE_ID}" /opt/jenkins/node.xml \
        | java -jar /opt/jenkins/cli.jar -auth "\${JENKINS_AUTH}" create-node "\${INSTANCE_ID}"
fi
exec java -jar /opt/jenkins/slave.jar -jnlpUrl "\${JENKINS_URL}/computer/\${INSTANCE_ID}/slave-agent.jnlp" -jnlpCredentials "\${JENKINS_AUTH}"
EOF

chmod +x /opt/jenkins/agent

cat <<EOF >/etc/systemd/system/jenkins-agent.service
# /etc/systemd/system/jenkins-agent.service
[Install]
WantedBy=multi-user.target
[Unit]
Description=Jenkins Agent
After=remote-fs.target network-online.target nss-lookup.target time-sync.target sendmail.service
Wants=remote-fs.target network-online.target nss-lookup.target
[Service]
ExecStart=/opt/jenkins/agent
Group=jenkins
PermissionsStartOnly=true
Restart=no
User=jenkins
EOF

mkdir -p /data
mount -a
groupadd --system jenkins
useradd --system --gid jenkins --home-dir /data/jenkins --create-home jenkins

for user in ec2-user jenkins
    do usermod --append --groups docker "${user}"
done

systemctl enable --now jenkins-agent.service

#!/usr/bin/env bash

set -o errexit -o xtrace

# Set up pod security policies

# The privileged PodSecurityPolicy is intended to be given
# only to trusted workloads. It provides for as few restrictions as possible
# and should only be assigned to highly trusted users.
kubectl create -f - <<EOF
{
  "apiVersion": "extensions/v1beta1",
  "kind": "PodSecurityPolicy",
  "metadata": {
    "annotations": {
      "apparmor.security.beta.kubernetes.io/defaultProfileName": "runtime/default",
      "seccomp.security.alpha.kubernetes.io/allowedProfileNames": "*",
      "seccomp.security.alpha.kubernetes.io/defaultProfileName": "docker/default"
    },
    "name": "suse.cap-vagrant.psp.privileged"
  },
  "spec": {
    "allowPrivilegeEscalation": true,
    "allowedCapabilities": [ "*" ],
    "defaultAddCapabilities": [],
    "defaultAllowPrivilegeEscalation": true,
    "fsGroup": { "rule": "RunAsAny" },
    "hostIPC": true,
    "hostNetwork": true,
    "hostPID": true,
    "hostPorts": [ {
        "min": 0,
        "max": 65535
    } ],
    "privileged": true,
    "readOnlyRootFilesystem": false,
    "requiredDropCapabilities": [],
    "runAsUser": { "rule": "RunAsAny" },
    "seLinux": { "rule": "RunAsAny" },
    "supplementalGroups": { "rule": "RunAsAny" },
    "volumes": [
      "configMap",
      "secret",
      "emptyDir",
      "downwardAPI",
      "projected",
      "persistentVolumeClaim",
      "hostPath",
      "nfs"
    ]
  }
}
EOF

# The unprivileged PodSecurityPolicy is intended to be a
# reasonable compromise between the reality of Kubernetes workloads, and
# suse:cap-vagrant:psp:privileged. By default, we'll grant this PSP to all
# users and service accounts.
kubectl create -f - <<EOF
{
  "apiVersion": "extensions/v1beta1",
  "kind": "PodSecurityPolicy",
  "metadata": {
    "annotations": {
      "apparmor.security.beta.kubernetes.io/allowedProfileNames": "runtime/default",
      "apparmor.security.beta.kubernetes.io/defaultProfileName": "runtime/default",
      "seccomp.security.alpha.kubernetes.io/allowedProfileNames": "docker/default",
      "seccomp.security.alpha.kubernetes.io/defaultProfileName": "docker/default"
    },
    "name": "suse.cap-vagrant.psp.unprivileged"
  },
  "spec": {
    "allowPrivilegeEscalation": false,
    "allowedCapabilities": [],
    "allowedHostPaths": [ { "pathPrefix": "/opt/kubernetes-hostpath-volumes" } ],
    "defaultAddCapabilities": [],
    "defaultAllowPrivilegeEscalation": false,
    "fsGroup": { "rule": "RunAsAny" },
    "hostIPC": false,
    "hostNetwork": false,
    "hostPID": false,
    "hostPorts": [ {
        "min": 0,
        "max": 65535
    } ],
    "privileged": false,
    "readOnlyRootFilesystem": false,
    "requiredDropCapabilities": [],
    "runAsUser": { "rule": "RunAsAny" },
    "seLinux": { "rule": "RunAsAny" },
    "supplementalGroups": { "rule": "RunAsAny" },
    "volumes": [
      "configMap",
      "secret",
      "emptyDir",
      "downwardAPI",
      "projected",
      "persistentVolumeClaim",
      "nfs"
    ]
  }
}
EOF

# Allow all users and serviceaccounts to use the unprivileged
# PodSecurityPolicy
kubectl auth reconcile -f - <<EOF
{
  "apiVersion": "rbac.authorization.k8s.io/v1",
  "kind": "ClusterRoleBinding",
  "metadata": {
    "name": "suse:cap-vagrant:psp:default"
  },
  "roleRef": {
    "apiGroup": "rbac.authorization.k8s.io",
    "kind": "ClusterRole",
    "name": "suse:cap-vagrant:psp:unprivileged"
  },
  "subjects": [
    {
      "apiGroup": "rbac.authorization.k8s.io",
      "kind": "Group",
      "name": "system:serviceaccounts"
    },
    {
      "apiGroup": "rbac.authorization.k8s.io",
      "kind": "Group",
      "name": "system:authenticated"
    }
  ]
}
EOF

# Allow system nodes to use the privileged PodSecurityPolicy.
kubectl auth reconcile -f - <<EOF
{
  "apiVersion": "rbac.authorization.k8s.io/v1",
  "kind": "ClusterRoleBinding",
  "metadata": {
    "name": "suse:cap-vagrant:psp:nodes"
  },
  "roleRef": {
    "apiGroup": "rbac.authorization.k8s.io",
    "kind": "ClusterRole",
    "name": "suse:cap-vagrant:psp:privileged"
  },
  "subjects": [
    {
      "apiGroup": "rbac.authorization.k8s.io",
      "kind": "Group",
      "name": "system:nodes"
    }
  ]
}
EOF

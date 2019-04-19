#!/usr/bin/env groovy
// vim: set et sw=4 ts=4 :

String ipAddress() {
    return sh(returnStdout: true, script: "ip -4 -o addr show eth0 | awk '{ print \$4 }' | awk -F/ '{ print \$1 }'").trim()
}

String domain() {
    return ipAddress() + ".nip.io"
}

jobBaseName = env.JOB_BASE_NAME.toLowerCase()
cfNamespace = "${jobBaseName}-${BUILD_NUMBER}-scf"
uaaNamespace = "${jobBaseName}-${BUILD_NUMBER}-uaa"

String getBuildLog() {
    return currentBuild.rawBuild.getLogFile().getText()
}

// The entries are the full path to the files, relative to the root of
// the repository
boolean areIgnoredFiles(HashSet<String> changedFiles) {
  HashSet<String> ignoredFiles = [
    "CHANGELOG.md",
    "README.md"
  ]

  // An empty set is considered to be contained by ignoredFiles, but if we
  // have an empty list, it's from a replay of a previous build, so we
  // should run it.
  if (changedFiles.size() == 0) {
    return false
  }

  return ignoredFiles.containsAll(changedFiles)
}

void setBuildStatus(String context, String status) {
    def description = null
    switch (status) {
        case 'pending':
            description = 'Tests running'
            break
        case 'success':
            description = 'Tests passed'
            break
        case 'failure':
            description = 'Tests failed'
            break
        default:
            // Also covers 'error' case
            description = 'Unknown error occurred'
            break
    }

    try {
    githubNotify credentialsId: 'creds-github-suse-cf-ci-bot',
                 context: "jenkins/${context}",
                 description: description,
                 status: status.toUpperCase(),
                 targetUrl: env.BUILD_URL
    } catch (IllegalArgumentException e) {
      echo "Can't notify github status (can't infer git data)"
    }
}

void runTest(String testName) {
    sh """
        set -e +x
        source \${PWD}/.envrc
        set -x

        export NAMESPACE=${cfNamespace}
        export UAA_NAMESPACE=${uaaNamespace}

        # this will look for tests under output/kube/bosh-tasks and not in output/unzipped/...
        make/tests "${testName}" "env.KUBERNETES_STORAGE_CLASS_PERSISTENT=hostpath"
    """
}

String distSubDir() {
    try {
        "${CHANGE_ID}"
        return 'prs/'
    } catch (Exception ex) {
        switch (env.BRANCH_NAME) {
            case 'develop':
                if (params.IS_NIGHTLY) {
                    return 'nightly/'
                }
                return 'develop/'
            case 'master':
                return 'master/'
            default:
                return 'branches/'
        }
    }
}

String distPrefix() {
    try {
        return "PR-${CHANGE_ID}-"
    } catch (Exception ex) {
        if (env.BRANCH_NAME == 'develop' || env.BRANCH_NAME == 'master') {
            return ''
        }
        return java.net.URLEncoder.encode("${BRANCH_NAME}-", "UTF-8")
    }
}

Boolean noOverwrites() {
    switch (env.BRANCH_NAME) {
        case 'master':
            return true
        default:
            return false
    }
}

void kubectlGetAll(String namespace) {
    sh "kubectl get all --namespace \"${namespace}\" --output wide || true"
}

pipeline {
    agent { label ((params.AGENT_LABELS ?: "scf prod").tokenize().join("&&")) }
    options {
        ansiColor('xterm')
        skipDefaultCheckout() // We do our own checkout so it can be disabled
        timestamps()
        timeout(time: 10, unit: 'HOURS')
        ws('scf')
    }
    parameters {
        booleanParam(
            name: 'SKIP_CHECKOUT',
            defaultValue: false,
            description: 'Skip the checkout step for faster iteration',
        )
        booleanParam(
            name: 'WIPE',
            defaultValue: false,
            description: 'Remove all existing sources and start from scratch',
        )
        booleanParam(
            name: 'CLEAN',
            defaultValue: true,
            description: 'Remove build artifacts that should normally not be reused',
        )
        booleanParam(
            name: 'PUBLISH_DOCKER',
            defaultValue: true,
            description: 'Enable publishing to docker',
        )
        booleanParam(
            name: 'PUBLISH_S3',
            defaultValue: true,
            description: 'Enable publishing to amazon s3',
        )
        booleanParam(
            name: 'IS_NIGHTLY',
            defaultValue: false,
            description: 'This is a nightly build (will publish to the nightly prefix)',
        )
        booleanParam(
            name: 'TEST_ROTATE',
            defaultValue: true,
            description: 'Trigger secret rotation via helm upgrade',
        )
        booleanParam(
            name: 'TEST_SMOKE',
            defaultValue: true,
            description: 'Run smoke tests',
        )
        booleanParam(
            name: 'TEST_BRAIN',
            defaultValue: true,
            description: 'Run BRAIN tests (SCF Acceptance Tests)',
        )
        booleanParam(
            name: 'TEST_SITS',
            defaultValue: true,
            description: 'Run SITS (Cloud Foundry Sync Integration Tests)',
        )
        booleanParam(
            name: 'TEST_CATS',
            defaultValue: true,
            description: 'Run CATS (Cloud Foundry Acceptance Tests)',
        )
        booleanParam(
            name: 'TAR_SOURCES',
            defaultValue: false,
            description: 'Tar sources',
        )
        booleanParam(
            name: 'COMMIT_SOURCES',
            defaultValue: false,
            description: 'Push sources to obs',
        )
        credentials(
            name: 'OBS_CREDENTIALS',
            description: 'Password for build.opensuse.org',
            defaultValue: 'osc-alfred-jenkins',
        )
        credentials(
            name: 'S3_CREDENTIALS',
            description: 'AWS access key / secret key used for publishing',
            defaultValue: 'cred-s3-scf',
        )
        string(
            name: 'S3_REGION',
            description: 'AWS S3 region the target bucket is in',
            defaultValue: 'us-east-1',
        )
        string(
            name: 'S3_BUCKET',
            description: 'AWS S3 bucket to publish to',
            defaultValue: 'cap-release-archives',
        )
        string(
            name: 'S3_LOG_BUCKET',
            description: 'AWS S3 bucket to publish to',
            defaultValue: 'cap-jenkins-logs',
        )
        string(
            name: 'S3_PREFIX',
            description: 'AWS S3 prefix to publish to',
            defaultValue: '',
        )
        credentials(
            name: 'DOCKER_CREDENTIALS',
            description: 'Docker credentials used for publishing',
            defaultValue: 'cred-docker-scf-staging',
        )
        string(
            name: 'FISSILE_DOCKER_REGISTRY',
            defaultValue: 'staging.registry.howdoi.website/',
            description: 'Docker registry to publish to',
        )
        string(
            name: 'FISSILE_DOCKER_ORGANIZATION',
            defaultValue: 'splatform',
            description: 'Docker organization to publish to',
        )
        string(
            name: 'FISSILE_DOCKER_REPO',
            defaultValue: 'fissile-stemcell-sle12',
            description: 'Docker repo name to pull from "<organization>/<repo>:<tag>"',
        )
        string(
            name: 'FISSILE_STEMCELL_VERSION',
            defaultValue: '12SP3-34.gcdd8986-0.220',
            description: 'Fissile stemcell version used as docker image tag',
        )
        booleanParam(
            name: 'STARTED_BY_TRIGGER',
            defaultValue: false,
            description: 'Guard to ensure master builds are started by a trigger',
        )
        string(
            name: 'AGENT_LABELS',
            defaultValue: 'scf prod',
            description: 'Extra labels for Jenkins slave selection',
        )
        credentials(
            name: 'NOTIFICATION_EMAIL',
            description: 'E-mail address to send failure notifications to; mail will not be sent for PRs',
            defaultValue: 'cred-scf-email-notification',
            required: false,
        )
    }

    environment {
        FISSILE_DOCKER_REGISTRY = "${params.FISSILE_DOCKER_REGISTRY}"
        FISSILE_DOCKER_ORGANIZATION = "${params.FISSILE_DOCKER_ORGANIZATION}"
        FISSILE_DOCKER_REPO = "${params.FISSILE_DOCKER_REPO}"
        FISSILE_STEMCELL_VERSION = "${params.FISSILE_STEMCELL_VERSION}"
    }

    stages {
        stage('ensure_triggered_master') {
            when {
                expression { return env.BRANCH_NAME == 'master' }
            }
            steps {
                script {
                    if (!params.STARTED_BY_TRIGGER) {
                        error "Master build without trigger flag"
                    }
                }
            }
        }

        stage('wipe') {
            when {
                expression { return params.WIPE }
            }
            steps {
                deleteDir()
            }
        }

        stage('clean') {
            when {
                expression { return params.CLEAN }
            }
            steps {
                sh '''
                    #!/bin/bash
                    dump_info() {
                        kubectl get namespace
                        helm list --all
                        docker ps -a
                        docker images
                    }
                    trap dump_info EXIT

                    get_namespaces() {
                        local ns
                        local -A all_ns
                        # Loop until getting namespaces succeeds
                        while test -z "${all_ns[kube-system]:-}" ; do
                            all_ns=[]
                            for ns in $(kubectl get namespace --no-headers --output=custom-columns=:.metadata.name) ; do
                                all_ns[${ns}]=${ns}
                            done
                        done
                        # Only return the namespaces we want
                        for ns in "${all_ns[@]}" ; do
                            if [[ "${ns}" =~ cf|uaa ]] ; then
                                echo "${ns}"
                            fi
                        done
                    }

                    get_namespaces | xargs --no-run-if-empty kubectl delete ns
                    set +x
                    while test -n "$(get_namespaces)"; do
                        sleep 5
                    done
                    set -x

                    # Run `docker rm` commands twice because of internal race condition:
                    # https://github.com/vmware/vic/issues/3196#issuecomment-263295426
                    docker ps --filter=status=exited  --quiet | xargs --no-run-if-empty docker rm || true
                    docker ps --filter=status=exited  --quiet | xargs --no-run-if-empty docker rm
                    docker ps --filter=status=created --quiet | xargs --no-run-if-empty docker rm || true
                    docker ps --filter=status=created --quiet | xargs --no-run-if-empty docker rm
                    # Force delete anything fissile
                    docker ps --filter=name=fissile --all --quiet | xargs --no-run-if-empty docker rm -f || true
                    docker ps --filter=name=fissile --all --quiet | xargs --no-run-if-empty docker rm -f

                    set +x
                    while docker ps -a --format '{{.Names}}' | grep -E -- '-scf_|-uaa_'; do
                        sleep 5
                    done
                    set -x

                    helm list --all --short | grep -E -- '-scf|-uaa' | xargs --no-run-if-empty helm delete --purge

                    docker images --format="{{.Repository}}:{{.Tag}}" | \
                        grep -E '/scf-|/uaa-|^uaa-role-packages:|^scf-role-packages:' | \
                        xargs --no-run-if-empty docker rmi

                    # Attempt to clean up orphaned images; it's okay to fail here
                    docker system prune -f || true
                '''
            }
        }
        stage('checkout') {
            when {
                expression { return (!params.SKIP_CHECKOUT) || params.WIPE }
            }
            steps {
                sh '''
                    git config --global --replace-all submodule.fetchJobs 0
                '''
                checkout scm
            }
        }
        stage('check_for_changed_files') {
          when {
              expression { return (env.BRANCH_NAME != 'master') }
          }
          steps {
            script {
	      def all_files = new HashSet<String>()

              // Nothing will build if no relevant files changed since
              // the last build on the same branch happened.
              for (set in currentBuild.changeSets) {
                def entries = set.items
                for (entry in entries) {
                  for (file in entry.affectedFiles) {
                    all_files << file.path
                  }
                }
              }

              echo "All files changed since last build: ${all_files}"

              if (areIgnoredFiles(all_files)) {
                currentBuild.rawBuild.result = hudson.model.Result.NOT_BUILT
                echo "RESULT: ${currentBuild.rawBuild.result}"
                throw new hudson.AbortException('Exiting pipeline early')
              }
            }
          }
        }

        stage('tools') {
            steps {
                sh '''
                    set -e +x
                    source ${PWD}/.envrc
                    set -x
                    unset SCF_PACKAGE_COMPILATION_CACHE
                    make ${FISSILE_BINARY}
                '''
            }
        }

        stage('verify_no_overwrite') {
            when {
                expression { return params.PUBLISH_S3 && noOverwrites() }
            }
            steps {
                withAWS(region: params.S3_REGION) {
                    withCredentials([usernamePassword(
                        credentialsId: params.S3_CREDENTIALS,
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY',
                    )]) {
                        script {
                            def expectedVersion = sh(script: '''make show-versions | awk '/^App Version/ { print $4 }' ''', returnStdout: true).trim()
                            if (expectedVersion == null || expectedVersion == '') {
                                error "Failed to find expected version"
                            }
                            echo "Found expected version: ${expectedVersion}"

                            def glob = "*scf-sle-${expectedVersion}.*.zip"
                            def files = s3FindFiles(bucket: params.S3_BUCKET, path: "${params.S3_PREFIX}${distSubDir()}", glob: glob)
                            if (files.size() > 0) {
                                error "found a file that matches our current version: ${files[0].name}"
                            }
                        }
                    }
                }
            }
        }

        stage('build') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: params.DOCKER_CREDENTIALS,
                    usernameVariable: 'DOCKER_HUB_USERNAME',
                    passwordVariable: 'DOCKER_HUB_PASSWORD',
                )]) {
                    sh '''
                        if [ -n "${FISSILE_DOCKER_REGISTRY}" ]; then
                            docker login -u "${DOCKER_HUB_USERNAME}" -p "${DOCKER_HUB_PASSWORD}" "${FISSILE_DOCKER_REGISTRY}"
                        fi
                    '''
                }
                sh '''
                    set -e +x
                    source ${PWD}/.envrc
                    set -x
                    unset SCF_PACKAGE_COMPILATION_CACHE

                    make vagrant-prep validate
                '''
            }
        }

        stage('dist') {
            steps {
                sh '''
                    set -e +x
                    source ${PWD}/.envrc
                    set -x
                    unset SCF_PACKAGE_COMPILATION_CACHE
                    rm -f output/*-sle-*.zip output/*-sle-*.tgz
                    make helm bundle-dist
                '''
            }
        }

                        --set enable.credhub=true \

        stage('deploy-eirini') {
            when {
                expression { return params.TEST_SMOKE || params.TEST_BRAIN || params.TEST_CATS }
            }
            steps {
                // Cleanup scf namespace and deploy again with eirini enabled
                sh '''
                    #!/bin/bash
                    dump_info() {
                        kubectl get namespace
                        helm list --all
                        docker ps -a
                        docker images
                    }
                    trap dump_info EXIT

                    get_namespaces() {
                        local ns
                        local -A all_ns
                        # Loop until getting namespaces succeeds
                        while test -z "${all_ns[kube-system]:-}" ; do
                            all_ns=[]
                            for ns in $(kubectl get namespace --no-headers --output=custom-columns=:.metadata.name) ; do
                                all_ns[${ns}]=${ns}
                            done
                        done
                        # Only return the namespaces we want
                        for ns in "${all_ns[@]}" ; do
                            if [[ "${ns}" =~ cf || "${ns}" == "eirini" ]] ; then
                                echo "${ns}"
                            fi
                        done
                    }

                    get_namespaces | xargs --no-run-if-empty kubectl delete ns
                    set +x
                    while test -n "$(get_namespaces)"; do
                        sleep 5
                    done
                    set -x
                '''
                sh """
                    set -e +x
                    source \${PWD}/.envrc
                    set -x

                    kubectl create namespace eirini

                    kubectl delete storageclass hostpath || /bin/true
                    kubectl create -f - <<< '{"kind":"StorageClass","apiVersion":"storage.k8s.io/v1","metadata":{"name":"hostpath","annotations":{"storageclass.kubernetes.io/is-default-class":"true"}},"provisioner":"kubernetes.io/host-path"}'

                    # Unzip the bundle
                    rm -rf output/unzipped
                    mkdir -p output/unzipped
                    unzip -e output/scf-sle-*.zip -d output/unzipped

                    # This is more informational -- even if it fails, we want to try running things anyway to see how far we get.
                    ./output/unzipped/kube-ready-state-check.sh || /bin/true

                    helm install output/unzipped/helm/uaa \
                        --name ${uaaNamespace} \
                        --namespace ${uaaNamespace} \
                        --set env.DOMAIN=${domain()} \
                        --set env.UAA_HOST=uaa.${domain()} \
                        --set env.UAA_PORT=2793 \
                        --set secrets.CLUSTER_ADMIN_PASSWORD=changeme \
                        --set secrets.UAA_ADMIN_CLIENT_SECRET=admin_secret \
                        --set kube.external_ips[0]=${ipAddress()} \
                        --set kube.storage_class.persistent=hostpath \
                        --set enable.eirini=true

                    # Deploy heapster
                    kubectl apply --filename https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml
                    kubectl apply --filename https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/standalone/heapster-controller.yaml

                    . make/include/secrets

                    has_internal_ca() {
                        test "\$(get_secret "${uaaNamespace}" "uaa" "INTERNAL_CA_CERT")" != ""
                    }

                    set +x
                    until has_internal_ca ; do
                        sleep 5
                    done
                    set -x

                    # Use `make/run` to run the deployment to ensure we have updated settings
                    export NAMESPACE="${cfNamespace}"
                    export UAA_NAMESPACE="${uaaNamespace}"
                    export DOMAIN="${domain()}"
                    export CF_CHART="output/unzipped/helm/cf"
                    log_uid=\$(hexdump -n 8 -e '2/4 "%08x"' /dev/urandom)
                    make/run-eirini \
                        --set enable.autoscaler=true \
                        --set env.SCF_LOG_HOST="log-\${log_uid}.${cfNamespace}.svc.cluster.local"

                    echo Waiting for all pods to be ready...
                    for ns in "${uaaNamespace}" "${cfNamespace}" ; do
                        make/wait "\${ns}"
                    done
                    kubectl get pods --all-namespaces
                """
            }
        }

        stage('smoke-eirini') {
            when {
                expression { return params.TEST_SMOKE }
            }
            steps {
                setBuildStatus('smoke-eirini', 'pending')
                runTest('smoke-tests')
            }
            post {
                success {
                    setBuildStatus('smoke-eirini', 'success')
                }
                failure {
                    setBuildStatus('smoke-eirini', 'failure')
                }
            }
        }

        stage('brain-eirini') {
            when {
                expression { return params.TEST_BRAIN }
            }
            steps {
                setBuildStatus('brain-eirini', 'pending')
                runTest('acceptance-tests-brain')
            }
            post {
                success {
                    setBuildStatus('brain-eirini', 'success')
                }
                failure {
                    setBuildStatus('brain-eirini', 'failure')
                }
            }
        }

        stage('scaler-eirini') {
            when {
                // Since we have autoescaler off by default, don't bother
                // testing the autoscaler unless we've rotated the secrets
                // (which also enables the autoscaler)
                expression { return params.TEST_SCALER && params.TEST_ROTATE }
            }
            steps {
                setBuildStatus('scaler-eirini', 'pending')
                runTest('autoscaler-smoke')
            }
            post {
                success {
                    setBuildStatus('scaler-eirini', 'success')
                }
                failure {
                    setBuildStatus('scaler-eirini', 'failure')
                }
            }
        }

        stage('cats-eirini') {
            when {
                expression { return params.TEST_CATS }
            }
            steps {
                setBuildStatus('cats-eirini', 'pending')
                runTest('acceptance-tests')
            }
            post {
                success {
                    setBuildStatus('cats-eirini', 'success')
                }
                failure {
                    setBuildStatus('cats-eirini', 'failure')
                }
            }
        }

        stage('tar_sources') {
          when {
                expression { return params.TAR_SOURCES }
          }
          steps {
                sh '''
                    set -e +x
                    source ${PWD}/.envrc
                    make tar-sources
                '''
          }
        }

        stage('commit_sources') {
          when {
                expression { return params.COMMIT_SOURCES }
          }
          steps {
                withCredentials([usernamePassword(
                    credentialsId: params.OBS_CREDENTIALS,
                    usernameVariable: 'OBS_CREDENTIALS_USERNAME',
                    passwordVariable: 'OBS_CREDENTIALS_PASSWORD',
                )]) {
                sh '''
                  set -e +x
                  source ${PWD}/.envrc
                  echo -e "[general]
apiurl = https://api.opensuse.org
[https://api.opensuse.org]
user = ${OBS_CREDENTIALS_USERNAME}
pass = ${OBS_CREDENTIALS_PASSWORD}
" > ~/.oscrc
                  make osc-commit-sources
                  rm ~/.oscrc
                '''
                }
          }
        }

        stage('publish_docker') {
            when {
                expression { return params.PUBLISH_DOCKER }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: params.DOCKER_CREDENTIALS,
                    usernameVariable: 'DOCKER_HUB_USERNAME',
                    passwordVariable: 'DOCKER_HUB_PASSWORD',
                )]) {
                    sh 'docker login -u "${DOCKER_HUB_USERNAME}" -p "${DOCKER_HUB_PASSWORD}" "${FISSILE_DOCKER_REGISTRY}" '
                }
                sh '''
                    set -e +x
                    source ${PWD}/.envrc
                    set -x
                    unset SCF_PACKAGE_COMPILATION_CACHE
                    make publish
                '''
            }
        }

        stage('publish_s3') {
            when {
                expression { return params.PUBLISH_S3 }
            }
            steps {
                withAWS(region: params.S3_REGION) {
                    withCredentials([usernamePassword(
                        credentialsId: params.S3_CREDENTIALS,
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY',
                    )]) {
                        script {
                            def files = findFiles(glob: "output/*-sle-*")
                            def subdir = "${params.S3_PREFIX}${distSubDir()}"
                            def prefix = distPrefix()

                            for ( int i = 0 ; i < files.size() ; i ++ ) {
                                if ( files[i].path =~ /\.zip$|\.tgz$/ ) {
                                    s3Upload(
                                        file: files[i].path,
                                        bucket: "${params.S3_BUCKET}",
                                        path: "${subdir}${prefix}${files[i].name}",
                                    )
                                    if (files[i].path =~ /\.zip$/ ) {
                                        def encodedFileName = java.net.URLEncoder.encode(files[i].name, "UTF-8")
                                        // Escape twice or the url will be unescaped when passed to the Jenkins form. It will then not work in the script.
                                        def capBundleUri = "https://s3.amazonaws.com/${params.S3_BUCKET}/${params.S3_PREFIX}${distSubDir()}${distPrefix()}${encodedFileName}"
                                        def encodedCapBundleUri = java.net.URLEncoder.encode(capBundleUri, "UTF-8")
                                        def encodedBuildUri = java.net.URLEncoder.encode(BUILD_URL, "UTF-8")

                                        echo "Create a cap release using this link: https://cap-release-tool.suse.de/?release_archive_url=${encodedCapBundleUri}&SOURCE_BUILD=${encodedBuildUri}"
                                        echo "Open a Pull Request for the helm repository using this link: http://jenkins-new.howdoi.website/job/helm-charts/parambuild?CAP_BUNDLE=${encodedCapBundleUri}&SOURCE_BUILD=${encodedBuildUri}"
                                        echo "Download the bundle from ${capBundleUri}"
                                    } else if (files[i].path =~ /^.*-helm-.*\.tgz$/ ) {
                                        def encodedFileName = java.net.URLEncoder.encode(files[i].name, "UTF-8")
                                        def helmChartUri = "https://s3.amazonaws.com/${params.S3_BUCKET}/${params.S3_PREFIX}${distSubDir()}${distPrefix()}${encodedFileName}"
                                        echo "Install with helm from ${helmChartUri}"
                                    }
                                } else {
                                    echo "Skipping file ${files[i].path}"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        failure {
            // Send mail, but only if we're develop or master
            script {
                if ((params.NOTIFICATION_EMAIL != null) && (env.BRANCH_NAME == 'develop' || env.BRANCH_NAME == 'master')) {
                    try {
                        withCredentials([string(credentialsId: params.NOTIFICATION_EMAIL, variable: 'NOTIFICATION_EMAIL')]) {
                            mail(
                                subject: "Jenkins failure: ${env.JOB_NAME} #${env.BUILD_ID}",
                                from: env.NOTIFICATION_EMAIL,
                                to: env.NOTIFICATION_EMAIL,
                                body: ("""
                                Jenkins build failed: ${env.JOB_NAME} on branch ${env.BRANCH_NAME} after ${currentBuild.durationString}

                                See logs on ${currentBuild.absoluteUrl}console
                                """).toString().replaceAll('\n[ \t]*', '\n'),
                            )
                        }
                        echo 'Build failure notification mail sent'
                    } catch (e) {
                        // Jenkins normally doesn't catch any exceptions here; catch it manually so we can see when
                        // there is an error with the mail queuing.  Note that succeeding past this does not mean
                        // the mail was successfully delivered.
                        echo "${e}"
                    }
                }
            }
            // Save logs of failed builds to s3 - we want to analyze where we may have jenkins issues.
            script {
                if (env.BRANCH_NAME == 'develop' || env.BRANCH_NAME == 'master') {
                    writeFile(file: 'build.log', text: getBuildLog())
                    sh "bin/clean-jenkins-log"
                    sh "container-host-files/opt/scf/bin/klog.sh -f ${cfNamespace}"
                    withAWS(region: params.S3_REGION) {
                        withCredentials([usernamePassword(
                            credentialsId: params.S3_CREDENTIALS,
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY',
                        )]) {
                            script {
                                def prefix = distPrefix()
                                // If prefix is not empty then trimming trailing "-" from path as distPrefix() returns "PR-${CHANGE_ID}-".
                                if (prefix){
                                    prefix = prefix.substring(0, prefix.length() - 1)
                                }
                                def subdir = "${params.S3_PREFIX}${distSubDir()}${prefix}/${env.BUILD_TAG}/"
                                s3Upload(
                                    file: 'cleaned-build.log',
                                    bucket: "${params.S3_LOG_BUCKET}",
                                    path: "${subdir}",
                                )
                                s3Upload(
                                    file: 'klog.tar.gz',
                                    bucket: "${params.S3_LOG_BUCKET}",
                                    path: "${subdir}",
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

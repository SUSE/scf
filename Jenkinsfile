#!/usr/bin/env groovy
// vim: set et sw=4 ts=4 :
pipeline {
    agent any
    options {
        disableConcurrentBuilds() // Otherwise clean would delete the images
        skipDefaultCheckout() // We do our own checkout so it can be disabled
        timestamps()
        timeout(time: 5, unit: 'HOURS')
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
            name: 'PUBLISH',
            defaultValue: true,
            description: 'Enable publishing',
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
            defaultValue: 'cf-opensusefs2',
        )
        string(
            name: 'S3_PREFIX',
            description: 'AWS S3 prefix to publish to',
            defaultValue: 'scf/config/',
        )
        credentials(
            name: 'DOCKER_CREDENTIALS',
            description: 'Docker credentials used for publishing',
            defaultValue: 'cred-docker-scf',
        )
        string(
            name: 'FISSILE_DOCKER_REGISTRY',
            defaultValue: '',
            description: 'Docker registry to publish to',
        )
        string(
            name: 'FISSILE_DOCKER_ORGANIZATION',
            defaultValue: 'splatform',
            description: 'Docker organization to publish to',
        )
    }

    environment {
        FISSILE_DOCKER_REGISTRY = "${params.FISSILE_DOCKER_REGISTRY}"
        FISSILE_DOCKER_ORGANIZATION = "${params.FISSILE_DOCKER_ORGANIZATION}"
    }

    stages {
        stage('wipe') {
            when {
                expression { return params.WIPE }
            }
            steps {
                deleteDir()
                script {
                    params.SKIP_CHECKOUT = false
                }
            }
        }
        stage('clean') {
            when {
                expression { return params.CLEAN }
            }
            steps {
                sh '''
                    docker images --format="{{.Repository}}:{{.Tag}}" | \
                        grep -E '/scf-|/uaa-|^uaa-role-packages:|^scf-role-packages:' | \
                        xargs --no-run-if-empty docker rmi
                '''
            }
        }
        stage('checkout') {
            when {
                expression { return ! params.SKIP_CHECKOUT }
            }
            steps {
                sh '''
                    git config --global --replace-all submodule.fetchJobs 0
                '''
                checkout scm
            }
        }
        stage('tools') {
            steps {
                ansiColor('xterm') {
                    sh '''
                        set -e +x
                        source ${PWD}/.envrc
                        set -x
                        unset HCF_PACKAGE_COMPILATION_CACHE
                        make ${FISSILE_BINARY}
                    '''
                }
            }
        }
        stage('build') {
            steps {
                ansiColor('xterm') {
                    sh '''
                        set -e +x
                        source ${PWD}/.envrc
                        set -x
                        unset HCF_PACKAGE_COMPILATION_CACHE
                        make vagrant-prep validate
                    '''
                }
            }
        }
        stage('dist') {
            steps {
                ansiColor('xterm') {
                    sh '''
                        set -e +x
                        source ${PWD}/.envrc
                        set -x
                        unset HCF_PACKAGE_COMPILATION_CACHE
                        rm -f scf-*-amd64-*.zip
                        make helm bundle-dist
                    '''
                }
            }
        }
        stage('publish') {
            when {
                expression { return params.PUBLISH }
            }
            steps {
                ansiColor('xterm') {
                    withCredentials([usernamePassword(
                        credentialsId: params.DOCKER_CREDENTIALS,
                        usernameVariable: 'DOCKER_HUB_USERNAME',
                        passwordVariable: 'DOCKER_HUB_PASSWORD',
                    )]) {
                        sh 'docker login -u "${DOCKER_HUB_USERNAME}" -p "${DOCKER_HUB_PASSWORD}" '
                    }
                    sh '''
                        set -e +x
                        source ${PWD}/.envrc
                        set -x
                        unset HCF_PACKAGE_COMPILATION_CACHE
                        make publish
                    '''
                    withAWS(region: params.S3_REGION) {
                        withCredentials([usernamePassword(
                            credentialsId: params.S3_CREDENTIALS,
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY',
                        )]) {
                            script {
                                def files = findFiles(glob: 'scf-*-amd64-*.zip')
                                for ( int i = 0 ; i < files.size() ; i ++ ) {
                                    s3Upload(
                                        file: files[i].path,
                                        bucket: "${params.S3_BUCKET}",
                                        path: "${params.S3_PREFIX}${files[i].name}",
                                    )
                                }
                            }
                        }
                    }
                }
            }
       }
    }
}

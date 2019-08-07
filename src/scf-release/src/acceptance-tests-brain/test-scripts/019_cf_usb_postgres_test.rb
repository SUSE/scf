#!/usr/bin/env ruby

require_relative 'cf_usb_helper'

class CFUSBPostgresTest < CFUSBTestBase
    def postgres_user
        @postgres_user ||= random_suffix('user')
    end

    def postgres_pass
        @postgres_pass ||= random_suffix('pass')
    end

    # Return the docker image to use for the server to test against
    def postgres_server_image
        @postgres_server_image_server_image ||= ENV.fetch('POSTGRES_SERVER_IMAGE', 'postgres:11.4')
    end

    def helm_release
        @helm_release ||= random_suffix('postgres-sidecar')
    end

    def helm_namespace
        helm_release
    end

    def helm_repo
        @helm_repo ||= ENV.fetch('POSTGRES_REPO', 'https://kubernetes-charts.suse.com/')
    end

    def helm_chart
        @helm_chart ||= ENV.fetch('POSTGRES_CHART', 'cf-usb-sidecar-postgres')
    end

    def helm_version
        @helm_version ||= ENV.fetch('POSTGRES_CHART_VERSION', '1.0.1')
    end

    def server_app
        @server_app ||= random_suffix('postgres')
    end

    def sidecar_app
        @sidecar_app ||= random_suffix('postgres-sidecar')
    end

    def service_type
        @service_type ||= random_suffix('postgres-service')
    end

    def service_instance
        @service_instance ||= random_suffix('pg-inst')
    end

    def wait_on_database
        run_with_retry 60, 5 do
            run({
                'PGHOST'       => tcp_domain,
                'PGPORT'       => "#{service_port}",
                'PGUSER'       => postgres_user,
                'PGPASSWORD'   => postgres_pass,
                'PGREQUIRESSL' => 'false',
                'PGDATABASE'   => postgres_user,
            }, 'psql --command "SELECT 1;"')
        end
    end

    def deploy_server
        at_exit do
            set errexit: false do
                run "cf delete -f #{server_app}"
            end
        end
        cmd = "cf push --no-start --no-route --health-check-type none #{server_app} -o #{postgres_server_image}"
        unless ENV.fetch('CF_DOCKER_USERNAME', '').empty?
            cmd += " --docker-username #{ENV['CF_DOCKER_USERNAME']}"
        end
        run cmd
        run "cf map-route #{server_app} #{tcp_domain} --random-port"
        run "cf set-env   #{server_app} POSTGRES_USER     #{postgres_user}"
        run "cf set-env   #{server_app} POSTGRES_PASSWORD #{postgres_pass}"
        run "cf start     #{server_app}"

        at_exit do
            set errexit: false do
                run "cf logs --recent #{server_app}"
            end
        end
        wait_on_database
    end

    def helm_chart_values
        ({
            CF_ADMIN_PASSWORD: ENV['CLUSTER_ADMIN_PASSWORD'],
            CF_ADMIN_USER: 'admin',
            CF_CA_CERT: ENV['INTERNAL_CA_CERT'],
            CF_DOMAIN: ENV['DOMAIN'],
            SERVICE_LOCATION: "http://cf-usb-sidecar-postgres.#{helm_namespace}.svc.#{ENV['KUBERNETES_CLUSTER_DOMAIN']}:8081",
            SERVICE_POSTGRESQL_HOST: tcp_domain,
            SERVICE_POSTGRESQL_PORT: service_port,
            SERVICE_POSTGRESQL_SSLMODE: 'disable',
            SERVICE_POSTGRESQL_USER: postgres_user,
            SERVICE_POSTGRESQL_PASS: postgres_pass,
            SERVICE_TYPE: service_type,
            UAA_CA_CERT: ENV['UAA_CA_CERT'].empty? ? ENV['INTERNAL_CA_CERT'] : ENV['UAA_CA_CERT'],
        })
    end
end

CFUSBPostgresTest.new.run_test

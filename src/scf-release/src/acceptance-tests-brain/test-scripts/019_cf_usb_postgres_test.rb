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

    def helm_repo
        @helm_repo ||= ENV.fetch('POSTGRES_REPO', 'https://kubernetes-charts.suse.com/')
    end

    def helm_chart
        @helm_chart ||= ENV.fetch('POSTGRES_CHART', 'cf-usb-sidecar-postgres')
    end

    def helm_version
        @helm_version ||= ENV.fetch('POSTGRES_CHART_VERSION', '1.0.1')
    end

    def wait_on_database
        run_with_retry 60, 5 do
            conn_string = {
                host: tcp_domain,
                port: service_port,
                dbname: postgres_user,
                user: postgres_user,
                password: postgres_pass,
                sslmode: 'disable',
            }

            run '/var/vcap/packages/sql-readiness/bin/sql-readiness',
                'postgres',
                conn_string.map { |k, v| "#{k.to_s}=#{v.to_s}" }.join(' ')
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
            CF_ADMIN_PASSWORD: ENV['CF_PASSWORD'],
            CF_ADMIN_USER: ENV['CF_USERNAME'],
            CF_CA_CERT: ENV['CF_CA_CERT'],
            CF_DOMAIN: ENV['CF_DOMAIN'],
            SERVICE_LOCATION: "http://cf-usb-sidecar-postgres.#{helm_namespace}.svc.#{ENV['KUBERNETES_CLUSTER_DOMAIN']}:8081",
            SERVICE_POSTGRESQL_HOST: tcp_domain,
            SERVICE_POSTGRESQL_PORT: service_port,
            SERVICE_POSTGRESQL_SSLMODE: 'disable',
            SERVICE_POSTGRESQL_USER: postgres_user,
            SERVICE_POSTGRESQL_PASS: postgres_pass,
            SERVICE_TYPE: service_type,
            UAA_CA_CERT: ENV['CF_CA_CERT_UAA'].empty? ? ENV['CF_CA_CERT'] : ENV['CF_CA_CERT_UAA'],
        })
    end
end

CFUSBPostgresTest.new.run_test

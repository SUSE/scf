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

    # Return the docker image to use for the side car
    def postgres_sidecar_image
        @postgres_sidecar_image ||= ENV.fetch('POSTGRES_SIDECAR_IMAGE', 'registry.suse.com/cap/cf-usb-sidecar-postgres:1.0.1')
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
    end

    def deploy_sidecar
        at_exit do
            set errexit: false do
                run "cf delete -f #{sidecar_app}"
            end
        end
        run "cf push #{sidecar_app} --no-start -o #{postgres_sidecar_image}"

        # Use a secret key that will be used by the USB to talk to your
        # sidecar, and set the connection parameters for the mysql client
        # sidecar so that it can talk to the mysql server from the previous
        # step.
        run "cf set-env #{sidecar_app} SIDECAR_API_KEY           #{sidecar_api_key}"
        run "cf set-env #{sidecar_app} SERVICE_TYPE              #{service_type}"
        run "cf set-env #{sidecar_app} SERVICE_POSTGRES_HOST     #{tcp_domain}"
        run "cf set-env #{sidecar_app} SERVICE_POSTGRES_PORT     #{service_port}"
        run "cf set-env #{sidecar_app} SERVICE_POSTGRES_SSLMODE  disable"
        run "cf set-env #{sidecar_app} SERVICE_POSTGRES_USER     #{postgres_user}"
        run "cf set-env #{sidecar_app} SERVICE_POSTGRES_PASSWORD #{postgres_pass}"
        run "cf set-env #{sidecar_app} SIDECAR_LOG_LEVEL         debug"

        at_exit do
            set errexit: false do
                run "cf logs --recent #{sidecar_app}"
            end
        end

        run "cf start   #{sidecar_app}"
    end

end

CFUSBPostgresTest.new.run_test

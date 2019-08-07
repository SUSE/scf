#!/usr/bin/env ruby

require_relative 'cf_usb_helper'

class CFUSBMySQLTest < CFUSBTestBase
    MYSQL_USER = 'root'
    MYSQL_PASS = 'testpass'

    # Return the docker image to use for the MySQL server to test against
    def mysql_server_image
        # Use MySQL 8.0.3, as MySQL defaults to the sha2 authentication plugin in 8.0.4
        # which isn't supported by github.com/go-sql-driver/mysql (the MySQL driver in
        # use in the USB broker).  This has actually been fixed in the driver, but
        # the USB sidecar has not yet upgraded.
        # https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_default_authentication_plugin
        # https://github.com/go-sql-driver/mysql/issues/785
        @mysql_server_image ||= ENV.fetch('MYSQL_SERVER_IMAGE', 'mysql/mysql-server:8.0.3')
    end

    # Return the docker image to use for the MySQL side car
    def mysql_sidecar_image
        @mysql_sidecar_image ||= ENV.fetch('MYSQL_SIDECAR_IMAGE', 'registry.suse.com/cap/cf-usb-sidecar-mysql:1.0.1')
    end

    def server_app
        @server_app ||= random_suffix('mysql')
    end

    def sidecar_app
        @sidecar_app ||= random_suffix('mysql-sidecar')
    end

    def service_type
        @service_type ||= random_suffix('mysql-service')
    end

    def service_instance
        @service_instance ||= random_suffix('my-db')
    end

    def wait_on_database(port, user, password)
        run_with_retry 60, 5 do
            run "mysql -u#{user} -p#{password} -P #{port} -h #{tcp_domain} > /dev/null"
        end
    end

    def deploy_server
        at_exit do
            set errexit: false do
                run "cf delete -f #{server_app}"
            end
        end
        run "cf push --no-start --no-route --health-check-type none #{server_app} -o #{mysql_server_image}"
        run "cf map-route #{server_app} #{tcp_domain} --random-port"
        run "cf set-env   #{server_app} MYSQL_ROOT_PASSWORD #{MYSQL_PASS}"
        run "cf set-env   #{server_app} MYSQL_ROOT_HOST '%'"
        run "cf start     #{server_app}"

        wait_on_database service_port, MYSQL_USER, MYSQL_PASS
    end

    def deploy_sidecar
        at_exit do
            set errexit: false do
                run "cf delete -f #{sidecar_app}"
            end
        end
        run "cf push #{sidecar_app} --no-start -o #{mysql_sidecar_image}"

        # Use a secret key that will be used by the USB to talk to your
        # sidecar, and set the connection parameters for the mysql client
        # sidecar so that it can talk to the mysql server from the previous
        # step.
        run "cf set-env #{sidecar_app} SIDECAR_API_KEY    #{sidecar_api_key}"
        run "cf set-env #{sidecar_app} SERVICE_TYPE       #{service_type}"
        run "cf set-env #{sidecar_app} SERVICE_MYSQL_HOST #{tcp_domain}"
        run "cf set-env #{sidecar_app} SERVICE_MYSQL_PORT #{service_port}"
        run "cf set-env #{sidecar_app} SERVICE_MYSQL_USER #{MYSQL_USER}"
        run "cf set-env #{sidecar_app} SERVICE_MYSQL_PASS #{MYSQL_PASS}"
        begin
            run "cf start   #{sidecar_app}"
        rescue
            set errexit: false do
                run "cf logs --recent #{sidecar_app}"
            end
            raise
        end
    end

end

CFUSBMySQLTest.new.run_test

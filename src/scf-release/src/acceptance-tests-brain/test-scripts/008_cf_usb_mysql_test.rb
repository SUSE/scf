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

    def helm_release
        @helm_release ||= random_suffix('mysql-sidecar')
    end

    def helm_namespace
        helm_release
    end

    def helm_repo
        @helm_repo ||= ENV.fetch('MYSQL_REPO', 'https://kubernetes-charts.suse.com/')
    end

    def helm_chart
        @helm_chart ||= ENV.fetch('MYSQL_CHART', 'cf-usb-sidecar-mysql')
    end

    def helm_version
        @helm_version ||= ENV.fetch('MYSQL_CHART_VERSION', '1.0.1')
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
            run '/var/vcap/packages/sql-readiness/bin/sql-readiness',
                'mysql',
                "#{user}:#{password}@tcp(#{tcp_domain}:#{port})/mysql"
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

    def helm_chart_values
        ({
            CF_ADMIN_PASSWORD: ENV['CLUSTER_ADMIN_PASSWORD'],
            CF_ADMIN_USER: 'admin',
            CF_CA_CERT: ENV['INTERNAL_CA_CERT'],
            CF_DOMAIN: ENV['DOMAIN'],
            SERVICE_LOCATION: "http://cf-usb-sidecar-mysql.#{helm_namespace}.svc.#{ENV['KUBERNETES_CLUSTER_DOMAIN']}:8081",
            SERVICE_MYSQL_HOST: tcp_domain,
            SERVICE_MYSQL_PORT: service_port,
            SERVICE_MYSQL_USER: MYSQL_USER,
            SERVICE_MYSQL_PASS: MYSQL_PASS,
            SERVICE_TYPE: service_type,
            UAA_CA_CERT: ENV['UAA_CA_CERT'].empty? ? ENV['INTERNAL_CA_CERT'] : ENV['UAA_CA_CERT'],
        })
    end

end

CFUSBMySQLTest.new.run_test

# Building nats with terraform

A terraform script with supporting pieces for getting nats running in
a horizon vm.  The script is currently running a temporary nats
container, but it has all the same functionality the deployed one will
have, although it isn't monitored.

## Usage

1. Set OpenStack client env variables in `../hpcs-apaas-tenant1-openrc.sh`,
   and source it to load the variables into the environment.
   If you're putting this file in version control, leave the OS_PASSWORD
   value unset and put the password in a private file called "password"
   in the same directory (assuming you're running this file from the
   directory that contains it).

   Also be sure to give the full path to your OpenStack private key file;
   this is the value of the `KEY_FILE` variable used by `../run-terraform.sh`.

2. To push the container: `bash ../run-terraform apply`.  This could take about 5 minutes.

3. To test:
   
   Get the VM's IP address (suppose it's 1.2.3.4).

   Start up nats-pub and nats-sub both pointing at the containerized nats server.  For example, on a Stackato VM start up two terminal sessions, and in each `cd` to `/s/code/cloud_controller_ng`.

   In one session type `bundle exec nats-sub sub1 -s http://1.2.3.4:80`.

   In the other, type `bundle exec nats-pub sub1 -s http://1.2.3.4:80 "hello from over here"`.

   You should see the message on the first system.

4. The end:
   
   `bash ../run-terraform destroy`

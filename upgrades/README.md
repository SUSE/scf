## Notes on running upgrades.

### Moving from cf v217 to v222

The main script is outlined in upgrade-217-222.sh.  It loads three
apps before the upgrade, and uses hardwired dirs.  It will need to
be modified before running on your machine.

Things that can go wrong:

1. configgin fails during startup -- this is most likely due to
a failure to add the new configs to a file like upgrade-v222.bash.
Each time we add consul settings on a version jump, we need to
capture the settings for upgrades.

2. roles running ruby 2.2.3 fail to start because libyaml-0-2 hasn't
been installed.  This is currently happening because the branches of
fissile and hcf-infrastructure aren't in sync.  One day this problem
will disappear.  Currently I'm running this command on the node:

    for x in cf-api cf-api\_worker cf-clock_global ; do
      echo $x
      docker exec -t $x apt-get install -y libyaml-0-2
    done

3. cf-api_worker and cf-clock_global will probably complain about bad
migrations. Eventually cf-api will run the migration successfully,
and then the other two will stop complaining.

  Note that the cloud controller database needs to be manually migrated
backwards before replacing a newer cf-api container with an older one.
This is because earlier versions of course have no idea of what
migrations will occur after they're released.

4. If the cf client returns a 404 status for early attempts to log in,
it might be that you're running older containers that don't contain
route\_register jobs for uaa, api, doppler, hm9000, and
loggregator_trafficcontroller. 

5. After a full upgrade, the apps weren't being restarted.  It turns
out that I had to restart the cf-runner-0 role on the other node
(which I hadn't upgraded yet) to get it talking to Nats.  As usual,
CF components are awful at retrying failed connections.  See
[Release It!](http://www.amazon.com/gp/product/0978739213).

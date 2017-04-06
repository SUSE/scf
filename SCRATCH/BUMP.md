
  __Note:__ Because this process involves cloning and building a release, it may take a long time.

  Cloud Foundry maintains a [compatibility spreadsheet](https://github.com/cloudfoundry-incubator/diego-cf-compatibility)
  for `cf-release`, `diego-release`, `etcd-release`, and `garden-runc-release`. If you are bumping
  all of those modules simultaneously, you can run `bin/update-cf-release.sh <RELEASE>` and skip steps
  1 and 2 in the example:

  The following example is for `cf-release`. You can follow the same steps for other releases.

  1. On the host machine, clone the repository that you want to bump:

    ```bash
  git clone src/cf-release/ ./src/cf-release-clone --recursive
    ```

  2. On the host, bump the clone to the desired version:

    ```bash
    git checkout v217
    git submodule update --init --recursive --force
    ```

  3. Create a release for the cloned repository:

    __Important:__ From this point on, perform all actions on the Vagrant box.

    ```bash
    cd ~/hcf
    ./bin/create-release.sh src/cf-release-clone cf
    ```

  4. Run the `config-diff` command:

    ```bash
    FISSILE_RELEASE='' fissile diff --release ${HOME}/hcf/src/cf-release,${HOME}/hcf/src/cf-release-clone
    ```

  5. Act on configuration changes:

    __Important:__ If you are not sure how to treat a configuration setting, discuss it with the HCF team.

    For any configuration changes discovered in step the previous step, you can do one of the following:

      * Keep the defaults in the new specification.

      * Add an opinion (static defaults) to `./container-host-files/etc/hcf/config/opinions.yml`.

      * Add a template and an exposed environment variable to `./container-host-files/etc/hcf/config/role-manifest.yml`.

    Define any secrets in the dark opinions file `./container-host-files/etc/hcf/config/dark-opinions.yml` and expose them as environment variables.

      * If you need any extra default certificates, add them here: `~/hcf/bin/dev-certs.env`.

      * Add generation code for the certificates here: `~/hcf/bin/generate-dev-certs.sh`.

  6. Evaluate role changes:

    a. Consult the release notes of the new version of the release.

    b. If there are any role changes, discuss them with the HCF team, [follow steps 3 and 4 from this guide](#how-do-i-add-a-new-bosh-release-to-hcf).

  7. Bump the real submodule:

    a. Bump the real submodule and begin testing.

    b. Remove the clone you used for the release.

  8. Test the release by running the `make <release-name>-release compile images run` command.



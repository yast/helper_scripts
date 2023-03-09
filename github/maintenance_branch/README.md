# Creating a New Maintenance Branch

This documentation describes how to create a new maintenance branch in the
YaST and libyui Git repositories. It describes the branching steps for the
SLE15-SP5 release, for later releases you might need to do some steps a bit
differently.

To do the branching you need several access permissions:

- Admin permission in GitHub (to change repository properties and push the changes)
- Maintainer permissions in both public and internal OBS instances
  (to create new subprojects, build packages and conatiner images)
- VPN access (to access the internal Git and Jenkins)

## Preparations

First we need to prepare the OBS projects.

The public OBS is used to build and host the container image which is used in
the CI tests at GitHub.

The internal OBS is used to build the package and for sending the actual
maintenance updates.

### Internal Open Build Service (IBS)

- At https://build.suse.de/project/new?namespace=Devel%3AYaST create a new
  maintenance subproject `Devel:YaST:SLE-15-SP5`

- Go to the [Meta](https://build.suse.de/projects/Devel:YaST:SLE-15-SP5/meta)
  section. Copy the settings from the [previous version project]
  (https://build.suse.de/projects/Devel:YaST:SLE-15-SP4/meta). Keep the
  new SP5 project name and update the repositories so they refer to the new
  SLE15-SP5. This will also grant the access for the YaST team members
  and to the Jenkins user to it can commit new packages and and create
  submit requests.

- Copy the current YaST packages from the original SLE project. This will
  initialize the packages to the current SLE versions.

```shell
# get the package list from the project for the previous release,
# copy those packages from the GA project to the new maintenance project
osc -A https://api.suse.de ls Devel:YaST:SLE-15-SP4 | xargs -I@ osc -A https://api.suse.de copypac -e SUSE:SLE-15-SP5:GA @ Devel:YaST:SLE-15-SP5
# these Ruby gems need to be used in the latest version, just copy them from YaST:Head
osc -A https://api.suse.de copypac openSUSE.org:YaST:Head rubygem-packaging_rake_tasks Devel:YaST:SLE-15-SP5
osc -A https://api.suse.de copypac openSUSE.org:YaST:Head rubygem-yast-rake Devel:YaST:SLE-15-SP5
```

*Note: If there is a new package or some package has been dropped you need to
copy/delete it manually!!*

### Public Open Build Service (OBS)

This is similar to the internal OBS setup with a small different that we are
additionally building some container images for GitHub CI.

#### Basic Project Setup

- At https://build.opensuse.org/project/new?namespace=YaSTCreate a new
  maintenance subproject `YaST:SLE-15:SP5`.

- Go to the [Meta](https://build.opensuse.org/projects/YaST:YaST:SLE-15:SP5/meta)
  section. Copy the settings from the [previous version project]
  (https://build.opensuse.org/projects/YaST:SLE-15:SP4/meta). Keep the
  new SP5 project name and update the repositories so they refer to the new
  openSUSE Leap 15.5 (the SLE projects are usually not available at this point).
  This will also grant the access for the YaST team members

- *Note: The order of the repositories in the `<repository>` section is important!*

- Set the [project config](https://build.opensuse.org/projects/YaST:SLE-15:SP5/prjconf) to
  build images and containers in that specified repositories instead of usual RPM packages

```
%if "%_repository" == "images"
Type: kiwi
Repotype: none
Patterntype: none
%endif

%if "%_repository" == "containers"
Type: docker
Repotype: none
Patterntype: none
%endif

Prefer: libyui-ncurses-pkg16 ruby2.5-rubygem-docile ruby2.5-rubygem-rubocop-0_71
```

*Note: If you get a "have choice for ..." dependency issue then you need to update
the `Prefer` line.*

##### Copy the Extra Packages

In this project we are building the CI container image which contains some
additional packages which are not included in the SLE release. These special
packages are needed only for development (like Rubocop).

Copy the same packages as in the previous maintenance project, but take the
versions from YaST:Head which might be potentially newer. This does not cover
the newly added Ruby gems. If you see some dependency problems later then
you need to fix them manually.

```shell
osc ls YaST:SLE-15:SP4 | grep rubygem | xargs -I@ osc copypac -e YaST:Head @ YaST:SLE-15:SP5
```

#### Build the Base Image

We build the base openSUSE Leap 15.5 image in this project. In theory we could
use the official Leap 15.5 container here, but in the past there were some
problems with that (less frequently rebuilds, sometimes in contained old
package versions or the included packages changed over time).

This ensures that the image is always up to date and that the content does not
change (unless we change it explicitly).

Copy the openSUSE Leap base image and update it:

```shell
# copy the image from the previous project
osc copypac -e YaST:Head opensuse-leap_latest-image YaST:SLE-15:SP5 opensuse-leap_15.5-image
# update it for the new release
osc co YaST:SLE-15:SP5
cd YaST:SLE-15:SP5/opensuse-leap_15.5-image
sed -e "s/15_4/15_5/" -i config.kiwi
sed -e "s/15\.4/15.5/" -i config.kiwi
# verify the changes
osc diff
# commit to OBS
osc commit -m "new base version"
```
Make sure the build is enabled for the `images` repository in the
[image repositories](https://build.opensuse.org/repositories/YaST:SLE-15:SP5/opensuse-leap_15.5-image).

Now the base Docker image with openSUSE Leap 15.5 should be built.

#### Build the CI Containers

Now we need to build the containers used in the GitHub CI. Usually it is OK
just to reuse the images from the previous release and slightly adapt them
for the release.

##### The Ruby Container

```shell
# copy the image from the previous project
osc copypac YaST:SLE-15:SP4 ci-ruby-container YaST:SLE-15:SP5
# go to the checkout and update it for the new release
sed -e "s/15\.4/15.5/" -i Dockerfile
sed -e "s/SP4/SP5/" -i Dockerfile
# verify the changes
osc diff
# commit to OBS
osc commit -m "new base version"
```

Make sure build is enabled for the [containers repository](
https://build.opensuse.org/repositories/YaST:SLE-15:SP5/ci-ruby-container).


It is a good idea to compare the differences from the YaST:Head project,
maybe there were some new changes which might make sense also in the
maintenance project. Check the diff with command:

```shell
osc rdiff YaST:Head ci-ruby-container-leap_latest YaST:SLE-15:SP5 ci-ruby-container
```

##### The C++ Container

This is similar to the Ruby container above, see more details there.

```shell
osc copypac YaST:SLE-15:SP4 ci-cpp-container YaST:SLE-15:SP5
sed -e "s/15\.4/15.5/" -i Dockerfile
sed -e "s/SP4/SP5/" -i Dockerfile
osc diff
osc commit -m "new base version"
osc rdiff YaST:Head ci-cpp-container YaST:SLE-15:SP5 ci-cpp-container
```

##### The libstorage-ng Container

Again, this is similar to the Ruby container above, see more details there.

```shell
osc copypac YaST:SLE-15:SP4 ci-libstorage-ng-container YaST:SLE-15:SP5
sed -e "s/15\.4/15.5/" -i Dockerfile
sed -e "s/SP4/SP5/" -i Dockerfile
osc diff
osc commit -m "new base version"
osc rdiff YaST:Head ci-cpp-container YaST:SLE-15:SP5 ci-cpp-container
```

## Jenkins Configuration

Jenkins is used for two tasks:

- Automatically build the package and send it to the configured maintenance project
- Copy the packages from IBS to OBS for building the CI images, to ensure that
  CI images contain the latest packages from the maintenance branch

The Jenkins configuration is kept in the internal Gitlab server:
https://gitlab.suse.de/yast/infra

```shell
git clone gitlab@gitlab.suse.de:yast/infra.git
cd infra
```

### IBS -> OBS Synchronization

The [Jenkins Job Builder](https://jenkins-job-builder.readthedocs.io/en/latest/index.html)
tool is used for managing the Jenkins jobs.

See more details in the [documentation](
https://gitlab.suse.de/yast/infra/-/blob/master/doc/jenkins-jobs.md).

```shell
sudo pip install jenkins-job-builder
```

The synchronization jobs are defined in `jenkins/ci.suse.de/sync-jobs.yaml` file.
Just add a new job at the end and make the previous jobs to run less often.

It is a good idea to always check the job configuration before deploying with:

```shell
# the regexp at end specifies the jobs to display
jenkins-jobs --conf jenkins/ci.suse.de.ini test jenkins/ci.suse.de/ "yast-obs-sync-sle15*"
```

If it is OK then you can deploy the jobs with:

```shell
jenkins-jobs --conf jenkins/ci.suse.de.ini update jenkins/ci.suse.de/ "yast-obs-sync-sle15*"
```

Check the newly create job in https://ci.suse.de/view/YaST/ and start it manually
to synchronize the packages (click "Build Now" button in the [job details](
https://ci.suse.de/view/YaST/job/yast-obs-sync-sle15-sp5/)).

Do not forget to open a merge request in gitlab.suse.de with your changes.

### Autosubmission

The autosubmission jobs are defined in the `jenkins/ci.suse.de/yast-jobs.yaml` file.

Add jobs for new branch in the `project_defaults` section.

Note: if you still want to submit the GA project because the maintenance project
is not yet open use the `sle_latest` submit target and change that to `sleXspY`
after releasing the GA version.

```shell
# test
jenkins-jobs --conf jenkins/ci.suse.de.ini test jenkins/ci.suse.de/ "*-SLE-15-SP5"
# deploy
jenkins-jobs --conf jenkins/ci.suse.de.ini update jenkins/ci.suse.de/ "*-SLE-15-SP5"
```

If you need to disable autosubmission for some older branch or for `master`
then run the [yast-autosubmission](https://ci.suse.de/view/YaST/job/yast-autosubmission/)
Jenkins job with the appropriate parameters.

#### Build Targets

The `osc` build and submit targets are defined in the [targets.yml](
https://github.com/yast/yast-rake/blob/master/data/targets.yml) file in the
`yast-rake` Ruby gem.

Verify that the new build target is present. If not then add it and deploy
the new gem to all Jenkins workers. (Update the [gems.sls](
https://gitlab.suse.de/yast/infra/-/blob/master/srv/salt/yast-jenkins/gems.sls)
file and run salt, see the [documentation](https://gitlab.suse.de/yast/infra/-/blob/master/doc/salt.md).)

## Creating the Git Branches

Now we are ready to do the actual branching in the Git repositories.

### Prerequisities

For branching the Git repositories you need an admin permission at GitHub.

The easiest way to authenticate in scripts is generating a [GitHub access token](
https://github.com/settings/tokens/new)
and write it to the `~/.netrc` file in format.

```
machine api.github.com
  login <GITHUB_USERNAME>
  password <ACCESS_TOKEN>
```

See more details in the [GitHub documentation](
https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token).

### Updating the Branching Script

The main branching script is located in the [create_maintenance_branch.rb](
./create_maintenance_branch.rb) file.

The branching script at the beginning contains some hardcoded constants which
are related to the branching process and need to be adapted for each branch.

You also might need to adapt the script to a different scenario, some things
might have been changed since the last time it was used.

### Test Run

```shell
./create_maintenance_branch.rb -c -r yast-yast2
```

### Full Run

```shell
./create_maintenance_branch.rb
```

The full run takes about 20-30 minutes.

## Libyui

- Create a maintenance subproject at
  https://build.opensuse.org/project/subprojects/devel:libraries:libyui
- Copy the project meta from the previous project
- Copy the project config from the previous project

```shell
osc ls devel:libraries:libyui:SLE-15:SP4 | xargs -I@ osc -A https://api.suse.de copypac -e -t https://api.opensuse.org SUSE:SLE-15-SP5:GA @ devel:libraries:libyui:SLE-15:SP5
osc copypac -e devel:libraries:libyui:SLE-15:SP4 ci-libyui-container-15.4 devel:libraries:libyui:SLE-15:SP5 ci-libyui-container
```

Update the ci-libyui-container image:

```
sed -e "s/15\.4/15.5/" -i Dockerfile
sed -e "s/SP4/SP5/" -i Dockerfile
osc diff
osc commit -m "update"
```

```shell
./create_maintenance_branch.rb -c -o libyui -r libyui
# before confirming the changes fix the version in VERSION.cmake manually!!
```

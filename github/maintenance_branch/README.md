# Creating a New Maintenance Branch


## Preparations

### Internal Open Build Service (IBS)

- At https://build.suse.de/project/new?namespace=Devel%3AYaST create a new
  maintenance project `Devel:YaST:SLE-15-SP5`

- Go to the [Meta](https://build.suse.de/projects/Devel:YaST:SLE-15-SP5/meta)
  section. Copy and update the settings from the previous version project
  (e.g. https://build.suse.de/projects/Devel:YaST:SLE-15-SP4/meta)

Copy the current YaST packages from the original SLE project. Get the package
list from the project for the previous release. If there is a new package or
some package has been dropped you need to copy it manually.

```shell
osc -A https://api.suse.de ls Devel:YaST:SLE-15-SP4 | xargs -I@ osc -A https://api.suse.de copypac -e SUSE:SLE-15-SP5:GA @ Devel:YaST:SLE-15-SP5
```

### Public Open Build Service (OBS)

#### Basic Project Setup

- At https://build.opensuse.org/project/new?namespace=YaSTCreate a new
  maintenance subproject with name `YaST:SLE-15:SP5`.

- Go to the [Meta](https://build.opensuse.org/projects/YaST:YaST:SLE-15:SP5/meta)
  section. Copy and update the settings from the previous version project
  (e.g. https://build.opensuse.org/projects/YaST:SLE-15:SP4/meta)

Note: The order of the repositories in the `<repository>` section is important!

Keep the original project name, update the repository names to match the
created branch. In this case the repositories need to be based on openSUSE
Leap 15.5.

Set the project config at https://build.opensuse.org/projects/YaST:SLE-15:SP5/prjconf to

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

If you get a "have choice for ..." dependency issue then you need to update
the `Prefer` line.

##### Copy the Extra Packages

```shell
osc ls YaST:SLE-15:SP4 | grep rubygem | xargs -I@ osc copypac -e YaST:Head @ YaST:SLE-15:SP5
```

Copy the same packages as in the previous maintenance project, but take the
versions from YaST:Head which might be potentially newer. This does not cover
the newly added Ruby gems. If you see some dependency problems later then
you need to fix them manually.

#### Build the Base Image

Copy the openSUSE Leap base image and update it:

```shell
osc co YaST:SLE-15:SP5
osc copypac YaST:Head opensuse-leap_latest-image YaST:SLE-15:SP5 opensuse-leap_15.5-image
cd opensuse-leap_15.5-image
sed -e "s/15_4/15_5/" -i config.kiwi
sed -e "s/15\.4/15.5/" -i config.kiwi
osc diff
osc commit -m "update"
```

Make sure build is enabled for the "images" repository, https://build.opensuse.org/repositories/YaST:SLE-15:SP5/opensuse-leap_15.5-image

Now the base Docker image with openSUSE Leap should be built.

Note: In theory we could use the official openSUSE Leap images as the base image.
But in the past was a bit problematic, it was not rebuild often so sometimes
it could contain older packages which were in conflict when later installing
additional packages.

#### Build the CI Containers

##### The Ruby Container

```shell
#osc copypac YaST:Head ci-ruby-container-leap_latest YaST:SLE-15:SP5 ci-ruby-container
osc copypac YaST:SLE-15:SP4 ci-ruby-container YaST:SLE-15:SP5
```
Make sure build is enabled for the "containers" repository, https://build.opensuse.org/repositories/YaST:SLE-15:SP5/ci-ruby-container


```
sed -e "s/15\.4/15.5/" -i Dockerfile
sed -e "s/SP4/SP5/" -i Dockerfile
osc diff
osc commit -m "update"
```

Note: Compare the differences from the YaST:Head ci-ruby-container-leap_latest project 

```shell
osc rdiff YaST:Head ci-ruby-container-leap_latest YaST:SLE-15:SP5 ci-ruby-container
```

##### The C++ Container

```shell
osc copypac YaST:SLE-15:SP4 ci-cpp-container YaST:SLE-15:SP5
sed -e "s/15\.4/15.5/" -i Dockerfile
sed -e "s/SP4/SP5/" -i Dockerfile
osc diff
osc commit -m "update"
osc rdiff YaST:Head ci-cpp-container YaST:SLE-15:SP5 ci-cpp-container
```

##### The libstorage-ng Container

```shell
osc copypac YaST:SLE-15:SP4 ci-libstorage-ng-container YaST:SLE-15:SP5
sed -e "s/15\.4/15.5/" -i Dockerfile
sed -e "s/SP4/SP5/" -i Dockerfile
osc diff
osc commit -m "update"
osc rdiff YaST:Head ci-cpp-container YaST:SLE-15:SP5 ci-cpp-container
```

## Jenkins Configuration

https://gitlab.suse.de/yast/infra

```shell
git clone gitlab@gitlab.suse.de:yast/infra.git
cd infra
```


### IBS -> OBS Synchronization

The synchronization jobs are defined in `jenkins/ci.suse.de/sync-jobs.yaml` file.

Test:

```shell
jenkins-jobs --conf jenkins/ci.suse.de.ini test jenkins/ci.suse.de/ "yast-obs-sync-sle15*"
```

Activate changes:

```shell
jenkins-jobs --conf jenkins/ci.suse.de.ini update jenkins/ci.suse.de/ "yast-obs-sync-sle15*"
```

Open a merge request in gitlab.suse.de with your changes.

Check the newly create job in https://ci.suse.de/view/YaST/

Start it manually to synchronize the packages ("Build Now" in
https://ci.suse.de/view/YaST/job/yast-obs-sync-sle15-sp5/)


### Autosubmission

The autosubmission jobs are defined in the `jenkins/ci.suse.de/yast-jobs.yaml` file.

Add jobs for new branch in the `project_defaults` section.

Test:

```shell
jenkins-jobs --conf jenkins/ci.suse.de.ini test jenkins/ci.suse.de/ "*-sle15-sp5"
```

Activate changes:

```shell
jenkins-jobs --conf jenkins/ci.suse.de.ini update jenkins/ci.suse.de/ "*-sle15-sp5"
```

#### Build Targets

The `osc` build and submit targets are defined in the [targets.yml](
https://github.com/yast/yast-rake/blob/master/data/targets.yml) file in the
`yast-rake` Ruby gem.

Verify that the new build target is present. If not then add it and deploy
the new gem to all Jenkins workers. (Update the [gems.sls](
https://gitlab.suse.de/yast/infra/-/blob/master/srv/salt/yast-jenkins/gems.sls)
file and run salt.)


## Creating the Git Branches

### Prerequisities

- GitHub access token
- `~/.netrc`
  ```
  machine api.github.com
    login <GITHUB_USERNAME>
    password <ACCESS_TOKEN>
  ```

### Updating the Branching Script

### Test Run

### Full Run

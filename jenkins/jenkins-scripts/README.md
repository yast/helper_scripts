
# Jenkins Scripts

Here is a collection of Jenkins scripts for mass management.

The credentials for [public Jenkins instance](https://ci.opensuse.org/view/Yast)
can be found in the [internal Wiki page](https://wiki.microfocus.net/index.php/YAST).

## How to Use

Here is a example how to run the scripts:

```shell
 JENKINS_USER=foo JENKINS_PASSWORD=bar ./jenkins_trigger_builds.rb
^ Space at the beginning! 
```

*Do not forget to use a space at the beginning so the credentials are not
saved in the shell history!*

## List of Scripts

- `jenkins_trigger_builds.rb` - automatically run YaST jobs (`yast-*-master` by
  default)
- `jenkins_modify_jobs.rb` - mass configuration change
- `jenkins_remove_jobs.rb` - mass job removal


# Triggering the Jenkins Jobs

The `jenkins_trigger_builds.rb` script can automatically trigger all YaST
`*-master` jobs at the [public Jenkins instance](https://ci.opensuse.org/view/Yast).

## Usage

```shell
 JENKINS_USER=foo JENKINS_PASSWORD=bar ./jenkins_trigger_builds.rb
```

*Do not forget to use a space at the beginning so the credentials are not
saved in the shell history.*

The credentials can be found in the
[internal Wiki page](https://wiki.microfocus.net/index.php/YAST).

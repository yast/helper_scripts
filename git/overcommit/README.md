# Overcommit

The [Overcommit](https://github.com/sds/overcommit) tool can configure
and manage Git hooks in an easy way. This directory contains helper scripts for
adding some nice hooks to the YaST Git checkout.

The motivation is to avoid "make Rubocop happy" commits or avoid committing
code which breaks unit tests. We run the CI builds so we would find the issues
anyway but with this tool you can find the problems sooner and faster.

See https://blog.ladslezak.cz/2016/06/06/overcommit/ for example usage.

## Requirements

Install the `overcommit` Ruby gem from [YaST:Head](
https://build.opensuse.org/project/show/YaST:Head) OBS project.

1. Add the repository:

   ```shell
   # openSUSE Leap
   zypper addrepo -r "https://download.opensuse.org/repositories/YaST:/Head/openSUSE_Leap_${releasever}" YaST:Head
   # openSUSE Tumbleweed
   zypper addrepo -r https://download.opensuse.org/repositories/YaST:/Head/openSUSE_Tumbleweed YaST:Head
   ```

2. Install the packages:

   ```shell
   # hunspell is used for spell checking the commit messages
   zypper install "rubygem(overcommit)" hunspell
   ```

## Usage

## Generating the Config Files and Installing Overcommit Hooks

The `install_overcommit.rb` script generates the default `.overcommit.yml`
configuration files and installs the Overcommit hooks in the specified path.
The target path is searched for Git repositories recursively, you can install
the hooks to all YaST Git repositories at once, just use the parent path.

If the configuration file already exists it is not created to not possibly
overwrite the manual changes. If you want to re-generate the configuration you have
to delete it first.

```shell
./install_overcommit.rb <directory>
```

The `.overcommit.yml` configuration file is not added to the Git index but is
listed in the `.git/info/exclude` file so it is ignored by Git even without
touching the `.gitignore` file.

### The Created Configuration

The default created configuration does these actions:

#### On `git commit`

- Runs a spell checker against the commit message. The potential mistakes are
  reported only as warnings, the commit to Git is not blocked but it is a good
  idea to check whether there is some typo in the message or not.
- Checks whether the commit targets a forbidden branch like `master` or
  `SLE-15-SP4` (any changes to these branches needs to be done via pull requests,
  GitHub would reject the push later anyway but it is better to notice this sooner)
- Runs a Rubocop check when the `.rubocop.yml` file is present in the repository.

#### On `git push`

- Runs the RSpec unit tests, `rake test:unit`) when a `Rakefile` is found
  or runs `make check` when a `Makefile` is found.

Of course, you might add some more checks to the configuration or modify the
defaults, see more details in the [Overcommit documentation](
https://github.com/sds/overcommit#built-in-hooks).

## Generating Custom Dictionary

The default Git hooks include running a spell checker for the commit messages.
To avoid many false positives you can import a custom YaST dictionary which
contains a lot of YaST specific words.

```shell
./install_custom_dictionary.rb
```

This script downloads the [custom YaST dictionary](
https://github.com/yast/yast.github.io/blob/master/.spell.yml) and installs it
into the `~/.hunspell_en_US` file. The existing words are kept.

## Disabling Overcommit

Sometimes you want to perform a Git operation even when an Overcommit hook fails.
For example the unit tests might fail because you are working in a SLE-12 branch
but you have SLE15/Leap15 installed in your system.

In that case you can disable the Overcommit hooks temporarily by setting the
environment variable `OVERCOMMIT_DISABLE=1` for that Git command.

```shell
OVERCOMMIT_DISABLE=1 git push
```

If you want to disable Overcommit permanently then run in the respective Git
checkout this command

```shell
overcommit --uninstall
```

## Updating the Configuration

For [security reasons](https://github.com/sds/overcommit#security) Overcommit
tracks the content of the `.overcommit.yml` configuration file. You need to run
`overcommit --sign` whenever you touch that file.

If the change was not done by you then you should carefully check the file
content.

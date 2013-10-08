chef-library
============

Our library of Chef configurations for bootstrapping systems. This is
a combination of cookbooks and utilities for bootstrapping rails
production. It has been developed and tested on Ubuntu/Debian systems, but
may work elsewhere.

## Setup

You need the following Perl modules from CPAN for running `amoeba` commands:
  - JSON
  - File::Temp

They can be installed via the `cpan` command (may require sudo on OS X):

    $ cpan JSON File::Temp

Or you can use `cpanm` to avoid the lengthy cpan configuration:

    $ curl -L http://cpanmin.us | perl - -S JSON File::Temp

## Passwordless deploys

If you'd like to do passwordless deploys using SSH public keys, place your
public key in a file or folder corresponding to the app name, or 'root'
for all apps, in the `authorized_keys/` folder.

In order to make your local SSH keys available on the remote system, capistrano
forwards your ssh-agent to the remote host. To facilitate this, you can use
`ssh-agent` with [Keychain](http://www.funtoo.org/wiki/Keychain), which stores
your ssh keys in memory for the duration of the bash session. You can read more
about setting up ssh keys, ssh-agent, and Keychain here:
https://wiki.archlinux.org/index.php/SSH_Keys#ssh-agent

An app user is named after its respective app, so any public keys for the app
should be placed into a subdirectory with the same name as the app. The 'root'
keys are copied into every user's authorized_keys file, including the
deployment user and all app users. Because the actual 'root' user is never
used for login directly, it will NOT be added to root's authorized_keys file.
You should instead use the 'deploy' user with the `sudo` command for any
operation requiring root privileges.

After adding a new key, the `amoeba node refresh_keys` command will convert
the authorized_keys into a local data bag, to be used during deployment. This
command is automatically run before any bootstrap or push operation however,
so you won't need to invoke it manually.

## Usage

You'll need to first create a new server VM. If you're using vagrants this
is just:

    $ vagrant up

If you aren't using vagrant, login to your cloud provider, and create the image.

Create a node definition JSON file in the `nodes/` directory. You can list
the currently defined nodes using the `amoeba node list` command.

After you have a fresh box, you can install chef and its dependencies
using the `amoeba node bootstrap` command:

    $ amoeba node bootstrap <node>

Note: You may be asked for a password multiple times if you haven't set up
public key login. To avoid this you can set up your public key on the
server by adding it to 'root' or 'deploy' authorized_keys subdirectory.

When the system is bootstrap, root user login is disabled, and you must SSH
using the "deploy" user, and sudo. Sudo is password-less for the deploy
user, to facilitate scripting. This is considered secure since you must use
an SSH key to login as "deploy".

If for some reason the bootstrap failed after setting up the deploy user, and
your pre-provision login credentials do not work, you can try running:

    $ amoeba node setup_deployer

This will set the deploy user to 'deploy', which would have been the case had
the bootstrap returned successfully. Now you can try re-running the bootstrap.

You're finally ready to deploy your node:

    $ amoeba node push <node>

You should now have a box configured to your desired node config.

## Shell

### Running commands as deployer

You can ssh into the node as the 'deploy' user:

    $ amoeba node shell <node>

You can also execute arbitrary commands:

    $ amoeba node exec <node> <cmd>

To escalate privileges using sudo:

    $ amoeba node sudo <node> <cmd>

### Running commands as app user

You can also connect to the node as the app user.

For an interactive shell as the app user:

    $ amoeba app shell <node>

For executing commands in the app context (loading .env):

    $ amoeba app exec <node> <cmd>


## Deploying with Capistrano

Once you have your node set up, you can deploy your app using Capistrano,
via the `amoeba node deploy` shortcut, which will run using a Capfile
dynamically generated from your node config:

    $ amoeba node deploy <node>

You can also run arbitrary capistrano commands:

    $ amoeba node cap <node> [<cap-args>]

The Capfile itself can be generated as well:

    $ amoeba node capfile <node>  >  <app-dir>/Capfile

We recommend you do not ever edit the capfile that is generated. Just
install it in your application. If you wish to customize the deploy
process for any reason, you can created a config/deploy.rb file in
your project. The default Capfile will detect this file and include
it if present, and you can hook into any stage of Capistrano.

Also note you can create multiple Capfiles easily such as 
`Capfile.prod` and `Capfile.beta`. We recommend using the default
Capfile for staging, or some non-production system so by default
when users type `cap deploy` they don't deploy to production. This
means you must be explicit (i.e. `cap -f Capfile.prod deploy`).

### Capistrano Commands

You bootstrap a new system with:

    $ cap deploy:cold

It will run `rake db:setup` followed by `rake db:seed` after deployment.

After the initial deployment, you can run:

    $ cap deploy

Which just follows a normal code deployment (using git). Note you can
specify a branch to either command, by passing in the `branch` var to
Capistrano (see Capistrano's README on how to do so).

The deploy command will also run migrations automatically when it's
complete.

## Other commands

Here are some of the other commands used internally. You don't really need
to know about these, but they can't hurt to know about.

This fetches the current node state as a JSON object into
`data_bags/nodes/<node>.json`, which is ignored by git:

    $ amoeba node pull <node>

This removes a node's data bags, which also resets the deployment user to
a pre-provisioned state:

    $ amoeba node clean <node>

There is also a shortcut to check monit status:

    $ amoeba node status <node>

To get the app-user's public key:

    $ amoeba app pubkey <node>


## Node Configuration

### Adding Cron Jobs

You can add cron jobs via the `application.crontab` attribute:

```javascript
    "application": {
      "crontab": [
        {
          "command": "echo 'hello world'",
          "minute": "30",
          "hour": "10",
          "day": "*"
        }
      ]
    }
```

These entries are created in the application-user's crontab. Each crontab
entry takes the same kind of arguments as in an actual crontab file,
including: day, hour, hour, minute, month, and weekday. The default values for
these are `*`, meaning every minute, hour, etc. For a list of available
attributes take a look at the Opscode
[cron resource](http://docs.opscode.com/resource_cron.html) reference page.

### Setting timezone and locale

Set the timezone via the `tz` attribute (defaults to `UTC`):

```javascript
    "tz": "UTC"
```

System locale settings can be in the `locale` attribute, see the
[locale cookbook README](https://github.com/fnordfish/chef-locale) for more info.

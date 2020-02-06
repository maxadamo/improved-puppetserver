# improved-puppetserver

## Steps to create the Puppet HA

#### Table of Contents

1. [Preamble](#preamble)
1. [Sharing the certificates](#sharing-the-certificates)
1. [on puppet01 and puppet02](#on-puppet01-and-puppet02)
1. [Puppet check](#puppet-check)
1. [Consul configuration](#consul-configuration)
    * [consul config in details](#consul-config-in-details)
1. [puppet.conf - agent](#puppet.conf---agent)
1. [puppet.conf - server](#puppet.conf---server)
1. [temporarily recover from PuppetDB failure - maybe obsolete](#temporarily-recover-from-puppetdb-failure---maybe-obsolete)


### Preamble

1. we have 2 puppet servers:

    - 1st server: `puppet01.domain.org`

    - 2nd server: `puppet02.domain.org`

1. we have Consul

1. we have two NFS VMs (if we have puppet multi-master, we deserve NFS multi-master)

### Sharing the certificates

`/etc/puppetlabs/puppet/ssl` is shared with NFS

A ZFS multi master appliance is still in the works, but it will be overkill for this use case.
You can share the certificates using this small HA appliance called [tiny_nas](https://forge.puppet.com/maxadamo/tiny_nas) 

#### on puppet01 and puppet02

```bash
puppet cert --generate $(hostname -f) --dns_alt_names=$(hostname -s).your.consul.node.domain
```

psst: this command is obsolete and it's not gonna work. You need to replace it with `puppetserver ....` correspondant command

### Puppet check (triggered by Consul)

You need a basic shell script (`/usr/local/bin/puppet-check.sh`) that will tell consul to lower/raise the weight based on CPU usage, or remore the node when it's unhealthy: [puppet-check.sh](https://github.com/maxadamo/improved-puppetserver/blob/master/scripts/puppet-check.sh)

#### Consul configuration

You may want to use the Puppet module for [Consul](https://forge.puppet.com/KyleAnderson/consul) made by Solarkennedy. 
You'll get a consul configuration file like this this one: [puppet_service.json](https://github.com/maxadamo/improved-puppetserver/blob/master/scripts/service_puppet.json)

##### consul config in details

the bottom part of the json contains the following statements:

```json
    "weights": {
      "passing": 10,
      "warning": 1
    }
```

which means:

- if the puppet check succeeds (`passing`) the weight of the SRV record will be 10
- it the puppet check finds that your CPU is higher than 90%, the weight is lowered to 1
- if the check fails, your puppet is borked and consul will delete its record

#### puppet.conf - agent

on your agents you'll have this [puppet.conf](https://github.com/maxadamo/improved-puppetserver/blob/master/scripts/puppet_agent.conf)

#### puppet.conf - server

on your server you'll have this [puppet.conf](https://github.com/maxadamo/improved-puppetserver/blob/master/scripts/puppet_server.conf)

### temporarily recover from PuppetDB failure - maybe obsolete

- fail one server:

```bash
puppet agent --disable
chmod -x /usr/local/bin/puppet-check.sh
```

- on the other puppet server:

```bash
puppet agent --disable
mv /etc/puppetlabs/puppet/routes.yaml /
sed -i s,'storeconfigs = true','storeconfigs = false', /etc/puppetlabs/puppet/puppet.conf
sed -i /'storeconfigs_backend = puppetdb'/d /etc/puppetlabs/puppet/puppet.conf
systemctl restart puppetserver
```

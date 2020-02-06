# improved-puppetserver

## Steps to create the Puppet HA

### Preamble

we have 2 puppet servers:

the 1st server is: `puppet01.domain.org`

the 2nd server is: `puppet02.domain.org`

we have Consul

we have two NFS VMs (yes, if we have HA puppet, we deserve a HA NFS appliance)

### sharing the certificates

`/etc/puppetlabs/puppet/ssl` is shared with NFS

A ZFS multi master appliance is still in the works, but it will be overkill for this use case.
You can share the certificates using this small HA appliance called [tiny_nas](https://forge.puppet.com/maxadamo/tiny_nas) 

#### on puppet01 and puppet02

```bash
puppet cert --generate $(hostname -f) --dns_alt_names=$(hostname -s).your.consul.node.domain
```

psst: this command is obsolete and it's not gonna work. You need to replace it with `puppetserver ....` correspondant command

#### Consul configuration

You may want to use Puppet module for [Consul](https://forge.puppet.com/KyleAnderson/consul) from Solarkennedy
and you'll get something like this script

### you need a puppet check (triggered by Consul)

You need a basic shell script (`/usr/local/bin/puppet-check.sh`) that will tell consul to lower/raise the weight based on CPU usage, or remore the node when it's unhealthy.

### temporarily recover from PuppetDB failure (is this part still needed?)

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

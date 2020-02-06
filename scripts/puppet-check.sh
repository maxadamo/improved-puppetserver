#!/bin/bash
#
# == Check puppet server
#
# This scripts checks:
#   - Redis  (emits OK or CRIT)
#   - CA availability  (emits OK or CRIT)
#   - Puppetserver status  (emits OK or CRIT)
#   - Puppetserver CPU usage  (emits OK or WARN)
#
# Most probably you don't have Redis and you can comment it out.
# But if you have it, you can create a key called "do_not_delete"
#
PATH=$PATH:/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
CERT_DIR=/etc/puppetlabs/puppet/ssl
FQDN=$(hostname -f)
STATE_OK=0
STATE_WARN=1
STATE_CRIT=2


# Check Redis
if [[ $(redis-cli -s /var/run/redis/redis.sock -a this-is-my-auth-token EXISTS do_not_delete) -lt 1 ]]; then
    echo "CRITICAL: Could not access Redis Server"
    exit $STATE_CRIT
fi

# Check CA
if ! sudo -u puppet curl -s --cert ${CERT_DIR}/certs/${FQDN}.pem \
  --key ${CERT_DIR}/private_keys/${FQDN}.pem \
  --cacert ${CERT_DIR}/ca/ca_crt.pem -H 'Accept: pson' \
  "https://${FQDN}:8140/puppet-ca/v1/certificate/${FQDN}" | grep -q 'CERTIFICATE'; then
    echo "CRITICAL: Could not access Certificate Authority API"
    exit $STATE_CRIT
fi

# Check Puppetserver
API_STATUS=$(sudo -u puppet curl -w "%{http_code}" -s --cert ${CERT_DIR}/certs/${FQDN}.pem \
  --key ${CERT_DIR}/private_keys/${FQDN}.pem --cacert ${CERT_DIR}/ca/ca_crt.pem \
  -H 'Accept: pson' "https://${FQDN}:8140/status/v1/services?level=debug")
RETURN_CODE="${API_STATUS: -3}"
JSON_STATUS="${API_STATUS::-3}"

# Ensure that return code is 200
if [[ $RETURN_CODE -ne 200 ]]; then
  echo "CRITICAL: Could not access Puppet Server"
  exit $STATE_CRIT
fi

# Emit warning if CPU usage is over 90%
CPU_USAGE=$(echo ${JSON_STATUS} | jq '."status-service".status.experimental."jvm-metrics"."cpu-usage"')
if [[ ${CPU_USAGE%.*} -gt 90 ]]; then
    echo "WARNING: CPU usage reached ${CPU_USAGE}"
    exit $STATE_WARN
fi

if tty -s ; then
  echo "OK: CPU usage ${CPU_USAGE}"
else
  echo "OK: I never felt so good"
fi

exit $STATE_OK

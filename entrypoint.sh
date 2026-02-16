#!/bin/bash
set -e

# Default variables
: "${REALM:=EXAMPLE.COM}"
: "${DOMAIN:=EXAMPLE}"
: "${ADMIN_PASS:=Pa$$w0rd}"
: "${DNS_FORWARDER:=8.8.8.8}"
: "${RPC_PORT_START:=50000}"
: "${RPC_PORT_END:=50010}"
# Default to allow both nonsecure and secure updates for easier initial client join
: "${DNS_UPDATE_MODE:=nonsecure and secure}" 

# Check if domain is already provisioned
if [ -f /var/lib/samba/private/secrets.keytab ]; then
    echo "Domain already provisioned."
else
    echo "Provisioning domain..."
    # Remove default config to allow provisioning to generate a clean one
    rm -f /etc/samba/smb.conf
    
    # Run provisioning
    samba-tool domain provision 
        --server-role=dc 
        --use-rfc2307 
        --dns-backend=SAMBA_INTERNAL 
        --realm="${REALM}" 
        --domain="${DOMAIN}" 
        --adminpass="${ADMIN_PASS}" 
        --option="dns forwarder = ${DNS_FORWARDER}"

    echo "Configuring smb.conf..."
    # Inject configuration for RPC ports, DNS updates, and LDAP Auth
    # ldap server require strong auth = no -> Allows simple bind (for FreeRADIUS)
    # idmap_ldb:use rfc2307 = yes -> Required for UID/GID mapping (NFS/Linux clients)
    sed -i "/\[global\]/a 

    rpc server port = ${RPC_PORT_START}-${RPC_PORT_END}

    allow dns updates = ${DNS_UPDATE_MODE}

    idmap_ldb:use rfc2307 = yes

    ldap server require strong auth = no

" /etc/samba/smb.conf
fi

echo "Starting Samba AD DC..."
# -i: Interactive (log to stdout)
# --no-process-group: Handle signals correctly in container
exec samba -i --no-process-group

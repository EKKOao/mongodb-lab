#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

mkdir -p /vagrant/secrets/mongodb "${MONGO_TLS_DIR}"
chmod 700 /vagrant/secrets/mongodb

HOST="$(hostname_short)"
IP="$(node_ip)"

if [ "${HOST}" = "cfg1" ] && [ ! -f "${CA_CRT_SHARED}" ]; then
  echo "Generating lab MongoDB CA on cfg1."
  openssl genrsa -out "${CA_KEY_SHARED}" 4096
  openssl req -x509 -new -nodes -key "${CA_KEY_SHARED}" -sha256 -days 3650 \
    -out "${CA_CRT_SHARED}" -subj "/CN=mongodb-lab-ca"
  chmod 600 "${CA_KEY_SHARED}"
  chmod 644 "${CA_CRT_SHARED}"
fi

while [ ! -f "${CA_CRT_SHARED}" ] || [ ! -f "${CA_KEY_SHARED}" ]; do
  echo "Waiting for MongoDB lab CA from cfg1..."
  sleep 2
done

cat > "/tmp/${HOST}-openssl.cnf" <<CNF
[ req ]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = req_ext

[ dn ]
CN = ${HOST}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${HOST}
DNS.2 = ${HOST}.${DOMAIN}
DNS.3 = localhost
IP.1 = ${IP}
IP.2 = 127.0.0.1
CNF

if [ ! -f "${LOCAL_CERT_KEY}" ]; then
  openssl genrsa -out "/tmp/${HOST}.key" 4096
  openssl req -new -key "/tmp/${HOST}.key" -out "/tmp/${HOST}.csr" -config "/tmp/${HOST}-openssl.cnf"
  openssl x509 -req -in "/tmp/${HOST}.csr" \
    -CA "${CA_CRT_SHARED}" -CAkey "${CA_KEY_SHARED}" -CAcreateserial \
    -out "/tmp/${HOST}.crt" -days 825 -sha256 \
    -extensions req_ext -extfile "/tmp/${HOST}-openssl.cnf"

  cat "/tmp/${HOST}.crt" "/tmp/${HOST}.key" > "${LOCAL_CERT_KEY}"
  cp "${CA_CRT_SHARED}" "${LOCAL_CA}"
fi

chown -R "${MONGO_USER}:${MONGO_GROUP}" "${MONGO_TLS_DIR}"
chmod 750 "${MONGO_TLS_DIR}"
chmod 640 "${LOCAL_CA}"
chmod 600 "${LOCAL_CERT_KEY}"

echo "TLS certificate installed for ${HOST} (${IP})."

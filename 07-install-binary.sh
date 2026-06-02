#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

mkdir -p "${MONGO_HOME}" "${MONGO_BIN}"
TMP_DIR="/tmp/mongodb-install"
mkdir -p "${TMP_DIR}"

install_server() {
  if [ -x "${MONGO_BIN}/mongod" ] && "${MONGO_BIN}/mongod" --version | grep -q "v${MONGO_VERSION}"; then
    echo "MongoDB Server ${MONGO_VERSION} already installed."
    return
  fi

  echo "Downloading MongoDB Server tarball: ${MONGO_TARBALL_URL}"
  curl -fL "${MONGO_TARBALL_URL}" -o "${TMP_DIR}/mongodb.tgz"
  rm -rf "${MONGO_HOME}/mongodb-${MONGO_VERSION}" "${MONGO_HOME}/mongodb"
  mkdir -p "${MONGO_HOME}/mongodb-${MONGO_VERSION}"
  tar -xzf "${TMP_DIR}/mongodb.tgz" -C "${MONGO_HOME}/mongodb-${MONGO_VERSION}" --strip-components=1
  ln -sfn "${MONGO_HOME}/mongodb-${MONGO_VERSION}" "${MONGO_HOME}/mongodb"
  ln -sfn "${MONGO_HOME}/mongodb/bin/mongod" "${MONGO_BIN}/mongod"
  ln -sfn "${MONGO_HOME}/mongodb/bin/mongos" "${MONGO_BIN}/mongos"
}

install_mongosh() {
  if [ -x "${MONGO_BIN}/mongosh" ]; then
    echo "mongosh already installed: $(${MONGO_BIN}/mongosh --version || true)"
    return
  fi

  echo "Downloading mongosh tarball: ${MONGOSH_TARBALL_URL}"
  curl -fL "${MONGOSH_TARBALL_URL}" -o "${TMP_DIR}/mongosh.tgz"
  rm -rf "${MONGO_HOME}/mongosh-${MONGOSH_VERSION}" "${MONGO_HOME}/mongosh"
  mkdir -p "${MONGO_HOME}/mongosh-${MONGOSH_VERSION}"
  tar -xzf "${TMP_DIR}/mongosh.tgz" -C "${MONGO_HOME}/mongosh-${MONGOSH_VERSION}" --strip-components=1
  ln -sfn "${MONGO_HOME}/mongosh-${MONGOSH_VERSION}" "${MONGO_HOME}/mongosh"
  # Archive normally contains bin/mongosh.
  ln -sfn "${MONGO_HOME}/mongosh/bin/mongosh" "${MONGO_BIN}/mongosh"
}

install_database_tools() {
  [ "${INSTALL_DATABASE_TOOLS}" = "true" ] || return 0
  if [ -x "${MONGO_BIN}/mongodump" ]; then
    echo "MongoDB Database Tools already installed."
    return
  fi

  echo "Downloading MongoDB Database Tools: ${MONGO_TOOLS_TARBALL_URL}"
  curl -fL "${MONGO_TOOLS_TARBALL_URL}" -o "${TMP_DIR}/mongodb-tools.tgz"
  rm -rf "${MONGO_HOME}/database-tools-${MONGO_TOOLS_VERSION}" "${MONGO_HOME}/database-tools"
  mkdir -p "${MONGO_HOME}/database-tools-${MONGO_TOOLS_VERSION}"
  tar -xzf "${TMP_DIR}/mongodb-tools.tgz" -C "${MONGO_HOME}/database-tools-${MONGO_TOOLS_VERSION}" --strip-components=1
  ln -sfn "${MONGO_HOME}/database-tools-${MONGO_TOOLS_VERSION}" "${MONGO_HOME}/database-tools"
  for b in mongodump mongorestore mongoexport mongoimport mongostat mongotop bsondump mongofiles; do
    [ -x "${MONGO_HOME}/database-tools/bin/${b}" ] && ln -sfn "${MONGO_HOME}/database-tools/bin/${b}" "${MONGO_BIN}/${b}"
  done
}

install_server
install_mongosh
install_database_tools

chown -R "${MONGO_USER}:${MONGO_GROUP}" "${MONGO_HOME}"
chmod -R go-w "${MONGO_HOME}"

"${MONGO_BIN}/mongod" --version | head -n 1
"${MONGO_BIN}/mongos" --version | head -n 1
"${MONGO_BIN}/mongosh" --version

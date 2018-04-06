#!/bin/sh
#


[[ ${DEBUG} ]] && set -x
[[ -f /etc/enviroment ]] && . /etc/enviroment

WORK_DIR="/srv"

MEMCACHE_HOST=${MEMCACHE_HOST:-""}
MEMCACHE_PORT=${MEMCACHE_PORT:-11211}

USE_EXTERNAL_CARBON=${USE_EXTERNAL_CARBON:-false}

CONFIG_FILE="/opt/graphite/webapp/graphite/local_settings.py"

. /init/output.sh

# -------------------------------------------------------------------------------------------------

prepare() {

  log_info "---------------------------------------------------"
  log_info "  graphite ${GRAPHITE_VERSION} (${BUILD_TYPE}) build: ${BUILD_DATE}"
  log_info "---------------------------------------------------"

  [[ -d ${WORK_DIR}/graphite ]] || mkdir -p ${WORK_DIR}/graphite

  sed -i \
    "s|%STORAGE_PATH%|${WORK_DIR}|g" \
    /opt/graphite/conf/carbon.conf

  cp -ar /opt/graphite/storage ${WORK_DIR}/graphite/

  chown -R nginx ${WORK_DIR}/graphite/storage

  [[ -f ${CONFIG_FILE} ]] || cp ${CONFIG_FILE}-DIST ${CONFIG_FILE}

  sed -i \
    -e "s|%STORAGE_PATH%|${WORK_DIR}|g" \
    ${CONFIG_FILE}

  if [[ ! -z ${MEMCACHE_HOST} ]]
  then
    sed -i \
      -e 's|%MEMCACHE_HOST%|'${MEMCACHE_HOST}'|g' \
      -e 's|%MEMCACHE_PORT%|'${MEMCACHE_PORT}'|g' \
      -e 's|# MEMCACHE_HOSTS|MEMCACHE_HOSTS|g' \
      ${CONFIG_FILE}
  fi

  [[ -d /var/log/graphite ]] || mkdir /var/log/graphite
  chown nginx: /var/log/graphite

  [[ -d /var/log/nginx ]] || mkdir /var/log/nginx

  # we will use another carbon service, like go-carbon
  [[ ${USE_EXTERNAL_CARBON} == true ]] && rm -f /etc/supervisor.d/carbon-cache.ini
}


setup() {

  chown -R nginx ${WORK_DIR}/graphite/storage

  PYTHONPATH=/opt/graphite/webapp django-admin.py migrate --verbosity 1 --settings=graphite.settings --noinput
  PYTHONPATH=/opt/graphite/webapp django-admin.py migrate --verbosity 1 --run-syncdb --settings=graphite.settings --noinput
}


start_supervisor() {

  log_info "starting supervisor"

  [[ -f /etc/supervisord.conf ]] && /usr/bin/supervisord -c /etc/supervisord.conf >> /dev/null
}

# -------------------------------------------------------------------------------------------------

run() {

  prepare

  . /init/database.sh

  setup

  start_supervisor
}

run

# EOF

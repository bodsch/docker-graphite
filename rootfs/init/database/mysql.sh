
MYSQL_HOST=${MYSQL_HOST:-""}
MYSQL_PORT=${MYSQL_PORT:-"3306"}
MYSQL_ROOT_USER=${MYSQL_ROOT_USER:-"root"}
MYSQL_ROOT_PASS=${MYSQL_ROOT_PASS:-""}

DATABASE_GRAPHITE_PASS=${DATABASE_GRAPHITE_PASS:-graphite}

if [ -z ${MYSQL_HOST} ]
then
  echo " [i] no MYSQL_HOST set ..."

  return
else
  MYSQL_OPTS="--host=${MYSQL_HOST} --user=${MYSQL_ROOT_USER} --password=${MYSQL_ROOT_PASS} --port=${MYSQL_PORT}"
fi


waitForDatabase() {

  RETRY=15

  # wait for database
  #
  until [ ${RETRY} -le 0 ]
  do
    nc ${MYSQL_HOST} ${MYSQL_PORT} < /dev/null > /dev/null

    [ $? -eq 0 ] && break

    echo " [i] Waiting for database to come up"

    sleep 5s
    RETRY=$(expr ${RETRY} - 1)
  done

  if [ $RETRY -le 0 ]
  then
    echo " [E] Could not connect to Database on ${MYSQL_HOST}:${MYSQL_PORT}"
    exit 1
  fi

  RETRY=10

  # must start initdb and do other jobs well
  #
  until [ ${RETRY} -le 0 ]
  do
    mysql ${MYSQL_OPTS} --execute="select 1 from mysql.user limit 1" > /dev/null

    [ $? -eq 0 ] && break

    echo " [i] wait for the database for her initdb and all other jobs"
    sleep 5s
    RETRY=$(expr ${RETRY} - 1)
  done

}

configureMysql() {

  # check if database already created ...
  #
  query="SELECT TABLE_SCHEMA FROM information_schema.tables WHERE table_schema = \"graphite\" limit 1;"

  status=$(mysql ${MYSQL_OPTS} --batch --execute="${query}")

  if [ $(echo "${status}" | wc -w) -eq 0 ]
  then
    # Database isn't created
    # well, i do my job ...
    #
    echo " [i] Initializing database."

    (
      echo "--- create user 'graphite'@'%' IDENTIFIED BY '${DATABASE_GRAPHITE_PASS}';"
      echo "CREATE DATABASE IF NOT EXISTS graphite;"
      echo "GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE, CREATE VIEW, ALTER, INDEX, EXECUTE ON graphite.* TO 'graphite'@'%' IDENTIFIED BY '${DATABASE_GRAPHITE_PASS}';"
      echo "FLUSH PRIVILEGES;"
    ) | mysql ${MYSQL_OPTS}

    if [ $? -eq 1 ]
    then
      echo " [E] can't create Database 'graphite'"
      exit 1
    fi
  fi

  sed -i \
    -e "s/%DBA_FILE%/graphite/" \
    -e "s/%DBA_ENGINE%/mysql/" \
    -e "s/%DBA_USER%/graphite/" \
    -e "s/%DBA_PASS%/${DATABASE_GRAPHITE_PASS}/" \
    -e "s/%DBA_HOST%/${MYSQL_HOST}/" \
    -e "s/%DBA_PORT%/${MYSQL_PORT}/" \
    ${CONFIG_FILE}

}


waitForDatabase

configureMysql

# EOF

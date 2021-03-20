
DATABASE_TYPE=sqlite

DATABASE_TYPE=${DATABASE_TYPE:-sqlite}

if [[ "${DATABASE_TYPE}" == "sqlite" ]]
then

  log_info "use sqlite backend"
  . /init/database/sqlite.sh

elif [[ "${DATABASE_TYPE}" == "mysql" ]]
then

  log_info "use mysql backend"
  . /init/database/mysql.sh

else
  log_error "unsupported Databasetype '${DATABASE_TYPE}'"
  exit 1
fi

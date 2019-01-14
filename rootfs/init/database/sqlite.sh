
configure_sqlite() {

  storage_directory="${WORK_DIR}/graphite"

  sed -i \
    -e "s|%DBA_FILE%|${storage_directory}/graphite.db|" \
    -e 's|%DBA_ENGINE%|sqlite3|g' \
    -e "s|%DBA_USER%||g" \
    -e "s|%DBA_PASS%||g" \
    -e "s|%DBA_HOST%||g" \
    -e "s|%DBA_PORT%||g" \
    ${CONFIG_FILE}

}

configure_sqlite

# EOF

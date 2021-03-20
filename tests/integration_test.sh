#!/bin/bash

HOST=127.0.0.1
PORT=2003

PUP_VERSION='0.4.0'
PUP_PATH='/var/tmp/bin'
if ! [ -f "${PUP_PATH}/pup" ]
then
  [ -d "${PUP_PATH}" ] || mkdir -p "${PUP_PATH}"
  # Parsing HTML at the command line
  curl \
    --silent \
    --location \
    --output "${PUP_PATH}/pup.zip" \
    "https://github.com/ericchiang/pup/releases/download/v${PUP_VERSION}/pup_v${PUP_VERSION}_linux_amd64.zip"
  unzip "${PUP_PATH}/pup.zip" -d "${PUP_PATH}"
  chmod +x "${PUP_PATH}/pup"
  rm -f "${PUP_PATH}/pup.zip"
fi

#
# Get the current hostname
#
host=$(hostname --short)

#
# The current time - we want all metrics to be reported at the
# same time.
#
time=$(date +%s)


# wait for
#
wait_for_graphite() {

  echo "wait for graphite web"

  # now wait for ssh port
  RETRY=40
  until [[ ${RETRY} -le 0 ]]
  do
    timeout 1 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/8080" 2> /dev/null
    if [ $? -eq 0 ]
    then
      break
    else
      sleep 3s
      RETRY=$(expr ${RETRY} - 1)
    fi
  done

  if [[ $RETRY -le 0 ]]
  then
    echo "could not connect to the graphite instance"
    exit 1
  fi
}


send_request() {

  echo ""

  curl --silent --head localhost:8080

  echo ""

  data=$(curl --silent -u supervisor:supervisor  http://localhost:9001)

  running=$(echo "${data}" | grep -c statusrunning)

  echo -e "${running} processes are running in the container.\n"

  for (( c=0; c<=2; c++ ))
  do
    echo "${data}" | \
      "${PUP_PATH}/pup" 'table tbody json{}' | \
      jq ".[] | {
        \"name\": .children[${c}].children[2].children[0].text,
        \"state\": .children[${c}].children[0].children[0].text,
        \"pid / uptime\": .children[${c}].children[1].children[0].text
      }"

  done

  echo ""
}


# A simple function to send data to a remote host:port address.
#
send() {

  echo "  - '${1}'"

  #
  # If we have nc then send the data, otherwise alert the user.
  #
  if ( command -v nc >/dev/null 2>/dev/null )
  then
    echo "${1}" | nc -w1 "${HOST}" "${PORT}"
    result=${?}

    if [ ${result} -eq 0 ]
    then
      echo "     successful"
    else
      echo "     failed"
    fi
  else
    echo "nc (openbsd-netcat) is not present.  Aborting"
  fi
}


send_metrics() {

  host=$(hostname --short)

  _time() {
    echo $(date +%s)
  }

  echo -e "\nsend some metrics to graphite .."
  echo -e "\n  - classic style"
  # Fork-count
  #
  if [ -e /proc/stat ]; then
    forked=$(awk '/processes/ {print $2}' /proc/stat)
    send "${host}.process.forked ${forked} $(_time)"
  fi

  # Process-count
  #
  if ( command -v ps >/dev/null 2>/dev/null )
  then
    pcount=$(ps -Al | wc -l)
    send "process.count ${pcount} $(_time)"
  fi

  echo -e "\n  - with tags"
  # Fork-count
  #
  if [ -e /proc/stat ]; then
    forked=$(awk '/processes/ {print $2}' /proc/stat)
    send "process.forked;type=qa,server=${host} ${forked} $(_time)"
  fi

  # Process-count
  #
  if ( command -v ps >/dev/null 2>/dev/null )
  then
    pcount=$(ps -Al | wc -l)
    send "process.count;type=qa,server=${host} ${forked} $(_time)"
  fi

}


send_tags() {

  curl \
    --silent\
    --request POST "http://localhost:8080/tags/tagMultiSeries" \
    --data-urlencode 'path=disk.used;rack=a1;datacenter=dc1;server=web01' \
    --data-urlencode 'path=disk.used;rack=a1;datacenter=dc1;server=web02' \
    --data-urlencode 'pretty=1' > /dev/null
}


get_tags() {

  curl \
    --silent \
    "http://localhost:8080/tags?pretty="1
}


add_event() {

  echo -e "\nadd event"
  curl \
    --silent \
    --request POST \
    http://localhost:8080/events -d '{"what": "Something Interesting", "tags" : "tag1"}'

  result=${?}

  if [ ${result} -eq 0 ]
  then
    echo "  successful"
  else
    echo "  failed"
  fi
}

inspect() {

  echo ""
  echo "inspect needed containers"
  for d in $(docker ps | tail -n +2 | awk  '{print($1)}')
  do
    # docker inspect --format "{{lower .Name}}" ${d}
    c=$(docker inspect --format '{{with .State}} {{$.Name}} has pid {{.Pid}} {{end}}' ${d})
    s=$(docker inspect --format '{{json .State.Health }}' ${d} | jq --raw-output .Status)

    printf "%-40s - %s\n"  "${c}" "${s}"
  done

  echo ""
}


#echo "wait 15 seconds for start"
#sleep 15s

if [[ $(docker ps | tail -n +2 | grep -c graphite) -eq 1 ]]
then
  inspect
  wait_for_graphite
  send_request
  send_metrics

  #send_tags
  #get_tags

  add_event

  exit 0
else
  echo "please run "
  echo " make compose-file"
  echo " docker-compose up --build -d"
  echo "before"

  exit 1
fi

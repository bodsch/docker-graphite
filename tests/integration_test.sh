#!/bin/bash

HOST=127.0.0.1
PORT=2003

PUP_VERSION='0.4.0'
PUP_PATH='/usr/local/bin'
if ! [ -x "$(command -v pup)" ]
then
  sudo curl \
    --silent \
    --location \
    --output "${PUP_PATH}/pup.zip" \
    "https://github.com/ericchiang/pup/releases/download/v${PUP_VERSION}/pup_v${PUP_VERSION}_linux_amd64.zip"
  sudo unzip "${PUP_PATH}/pup.zip" -d "${PUP_PATH}"
  sudo chmod +x "${PUP_PATH}/pup"
  sudo rm -f "${PUP_PATH}/pup.zip"
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


###
##
## A simple function to send data to a remote host:port address.
##
###
send() {

#  if [ ! -z "$VERBOSE"  ]; then
    echo "Sending : $1"
#  fi

  #
  # If we have nc then send the data, otherwise alert the user.
  #
  if ( command -v nc >/dev/null 2>/dev/null ); then
    echo "${1}" | nc -w1 "${HOST}" "${PORT}"
    result=${?}

    if [ ${result} -eq 0 ]
    then
      echo "  .. successful"
    else
      echo "  .. failed"
    fi
  else
      echo "nc (netcat) is not present.  Aborting"
  fi
}



send_metrics() {

  ##
  ## Fork-count
  ##
  if [ -e /proc/stat ]; then
      forked=$(awk '/processes/ {print $2}' /proc/stat)
      send "qa.$host.process.forked $forked $time"
  fi


  ##
  ## Process-count
  ##
  if ( command -v ps >/dev/null 2>/dev/null ); then
      pcount=$(ps -Al | wc -l)
      send "qa.$host.process.count  $pcount $time"
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


echo "wait 15 seconds for start"
sleep 15s

if [[ $(docker ps | tail -n +2 | wc -l) -eq 1 ]]
then
  inspect
  wait_for_graphite
  send_request
  send_metrics
  exit 0
else
  echo "please run "
  echo " make compose-file"
  echo " docker-compose up --build -d"
  echo "before"

  exit 1
fi

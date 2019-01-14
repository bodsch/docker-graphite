#!/bin/bash

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

  curl --head localhost:8080
}


inspect() {

  echo "inspect needed containers"
  for d in $(docker ps | tail -n +2 | awk  '{print($1)}')
  do
    docker inspect --format '{{with .State}} {{$.Name}} has pid {{.Pid}} {{end}}' ${d}
  done
}


echo "wait 10 seconds for start"
sleep 10s

if [[ $(docker ps | tail -n +2 | wc -l) -eq 1 ]]
then
  inspect
  wait_for_graphite
  send_request
  exit 0
else
  echo "please run "
  echo " make start"
  echo "before"

  exit 1
fi

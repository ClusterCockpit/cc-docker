#!/bin/bash

x=1
attempts=6

while [ $x -le $attempts ]
do
  echo "Attempt $x to connect to localhost:80/login"
  CODE=$( curl -X GET localhost:80/login --write-out '%{http_code}' --silent --output /dev/null )
  echo "Result HTML Code: $CODE"

  if [ $CODE -eq '200' ]
  then
    echo "... Success!"
    break
	else
    echo "... No response!"
  fi

  if [ $x -lt $attempts ]
  then
    echo "Retrying in 10 seconds."
    sleep 10s
    x=$(( $x + 1 ))
  else
    echo "Could not get response 200 from localhost:80/login !"
    break
  fi

done

if [ $x -lt $attempts ]
then
  exit 0
else
  exit 110
fi

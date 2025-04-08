#!/bin/bash

cd scripts

# Check if required perl modules are installed
if ./checkPerlModules.pl ../migrateTimestamps.pl | grep "couldn't load"; then
  echo "Perl Modules missing!"
  echo -n "Stopped."
  exit
else
  echo "Perl Modules loaded."
fi

# check if golang is installed and available
if ! go version; then
  echo "Golang not installed!"
  echo -n "Stopped."
  exit
else
  echo "Golang installed."
fi

# check if docker is installed and available
if ! docker --version; then
  echo "Docker not installed!"
  echo -n "Stopped."
  exit
else
  echo "Docker installed."
fi

# check if npm is installed and available
if ! npm --version; then
  echo "NPM not installed!"
  echo -n "Stopped."
  exit
else
  echo "NPM installed."
fi

# check if make is installed and available
if ! make --version; then
  echo "Make not installed!"
  echo -n "Stopped."
  exit
else
  echo "Make installed."
fi

# check if gcc is installed and available
if ! gcc --version; then
  echo "GCC not installed!"
  echo -n "Stopped."
  exit
else
  echo "GCC installed."
fi

cd ..

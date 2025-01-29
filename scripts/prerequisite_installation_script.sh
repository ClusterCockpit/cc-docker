#!/bin/bash -l

sudo apt-get update
sudo apt-get upgrade -f -y

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -f -y gcc
sudo apt-get install -f -y npm
sudo apt-get install -f -y make
sudo apt-get install -f -y gh  
sudo apt-get install -f -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 
sudo apt-get install -f -y docker-compose
sudo apt install perl -f -y libdatetime-perl libjson-perl
sudo apt-get install -f -y golang-go

sudo cpan Cpanel::JSON::XS
sudo cpan File::Slurp
sudo cpan Data::Dumper
sudo cpan Time::Piece
sudo cpan Sort::Versions

sudo groupadd docker
sudo usermod -aG docker ubuntu

sudo shutdown -r -t 0



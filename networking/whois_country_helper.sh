#!/bin/bash

# This command takes two input parameters, The first one is the country code we would like to check for 
# and the second one is a file in which we are having the ip addresses or the networks we would like to check.
# As an example if we would like to check a file with networks and print only those of them 
# that aren't registered with CN country, we will include all networks in china_networks.txt
# and run from a bash: ./whois_country_helper.sh CN china_networks.txt

#Retrieve the country code from console input and the file with the network(s)
country=$1
networks_file=$2

while read ip_network 
do
  # Check from whois, regitsered country code
  whois_country=$(whois $ip_network | grep -i country | head -1 | awk '{print $2}')
  # And compare it with the preffered one
  if [[ "$whois_country" != "$1" ]]
  then
    # print the results if country code is different than the checked
    echo $whois_country $ip_network
  fi
done < $networks_file 

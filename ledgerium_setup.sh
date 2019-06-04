#!/bin/bash

cd ../
DIRECTORY="$PWD/ledgeriumtools"

# Check if ledgeriumtools folder exists
    # If yes, go to ledgerium tools
    # Else, clone ledgerium tools repo
if [ -d "$DIRECTORY" ]; then

echo "+-----------------------------------------------------------------------+"    
echo "|***************** Ledgerium tools folder exists ***********************|"

cd ledgeriumtools

else 

echo "+-----------------------------------------------------------------------+"
echo "|**************** Ledgerium tools folder doesn't exist *****************|"
echo "|***************** Cloning ledgerium tools from github *****************|"
echo "+-----------------------------------------------------------------------+"

git clone http://github.com/ledgerium-io/ledgeriumtools &&
cd ledgeriumtools &&

echo "+-----------------------------------------------------------------------+"
echo "|********************** Installing node modules ************************|"
echo "+-----------------------------------------------------------------------+" 

npm install 

fi

echo "|***************** Running ledgerium tools application *****************|"
echo "+----------------------------------------------------------------------+"

# Enter the type of node setup
echo "Enter the type of node setup - full/addon"
read -p 'MODE:' MODE

IP=$(curl -s https://api.ipify.org)
echo $IP

if [ "$MODE" = "full" ]; then

echo "+--------------------------------------------------------------------+"
echo "|***************** Executing script for '$MODE' mode ****************|"

node <<EOF

//Read data
var data = require('./initialparams.json');
var fs = require('fs');

//Manipulate data
data.mode = "$MODE";
data.nodeName = "$(hostname)";
data.domainName = "$(hostname)";
data.externalIPAddress = "$IP"

//Output data
fs.writeFileSync('./initialparams.json',JSON.stringify(data))

EOF

if [ "$1" = "true" ]; then
    echo "Distributed Setup :: True"

    mkdir -p output/tmp         &&
    mkdir -p output/fullnode    &&
    node index.js               &&
    cd output                   &&

    #Read static-nodes.json
    value=$(<tmp/static-nodes.json)
    
    # Convert 'value' to an array
    IFS=',()][' read -r -a array <<<$value

    for index in ${!array[@]}; 
    do
        if [ $index = 0 ]; then
            # Skip 0th element of array
            echo "Skip 0th element of array"
        elif [ $index = 1 ]; then 
            echo "First node will be run in same host"
            docker-compose up -d
        else
            echo "Remaining nodes will be run on remote servers"
            #Split with '@' and take second part
            A="$(echo ${array[$index]} | cut -d'@' -f2)"                                    &&
            #Split with ':' and take first part which is IP Address
            B="$(echo $A | cut -d':' -f1)"                                                  &&

            FOLDER=node_$((index-1))                                                        &&
            mkdir -p $FOLDER/tmp                                                            &&
            cp .env $FOLDER                                                                 &&
            cp fullnode/"docker-compose_$((index-1))_$B.yml" $FOLDER/docker-compose.yml     &&
            cp tmp/genesis.json $FOLDER/tmp                                                 &&
            cp tmp/nodesdetails.json $FOLDER/tmp                                            &&
            cp tmp/privatekeys.json $FOLDER/tmp                                             &&
            cp tmp/static-nodes.json $FOLDER/tmp                                            &&
            echo "*** Enter username for $B ***"                                            &&
            read -p 'Username:' username                                                    &&
            echo "*** Enter password to start scp ***"                                      &&
            scp -r $FOLDER/* $username@$B:~/ledgerium/ledgeriumtools/output
            echo "*** Enter password to start bring up docker containers ***"                 
            ssh $username@$B "cd ~/ledgerium/ledgeriumtools/test && docker-compose up -d" 
        fi
    done
    
else
    echo "Distributed Setup :: False"
    mkdir -p output/tmp &&
    mkdir -p output/fullnode &&
    node index.js &&
    cd output &&
    docker-compose up -d
fi


elif [ "$MODE" = "addon" ]; then
echo "+--------------------------------------------------------------------+"
echo "|***************** Executing script for '$MODE' mode ****************|"

cd ../
LED_NETWORK="$PWD/ledgeriumnetwork"

if [ -d "$LED_NETWORK" ]; then 

echo "|******************** Ledgerium network exists **********************|"
echo "|************ Pulling Ledgerium network from github *****************|"
echo "+--------------------------------------------------------------------+"

cd ledgeriumnetwork &&
git stash &&
git pull -f https://github.com/ledgerium-io/ledgeriumnetwork master &&
cd ../

else

echo "|**************** Ledgerium network deosn't exist *******************|"
echo "|************ Cloning Ledgerium network from github *****************|"
echo "+--------------------------------------------------------------------+"

git clone https://github.com/ledgerium-io/ledgeriumnetwork

fi

cd ledgeriumtools &&
mkdir -p output/tmp &&
echo "$PWD"

node <<EOF
//Read data
var data = require('./initialparams.json');
var fs = require('fs');

var staticNodes = require('../ledgeriumnetwork/static-nodes.json');
var enode = staticNodes[0];
var externalIPAddress = (enode.split('@')[1]).split(':')[0];

//Manipulate data
data.mode = "$MODE";
data.nodeName = "$(hostname)";
data.domainName = "$(hostname)";
data.externalIPAddress = externalIPAddress;

//Output data
fs.writeFileSync('./initialparams.json',JSON.stringify(data))
EOF

node index.js && cp ../ledgeriumnetwork/* ./output/tmp &&
cd output &&
docker-compose up -d

else
echo "Invalid mode"
fi
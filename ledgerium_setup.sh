#!/bin/bash
if [[ "$(docker ps -a | grep ledgeriumengineering)" ]]; then
    echo "There seems to be an existing setup already. Warning: This will a hard reset. You may end up losing ledgerium accounts on your node and other data and additionally, it might take a while before the new node synch up with Ledgerium Blockchain fully. The new node may not be able to write transactions during this period. Do you really want to clean up? "
    read -p "(yes/no) : " CLEANUP

    if [[ $CLEANUP == "yes" ]] || [[ $CLEANUP == "y" ]]; then
        echo "Running cleanup script"
        ./ledgerium_cleanup.sh
        echo "Cleanup is done and now, actual setup is starting"
    elif [[ $CLEANUP == "no" ]] || [[ $CLEANUP == "n" ]]; then
        echo "Running setup without cleanup"
    else
        echo "Invalid input :: $CLEANUP"
    fi
else
    echo "No existing setup. Nothing to clean up"
fi

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

    git clone --single-branch --branch master http://github.com/ledgerium-io/ledgeriumtools &&
    cd ledgeriumtools

    echo "+-----------------------------------------------------------------------+" 
    echo "|********************** Installing node modules ************************|" 
    echo "+-----------------------------------------------------------------------+"  

    npm install 

fi

echo "|***************** Running ledgerium tools application *****************|"
echo "+----------------------------------------------------------------------+"

# Enter the type of node setup
echo "Select the type of node setup - full/blockproducer ('0' for 'blockproducer' and '1' for 'full')"
read -p 'MODE:' MODE

IP=$(curl -s https://api.ipify.org)

if [ $MODE = "0" ]; then
    echo "+--------------------------------------------------------------------+"
    echo "|***************** Executing script for blockproducer mode ****************|"

    # Enter the folder name to pick network files
    echo "Enter the testnet - toorak/flinders ('0' for 'toorak' and '1' for 'flinders')"
    read -p 'TESTNET:' TESTNET

    FLAG=false;
    NETWORK="TOORAK"
    if [ $TESTNET = "0" ]; then
        FLAG=false
        NETWORK="toorak"
    elif [ $TESTNET = "1" ]; then
        FLAG=true
        NETWORK="flinders"
    else 
        echo "Invalid input :: $TESTNET"
        exit
    fi

    cd ../
    LED_NETWORK="$PWD/ledgeriumnetwork"

    if [ -d "$LED_NETWORK" ]; then
        cd ledgeriumnetwork 
    else
        mkdir ledgeriumnetwork
        cd ledgeriumnetwork
    fi
    
    curl -LJO https://raw.githubusercontent.com/ledgerium-io/ledgeriumnetwork/master/$NETWORK/genesis.json
    curl -LJO https://raw.githubusercontent.com/ledgerium-io/ledgeriumnetwork/master/$NETWORK/static-nodes.json

    cd ../ledgeriumtools &&
    mkdir -p output/tmp &&

    node <<EOF
        //Read data
        var data = require('./initialparams.json');
        var fs = require('fs');

        var staticNodes = require('../ledgeriumnetwork/static-nodes.json');
        var genesisInfo = require('../ledgeriumnetwork/genesis.json');
        var enode = staticNodes[0];
        var externalIPAddress = (enode.split('@')[1]).split(':')[0];
        var networkId = genesisInfo.config.chainId;

        //Manipulate data
        data.mode = "blockproducer";
        data.distributed = $FLAG;
        data.env = "testnet";
        data.network = "$NETWORK";
        data.nodeName = "$(hostname)";
        data.domainName = "$(hostname)";
        data.externalIPAddress = externalIPAddress;
        data.networkId = networkId;

        //Output data
        fs.writeFileSync('./initialparams.json',JSON.stringify(data))
EOF
    node index.js

    # $? will be 1 if there is any error
    if [[ $? != 0 ]]; then                   
        echo "Error while running ledgeriumtools" && exit 1
    else 
        cp ../ledgeriumnetwork/genesis.json ../ledgeriumnetwork/static-nodes.json ./output/tmp &&
        cd output &&
        docker-compose up -d
        if [[ $? != 0 ]]; then                   
            echo "Error while bringing up docker containers" && exit 1
        fi 
        echo "Ledgerium Blockchain setup is complete now! The setup file is available in $DIRECTORY/output."
        echo "Summary:"
        echo "  - Existing containers are stopped, and the current ledgeriumtools folder is backed up."
        echo "  - New ledgeriumtools repository is created." 
        echo "  - LedgeriumNetwork folder contains files 'genesis.json' and 'static-nodes.json' files. To know more about these files, please refer https://docs.ledgerium.io/docs/ledgerium-test-networks."
        echo "  - New peer node is set up and added to $NETWORK testnet. You can check the status of the new node on https://$NETWORK.ledgerium.io/."
        echo "  - If you want to join the block producer consortium and write transactions on the blockchain, please contact Ledgerium Foundation team."
    fi


elif [ $MODE = "1" ]; then

    # Enter the type of node setup
    echo "Is this a local setup or distributed? ('0' for local and '1' for distributed)"
    read -p 'Setup:' SETUP

    if [ $SETUP = "1" ]; then

        echo "|***************** Executing script for distributed full mode ****************|"
        
        # Enter Network ID
        ok=0
        while [ $ok = 0 ]
        do
        echo "Enter Network ID"
        echo "Should be a 4 digit number. Ex: 2019"
        read -p 'Network ID:' NETWORKID
        if [[ ! $NETWORKID =~ ^[0-9]{4} ]]
        then
            echo Only numbers and 4 digits
        else
            if [[ ${#NETWORKID} -eq 4 ]]
                then
                ok=1
            else
                echo Length should be 4
            fi
            echo $id
        fi
        done
        
        node <<EOF

            //Read data
            var data = require('./initialparams.json');
            var fs = require('fs');

            //Manipulate data
            data.mode = "full";
            data.distributed = true;
            data.env = "testnet";
            data.network="flinders";
            data.nodeName = "$(hostname)";
            data.domainName = "$(hostname)";
            data.externalIPAddress = "$IP";
            data.networkId = ($NETWORKID == "")? "2018" : $NETWORKID; 

            //Output data
            fs.writeFileSync('./initialparams.json',JSON.stringify(data))

EOF

        # Distributed Setup

        mkdir -p output/tmp         &&
        mkdir -p output/fullnode    &&
        node index.js

        # $? will be 1 if there is any error in nodejs application
        if [[ $? != 0 ]]; then                   
            echo "Error while running ledgeriumtools" && exit 1
        fi
        cd output
        #Read static-nodes.json
        value=$(<tmp/static-nodes.json)
        
        # Convert 'value' to an array
        IFS=',()][' read -r -a array <<<$value

        for index in ${!array[@]}; 
        do
            echo "Remaining nodes will be run on remote servers"
            #Split with '@' and take second part
            A="$(echo ${array[$index]} | cut -d'@' -f2)"                                    
            #Split with ':' and take first part which is IP Address
            B="$(echo $A | cut -d':' -f1)"

            if [ $index = 0 ]; then
                # Skip 0th element of array
                echo "Skip 0th element of array"
            elif [ $index = 1 ]; then 
                echo "First node will be run in same host"
                cp fullnode/"docker-compose_$((index-1)).yml" docker-compose.yml
                docker-compose up -d
                if [[ $? != 0 ]]; then                   
                    echo "Error while bringing up docker containers" && exit 1
                fi
            else
                FOLDER=node_$((index-1))                                                        &&
                mkdir -p $FOLDER/tmp                                                            &&
                cp fullnode/".env$((index-1))" $FOLDER/.env                                                                 &&
                cp fullnode/"docker-compose_$((index-1)).yml" $FOLDER/docker-compose.yml     &&
                cp fullnode/tmp/"privatekeys$((index-1)).json" $FOLDER/tmp/privatekeys.json  &&
                cp tmp/nodesdetails.json tmp/genesis.json tmp/static-nodes.json $FOLDER/tmp                                            &&
                echo "*** Enter username for $B ***"                                            &&
                read -p 'Username:' username                                                    &&
                echo "*** Enter password to create folder structure ***"                        &&
                ssh $username@$B "cd ~/ledgerium/ && mkdir -p ledgeriumtools/output/tmp"        &&
                echo "*** Enter password to start copying files ***"                            &&
                scp -r $FOLDER/* $FOLDER/.env $username@$B:~/ledgerium/ledgeriumtools/output                 &&
                echo "*** Enter password to start bring up docker containers ***"                 
                ssh $username@$B "cd ~/ledgerium/ledgeriumtools/output && docker-compose up -d" 
            fi
        done
        echo "*** Removing files from fullnode ***"
        sudo rm -rf fullnode node_*
        echo "Ledgerium Blockchain setup is complete now! The setup file is available in $DIRECTORY/output."
    elif [ $SETUP = "0" ]; then
        echo "|***************** Executing script for local full mode ****************|"
        # Enter Network ID
                # Enter Network ID
        ok=0
        while [ $ok = 0 ]
        do
        echo "Enter Network ID"
        echo "Should be a 4 digit number. Ex: 2019"
        read -p 'Network ID:' NETWORKID
        if [[ ! $NETWORKID =~ ^[0-9]{4} ]]
        then
            echo Only numbers and 4 digits
        else
            if [[ ${#NETWORKID} -eq 4 ]]
                then
                ok=1
            else
                echo Length should be 4
            fi
            echo $id
        fi
        done
        
        echo "+--------------------------------------------------------------------+"

        node <<EOF

        //Read data
        var data = require('./initialparams.json');
        var fs = require('fs');

        //Manipulate data
        data.mode = "full";
        data.distributed = false;
        data.env = "testnet";
        data.network="toorak";
        data.nodeName = "$(hostname)";
        data.domainName = "$(hostname)";
        data.externalIPAddress = "$IP";
        data.networkId = ($NETWORKID == "")? "2018" : $NETWORKID;

        //Output data
        fs.writeFileSync('./initialparams.json',JSON.stringify(data))

EOF

        # Full mode Setup 
        mkdir -p output/tmp &&
        mkdir -p output/fullnode &&
        node index.js
        # $? will be 1 if there is any error in nodejs application
        if [[ $? != 0 ]]; then                   
            echo "Error while running ledgeriumtools" && exit 1
        fi

        cd output &&
        docker-compose up -d
        if [[ $? != 0 ]]; then                   
            echo "Error while bringing up docker containers" && exit 1
        fi
        echo "Ledgerium Blockchain setup is complete now! The setup file is available in $DIRECTORY/output."
    else 
    echo "Invalid setup value :: $SETUP"
    fi
else
        echo "Invalid mode :: $MODE"
fi

printf -- '\n';
exit 0;

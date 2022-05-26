#!/bin/bash

set -euo pipefail

eval_id=$(echo "$1" | grep -ioP "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}")
deployment_id=$(nomad eval status -json $eval_id | jq -rM '.DeploymentID')

i=0
while [ $i -ne 120 ]; do
    i=$(($i+1))

    echo "-------"
    date
    nomad deployment status -verbose "$deployment_id"
    full_status=$(nomad deployment status -json "$deployment_id")
    echo

    status=$(echo "$full_status" | jq -rM '.Status')
    description=$(echo "$full_status" | jq -rM '.StatusDescription')

    if [ "$status" = "failed" ]; then
        nomad deployment status -verbose "$deployment_id"
        echo "Deployment failed"
        exit 1
    fi
    
    if [ "$status" = "successful" ]; then
        nomad deployment status -verbose "$deployment_id"
        echo "Deployment successful"
        exit 0
    fi

    sleep 5
done

nomad deployment status -verbose "$deployment_id"
echo "Deployment timed out"
exit 1
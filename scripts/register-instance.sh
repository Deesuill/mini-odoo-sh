#!/bin/bash

INSTANCE_NAME=$1
REPOSITORY=$2
PORT=$3

REGISTRY="/opt/mini-odoo-sh/instances.json"


if [ $# -ne 3 ]; then
    echo "Usage: register-instance.sh name repo port"
    exit 1
fi


python3 <<EOF
import json

file="$REGISTRY"

with open(file) as f:
    data=json.load(f)


data["$INSTANCE_NAME"] = {
    "repository": "$REPOSITORY",
    "port": "$PORT"
}


with open(file,"w") as f:
    json.dump(data,f,indent=4)

EOF


echo "Instance registered."


#!/bin/bash

set -e

ACTION=$1
INSTANCE_NAME=$2

BASE_PATH="/opt/mini-odoo-instances"
INSTANCE_PATH="$BASE_PATH/$INSTANCE_NAME"


if [ $# -ne 2 ]; then
    echo "Usage:"
    echo "./manage-instance.sh <start|stop|restart|status> <instance-name>"
    exit 1
fi


if [ ! -d "$INSTANCE_PATH" ]; then
    echo "Instance not found: $INSTANCE_NAME"
    exit 1
fi


cd "$INSTANCE_PATH"


case $ACTION in

    start)
        echo "Starting $INSTANCE_NAME..."
        docker compose up -d
        ;;

    stop)
        echo "Stopping $INSTANCE_NAME..."
        docker compose down
        ;;

    restart)
        echo "Restarting $INSTANCE_NAME..."
        docker compose restart
        ;;

    status)
        echo "Status of $INSTANCE_NAME..."
        docker compose ps
        ;;

    *)
        echo "Unknown action: $ACTION"
        echo "Allowed: start stop restart status"
        exit 1
        ;;

esac

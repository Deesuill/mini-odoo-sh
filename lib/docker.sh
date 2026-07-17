#!/bin/bash

docker_compose_up() {

    docker compose up -d

}

docker_compose_down() {

    docker compose down

}

docker_compose_down_v(){

    docker compose down -v

}

docker_compose_ps() {

    docker compose ps

}

docker_compose_logs() {

    docker compose logs

}

docker_compose_restart() {

    docker compose restart

}

docker_compose_pull() {

    docker compose pull

}

docker_exec() {
    docker exec "$@"
}

docker_compose_ps_json() {
    docker compose ps --format json
}

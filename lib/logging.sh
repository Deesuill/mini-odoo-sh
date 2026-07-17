#!/bin/bash

log_info() {

    echo "[INFO] $1"

}

log_success() {

    echo "[ OK ] $1"

}

log_warning() {

    echo "[WARN] $1"

}

log_error() {

    echo "[FAIL] $1"
    exit 1

}

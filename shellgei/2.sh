#!/bin/bash

set -eu

source 2.libs.sh

SERVICE=$1

download_app $SERVICE
put_app $SERVICE
restart_app $SERVICE
check_error_log $SERVICE

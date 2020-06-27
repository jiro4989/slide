#!/bin/bash

set -eu

download_app() {
  echo unko > "$1"
}

put_app() {
  sudo install -d -o www-data -g www-data -m 0750 "/opt/$1/$(date +%Y-%m-%d)"
  sudo install -o www-data -g www-data -m 0640 "$1" "/opt/$1/$(date +%Y-%m-%d)/$1"
}

restart_app() {
  ln -sfn "/opt/$1/$(date +%Y-%m-%d)/$1" "/opt/$1/current"
  echo "restart $1 ..." >> "/var/log/$1/$1.log"
}

check_error_log() {
  grep "ERROR" "/var/log/$1/$1.log"
}

#!/bin/bash

function download() {
  local app=$1
  local version=$2
  wget https://github.com/jiro4989/nimjson/releases/download/${version}/${app}_linux.tar.gz
}

function deploy() {
  local app=$1
  tar xzf ${app}_linux.tar.gz
  local now=$(date +%Y-%m-%d_%H%M%S)
  sudo install -o www-data -g www-data -m 0700 ${app}_linux /var/www/${app}/${now}
  sudo systemctl stop ${app}
  sudo ln -sfn /var/www/${app}/${today} /var/www/${app}/current
  sudo systemctl start ${app}
}

function check_server() {
  local app=$1
  grep 'Start server' /var/log/${app}/${app}.log
}

# .. その他様々な関数 ..
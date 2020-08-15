#!/bin/bash

set -eu

wget https://github.com/jiro4989/nimjson/releases/download/v1.2.7/nimjson_linux.tar.gz > /dev/null 2>&1
tar xzf nimjson_linux.tar.gz

SECRET_DIR=/var/www/.secrets
sudo mv nimjson_linux/ "$SECRET_DIR"
sudo chmod 0600 "$SECRET_DIR"/*
sudo chown -R www-data:www-data "$SECRET_DIR"
sudo chmod 0700 "$SECRET_DIR"

#!/bin/bash

ssh dev-web-01 "
HOST=$(hostname)
mkdir -p /tmp/work/$HOST
cp /var/log/web/*.log /tmp/work/$HOST
cd /tmp/work
tar czf $HOST.tar.gz ./$HOST
"

#!/bin/bash

wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
ssh dev sudo mkdir -p $HOME/bin
scp thx dev:/tmp/thx
ssh dev sudo install -m 0755 /tmp/thx $HONE/bin/thx

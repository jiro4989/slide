#!/bin/bash

mkdir -p $HOME/bin
wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx '$HOME/bin/thx'
rm thx
echo '== Finish =='

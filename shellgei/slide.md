---
marp: true
theme: uncover
---

# **見落としがちなシェルわかるかな**

@jiro_saburomaru

---

## いきなりですが

以下のシェル、バグがあるのですが分かりますか？

```bash
#!/bin/bash

wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx '$HOME/bin/thx'
```

---

```bash
#!/bin/bash

wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx "$HOME/bin/thx"
```

---

## 目次

1. a

---

```bash
#!/bin/bash

set -eu

source 2.libs.sh

SERVICE=$1

download_app $SERVICE
put_app $SERVICE
restart_app $SERVICE
check_error_log $SERVICE
```

```bash
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
```

---

```bash
#!/bin/bash

wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
ssh dev sudo mkdir -p $HOME/bin
scp thx dev:/tmp/thx
ssh dev sudo install -m 0755 /tmp/thx $HONE/bin/thx
```
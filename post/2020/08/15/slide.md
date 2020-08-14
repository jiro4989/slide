---
marp: false
theme: uncover
---

# **見落としがちなシェルわかるかな**

発表者: 次郎 (@jiro_saburomaru)

---

## いきなりですが

以下のシェル、バグがあるのですが分かりますか？  
あるスクリプトをダウンロードしてきて、所定のパスにコピーするだけのシェルスクリプトです。

```txt
#!/bin/bash

mkdir -p $HOME/bin
wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx '$HOME/bin/thx'
rm thx
echo '== Finish =='
```

---

実は、変数展開がされていないのがバグです。  
ホームディレクトリ配下のbinディレクトリ配下にコピーしたいはずなのに、
`$HOME/bin/thx` というディレクトリの下にスクリプトを配置しようとしています。

分かりましたでしょうか。

```txt
#!/bin/bash

wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx '$HOME/bin/thx' # <-- NG
install -m 0755 thx "$HOME/bin/thx" # <-- OK
rm thx
echo '== Finish =='
```

---

ということで、僕のLTでは  
「一見問題ないけれど、実はバグがあるシェルスクリプト」とその対策についての話をします。

あと今回は飲んでないのでシラフで発表します

---

## 目次

1. 自己紹介
1. 自己紹介
1. 自己紹介
1. 自己紹介

---

## 自己紹介

![jiro4989.png](https://lh4.googleusercontent.com/-j_KBtztsqEc/AAAAAAAAAAI/AAAAAAAAAFE/vBJ2jwo9y30/photo.jpg)

| Key | Value |
| --- | ----- |
| 名前 | 次郎 |
| 職業 | サーバサイドエンジニア |
| おねがい | 勉強会初参加 ＋ 初LTなのでお手柔らかに |

---

## 第1問

一番最初に見せましたが、こちらのシェル。
気づけましたでしょうか。

もし数百行もあるスクリプトの１行だけがこうなっていたら、見落としてしまいそうです。
どうすれば防げたでしょう。

```txt
#!/bin/bash

wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx '$HOME/bin/thx'
echo '== Finish =='
```

---

最初にできる対策は、シンタックスハイライトのあるエディタを使うことです。  
きちんと変数の色を識別してくれるエディタなら、以下のようにおかしいことに気づけます。

```bash
#!/bin/bash

wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx '$HOME/bin/thx' # <-- NG
install -m 0755 thx "$HOME/bin/thx" # <-- OK
echo '== Finish =='
```

---


次にできる対策は、shellcheckを使うことです。  
shellcheckは上記のような変数展開されない記述に対して、警告をだしてくれます。

```bash
TBD
```

---

最後に、スクリプトに `set -eu` を付けます。  
`set -e` はコマンドの終了ステータスが0でない場合にシェルを終了させます。  
`set -u` は未使用の変数を参照しようとしたときにエラーを発生させます。

```bash
#!/bin/bash

set -eu

wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx '$HOME/bin/thx'
echo '== Finish =='
```

`set -eu` をいれても変数がシングルクォート内で展開されるようになったりはしませんが、
`install` コマンドに失敗したことに気づけるようになります。

この例であれば、 `install` に失敗しても、その必ず成功する `echo` コマンドが実行されるため、スクリプト自体は終了ステータス 0 を返します。  
(シェルスクリプトは一番最後に実行されたコマンドの終了ステータスをスクリプト全体の終了ステータスとして返す)

ですが、 `install` に失敗した時点でスクリプトが終了すれば、終了ステータスは 0 以外になります。  
また、最後のスクリプトの完了を表すテキストも出力されなくなるため、異常に早く気付けるようになります。

---

## 第2問

`ssh` コマンドを使うと、リモートサーバに `ssh` で接続できる。  
`ssh` コマンドの引数にコマンドを渡すと、リモートサーバにシェルを送って実行する事もできる。

サーバに直接SSHしてコマンドを実行するのが面倒なので、
サーバ上の環境変数を使って、sshごしにデプロイスクリプトを実行したい。

以下がそのためのスクリプトだが、何が問題だろう？

```bash
#!/bin/bash

ssh zero "env | grep APP_ENV"
# -> prd が表示される

ssh zero "/opt/infra/${APP_ENV}/deploy.sh"
# /opt/infra/{prd,stg,dev} で各環境用のスクリプトが配置されるようになっている
```

---

問題は、 `${APP_ENV}` 変数が空になること。
ダブルクオートでくくられているので、 `${APP_ENV}` 変数はsshでリモートサーバに渡される**前**に変数が展開されてから、ssh先に渡される。

`${APP_ENV}` はローカルPCには設定されていない環境変数のため。空文字になる。

---

ssh先で環境変数を使ってシェルを実行したいなら、今度は逆に**シングルクォート**で変数を囲う必要がある。

使いたい変数が「いつ」評価されてほしいか、によってダブルクオートとシングルクォートを使い分けないといけない。


## 第3問

ある運用作業者が、サーバ上でいつも使っている関数群をまとめたシェルスクリプトがある。
作業者は以下のようにいつもスクリプトをロードして、関数を実行して作業を行っていた。

```bash
source /opt/infra/libs.sh

download app
deploy app
check_server app
```

---

`/opt/infra/libs.sh` の中身は以下。

```bash
#!/bin/bash

function download() {
  local app=$1
  wget https://example.com/release/v1/${app}.tar.gz
}

function deploy() {
  local app=$1
  tar xzf ${app}.tar.gz
  local now=$(date +%Y-%m-%d_%H%M%S)
  sudo install -o www-data -g www-data -m 0700 ${app} /var/www/${app}/${now}
  sudo systemctl stop ${app}
  sudo ln -sfn /var/www/${app}/${today} /var/www/${app}/current
  sudo systemctl start ${app}
}

function check_server() {
  local app=$1
  grep 'Start server' /var/log/${app}/${app}.log
}

# .. その他様々な関数 ..
```

---

ある日、同僚作業者に「スクリプトにはとりあえず `set -eu` 入れとくと良いよ」と言われたので、
`set -eu` を追加した。

安全性が高まって見える。
何が問題でしょう？

```bash
#!/bin/bash

set -eu

function download() {
  local app=$1
  wget https://example.com/release/v1/${app}.tar.gz
}

function deploy() {
  local app=$1
  tar xzf ${app}.tar.gz
  local now=$(date +%Y-%m-%d_%H%M%S)
  sudo install -o www-data -g www-data -m 0700 ${app} /var/www/${app}/${now}
  sudo systemctl stop ${app}
  sudo ln -sfn /var/www/${app}/${today} /var/www/${app}/current
  sudo systemctl start ${app}
}

function check_server() {
  local app=$1
  grep 'Start server' /var/log/${app}/${app}.log
}

# .. その他様々な関数 ..
```

---

実はこれ、 `check_server` 関数を呼び出したタイミングによっては、**関数を実行した瞬間に端末が終了する**。

`grep` は正規表現にマッチする文字が存在しなかった場合、終了ステータスに 1 を返す。

スクリプトを `source` で読み込むと、スクリプト内で定義している `set -eu` が現在のシェルプロセスに適用されてしまい、コマンドの実行結果が 0 以外だったときにプロセスを終了する時限爆弾を抱えることになる。

たとえばログ・ファイルがログローテート直後だったりして、 `Start server` がログファイル内に存在しないタイミングや、サーバの起動に失敗した場合などに、関数を呼んだ瞬間に端末が閉じるという現象が起きる。

---

対策

`source` する前提のスクリプトに `set -eu` を付けない

---

## 第4問

前提条件: developer ユーザとして作業します。

ある秘匿情報を含んだ圧縮ファイルをダウンロードしてきて、
特定ユーザのホームディレクトリ配下の秘密のディレクトリに配置するスクリプトです。

特におかしいところはなさそうです。何が問題でしょう？

```bash
#!/bin/bash

set -eu

wget https://github.com/jiro4989/nimjson/releases/download/v1.2.7/nimjson_linux.tar.gz
tar xzf nimjson_linux.tar.gz

SECRET_DIR=/home/www-data/.secrets
sudo mkdir -p "$SECRET_DIR"

sudo mv nimjson_linux/* "$SECRET_DIR"
sudo chmod 0600 "$SECRET_DIR"/*
sudo chown -R www-data:www-data "$SECRET_DIR"
sudo chmod 0700 "$SECRET_DIR"
```

---

実はこのスクリプト、１回目は成功します。
しかし、もう一度スクリプトを実行すると `chmod 0600` が失敗します。

1回目のスクリプト実行時点で `$SECRET_DIR` の所有者:所有グループは `www-data:www-data` になり、  
ディレクトリの権限は `0600` になりました。これにより、 developer ユーザは `$SECRET_DIR` 配下のファイルを読み込み権限はありません。

この状態だと `$SECRET_DIR` に `cd` することもできませんし、
`chmod` のときに指定している `*` (glob) も展開されなくなっています。

`*` glob によるパス名展開にはディレクトリの読み込み権限が必要です。
1回目の mkdir 直後では読み込み権限があったものの、2回目では読み込み権限が無くなったことにより、
2回目移行はスクリプトの実行が失敗するようになっています。

---

対策

そのスクリプトは何回実行しても成功するかテストをしましょう
可能なら、対象ディレクトリ上でファイルを操作するのではなく、
予め完成形のファイル構造にし、最後に権限を設定したうえで
mv してファイルを配置するようにしたほうがベターだと思います

## 第5問

とある常駐バッチを停止するまでの手順コマンドを作成しました。

見た感じ問題なさそうですが、どこが良くないでしょうか？

```bash
cd /var/app

# appディレクトリは app ユーザが所有者。権限が無いため sudo を使う
sudo echo 1 > stop

# stopファイルを配置すると常駐バッチが安全に停止する。停止するまで確認
tail -f /var/log/app/app.log

# 停止を確認したらデプロイスクリプトを実行
/opt/infra/deploy.sh

# stopファイルが残っていると常駐バッチ起動直後に停止してしまうため削除
sudo rm stop

# 常駐バッチを再開
sudo systemctl start app
```

---

`sudo echo` が失敗します。

リダイレクトでのファイル書き込みは、親ディレクトリに書き込み権限が必要です。
親ディレクトリに書き込み権限がない場合、 `sudo` をつけてrootユーザとして実行しようとしても失敗します。

---

対策

リダイレクトが問題なので `tee` などコマンドの機能でファイルを生成して書き込むようにすればOK。

---

## まとめ

たった5問でしたが、何問わかったでしょうか？

- 変数の展開のされ方
- sourceとsetオプションの適用範囲
- globと権限
- リダイレクトと権限

について話しました。

特に権限周りが絡んでくると、普段何気なく使っているシェルが動かなくなったりシます。
事前にきちんとテストした上でスクリプトを実行しましょう。

また、shellcheckやshfmtなどで、スクリプトの品質を高めることで、
コードレビュー時点で検出できるようにするのも、なお良いと思います。

デプロイ用途として、Ansibleなどのプロビジョニングツールを使うのもベターだと思います。

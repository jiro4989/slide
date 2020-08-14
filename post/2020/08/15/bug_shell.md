---
marp: false
theme: default
---

# **見落としがちなシェルわかるかな**

発表者: 次郎 (@jiro_saburomaru)

---

## いきなりですが

以下のシェル、バグがあるのですが、分かりますか？  
あるスクリプトをダウンロードしてきて、  
所定のパスにコピーするだけのシェルスクリプトです。

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

mkdir -p $HOME/bin
wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx '$HOME/bin/thx' # <-- NG
install -m 0755 thx "$HOME/bin/thx" # <-- OK
rm thx
echo '== Finish =='
```

---

ということで、僕のLTでは  
「一見問題ないけれど、実はバグがあるシェルスクリプト」の解説と、  
その対策について話します。

話すスクリプトについては多少改変していますが、  
いずれも実際に僕がやらかした実例をもとにしています。

僕と同じミスをする人が減ってくれれば良いな、と思って話します。

---

## 目次

1. 自己紹介
1. 自己紹介
1. 自己紹介
1. 自己紹介

---

## 自己紹介

![jiro4989.png](https://gyazo.com/364f369f7714b4e7fb2a6ed1ce5b58de/thumb/1000)

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

mkdir -p $HOME/bin
wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx '$HOME/bin/thx'
rm thx
echo '== Finish =='
```

---

## 第1問 対策

最初にできる対策は、シンタックスハイライトのあるエディタを使うことです。  
きちんと変数の色を識別してくれるエディタなら、以下のようにおかしいことに気づけます。

```bash
#!/bin/bash

mkdir -p $HOME/bin
wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx '$HOME/bin/thx' # <-- NG
install -m 0755 thx "$HOME/bin/thx" # <-- OK
rm thx
echo '== Finish =='
```

---

次にできる対策は、 [shellcheck](https://github.com/koalaman/shellcheck) を使うことです。  
`shellcheck` は前述の展開されない変数に対して、警告をだしてくれます。

```log
⟩ shellcheck q1.sh

In q1.sh line 3:
mkdir -p $HOME/bin
         ^---^ SC2086: Double quote to prevent globbing and word splitting.

Did you mean:
mkdir -p "$HOME"/bin


In q1.sh line 5:
install -m 0755 thx '$HOME/bin/thx'
                    ^-------------^ SC2016: Expressions don't expand in single quotes, use double quotes for that.

For more information:
  https://www.shellcheck.net/wiki/SC2016 -- Expressions don't expand in singl...
  https://www.shellcheck.net/wiki/SC2086 -- Double quote to prevent globbing ...
```

---

最後に、スクリプトに `set -eu` を付けます。  
`set -e` はコマンドの終了ステータスが0でない場合にシェルを終了させます。  
`set -u` は未使用の変数を参照しようとしたときにエラーを発生させます。

```bash
#!/bin/bash

set -eu

mkdir -p $HOME/bin
wget https://raw.githubusercontent.com/jiro4989/scripts/master/bin/thx
install -m 0755 thx "$HOME/bin/thx"
rm thx
echo '== Finish =='
```

※詳細は `man set` を参照

---

`set -eu` を入れることで、
`install` コマンドに失敗したことに気づけるようになります。

この例であれば、 `install` に失敗しても、その直後に必ず成功する `echo` コマンドが実行されるため、スクリプト自体は終了ステータス 0 を返します。

(シェルスクリプトは一番最後に実行されたコマンドの終了ステータスをスクリプト全体の終了ステータスとして返す)

ですが、 `install` に失敗した時点でスクリプトが終了すれば、終了ステータスは 0 以外になります。

また、最後のスクリプトの完了を表すテキストも出力されなくなるため、異常に早く気付けるようになります。

---

## 第2問

以下はリモートのサーバ上のログを圧縮してscpで取得するスクリプトです。  

リモートサーバのホスト名を圧縮ファイル名に使うことで、サーバ台数が増えたときに対応できるようになっています。

sshコマンドごしにスクリプトを送信しています。

何が問題でしょう？

```bash
#!/bin/bash

ssh dev-web-01 "
HOST=$(hostname)
mkdir -p /tmp/work/$HOST
cp /var/log/web/*.log /tmp/work/$HOST
cd /tmp/work
tar czf $HOST.tar.gz ./$HOST
"
scp dev-web-01:/tmp/work/*.tar.gz .
```

---

実はこのスクリプト、 **`$HOST` が空文字として展開されています**。 

ダブルクオートでくくられているので、 `$HOST` 変数はリモートサーバにスクリプトが渡される**前**に変数が展開されてから、ssh先にスクリプトが送信されています。

`$HOST` はローカルPCには設定されていない環境変数のため。空文字になります。

あと`$(hostname)`もローカルPCの実行結果がHOSTにセットされているため、仮にきちんと評価されても、圧縮ファイル名が全部ローカルPCのホスト名になります。

---

## 第2問 対策

ssh先で変数を使ってシェルを実行したいなら、今度は逆に**シングルクォート**で変数を囲う必要があります。

使いたい変数が「いつ」評価されてほしいか、によってダブルクオートとシングルクォートを使い分ける必要があります。

```bash
#!/bin/bash

ssh dev-web-01 '
HOST=$(hostname)
mkdir -p /tmp/work/$HOST
cp /var/log/web/*.log /tmp/work/$HOST
cd /tmp/work
tar czf $HOST.tar.gz ./$HOST
'
scp dev-web-01:/tmp/work/*.tar.gz .
```

---

また、これも`shellcheck`で検出できます。  
`shellcheck`にかけておくことも、問題を早期に発見できます。

```log
$ shellcheck q2.sh

In q2.sh line 4:
HOST=$(hostname)
     ^---------^ SC2029: Note that, unescaped, this expands on the client side.

For more information:
  https://www.shellcheck.net/wiki/SC2029 -- Note that, unescaped, this expand...
```

---

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

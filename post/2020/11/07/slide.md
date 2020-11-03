---
marp: true
theme: default
---

# GitHub Releasesからインストールしたコマンドをバージョン管理する

発表者: 次郎 (@jiro_saburomaru)

---

## 目次

1. 自己紹介
1. GitHub Releasesについて
1. 既存のパッケージ
1. relmaで解決
1. relmaの使い方
1. まとめ

---

## 自己紹介

![jiro4989.png](https://gyazo.com/364f369f7714b4e7fb2a6ed1ce5b58de/thumb/1000)

| Key | Value |
| --- | ----- |
| 名前 | 次郎 |
| 職業 | サーバサイドエンジニア |
| おねがい | 勉強会初参加 ＋ 初LTなのでお手柔らかに |

---

## GitHub Releasesについて

皆様はGitHub Releasesを使ってますか？

GitHub Releases便利なので、次郎は大変活用させてもらっています。

GitHub Releasesは開発者にとっても、リポジトリを訪れた人(以降ユーザと記載)にとっても
手軽に使える素晴らしい機能だと感じています。

---

GitHub Releasesご存知ない方のために軽く説明すると

- GitHubのリポジトリに紐づく、任意のファイルをユーザに提供できる機能
    - [リポジトリのリリースを管理する - GitHub Docs](https://docs.github.com/ja/free-pro-team@latest/github/administering-a-repository/managing-releases-in-a-repository)
- リポジトリのタグと紐付いていて、「タグを付与された時点でのリリース物」として利用される場合がほとんど
    - 例: タグ `v1.0.1` のリリース物
- 各OS用の実行可能ファイルや、コードから生成したフォントファイルといったのアセットファイルなどを圧縮して公開してるケースが多い(と思う)

---

参考までに、僕が利用しているGitHub Releasesの画面

![参考画像](./ss_nimjson.png)

---

### なにが便利か

開発者

- 無料で使える
- リリースファイルのアップロードが容易
- CI (GitHub Actions, Travis CIなど)と連携して自動リリース可能

ユーザ

- 無料で使える
- 簡単にダウンロードできる

---

次郎は主にGitHub Releasesにだけ公開されているコマンドのダウンロードに使っています

有名なコマンドなどは `apt install` できたりするものもありますが、
GitHub Releasesだけに公開されているコマンドも多いです。

---

### 管理に悩む

こういったGitHub Releasesから取得するタイプのコマンドをインストールする時、僕は以下のようなコマンドを実行します。

```bash
cd /tmp
wget https://github.com/jiro4989/nimjson/releases/download/v1.2.8/nimjson_linux.tar.gz
tar xzf nimjson_linux.tar.gz
mkdir -p ~/bin
install -m 0755 ./nimjson_linux/bin/nimjson ~/bin/
```

インストールする時は特にこれで不便ありません。

---

ですが、コマンドをアップグレードしたくなった時に困りました。
主に以下の問題に遭遇しました。

- このコマンドどこから取得したっけ？
- どうやってインストールしたっけ？
- そもそも新しいバージョン出てるんだっけ？

この問題はGitHub Releasesから取得するコマンドが増えるほど大きくなりました

---

「debianパッケージみたいに `apt install` でインストールできて、
 `apt update` して `apt upgrade` でバージョン更新できたらいいのになぁ...」と感じるようになりました。

 GitHub Releasesはタグに紐づくリリース物を公開する機能であって、
 リリース物をユーザがどう管理するかについては責務外と思います。

僕の「debianパッケージみたいに管理したい」がそもそも責務外の無茶な要求というものです。

---

ということで、作りました。

GitHub Releasesでインストールしたコマンドの一括アップグレードを可能にするコマンドです。

名前は `relma` としました。

https://github.com/jiro4989/relma

---

## relma の使い方

最初に `init` で初期化して、 `install` にリリース物のURLを渡してあげるだけです。

これでリリース物の圧縮ファイルを展開して `$HOME/relma/bin` に実行可能ファイルのシンボリックリンクが配置されます。

```bash
relma init
relma install https://github.com/jiro4989/nimjson/releases/download/v1.2.8/nimjson_linux.tar.gz
```

---

### アップグレード方法

以下の様に `update` して `upgrade` するだけです。

`update` では最新バージョンの有無をチェックし、バージョン情報をローカルに保存します。
`upgrade` を実行するとアップグレード可能なパッケージをすべてアップグレードします。

```bash
relma update
relma upgrade
```

---

### パッケージの確認

relma でインストールしたパッケージの一覧を確認する場合は `list` を実行します。

```bash
relma list
```

---

## relma の仕組み

GitHub Releasesで公開されているコマンドの多くは、リリース手順を自動化されています。

ローカルで手動で叩くコマンドか、あるいはCIからか、手段は違えど大なり小なり自動化されている場合が多いです。

また、リリースファイルの命名も、リポジトリごとに違えど、概ね命名が決まっていて、「リリースファイル名に含まれるバージョン番号がリリースごとに異なる以外は同じ」という点で共通点があります。

---

よって、 `relma install` に指定したURLのバージョン番号をリリースのタグ番号で差し替えれば、次のバージョンのリリースファイルを取得するURLが特定できるのでは、と考えました。

```bash
https://github.com/jiro4989/nimjson/releases/download/${VERSION}/nimjson_${VERSION}_linux.tar.gz
```

開発者が毎回手動でリリースファイルを作っていて、命名が不規則だったり、タグとバージョン番号が不一致になるケースもあると思いますが、対象外にしました。

あらゆるリポジトリをサポートするつもりはないですし、命名が不規則なのはリポジトリのオーナーの問題と考えます。

8割くらいのリポジトリをカバーできれば、次郎は満足です。

---

また、リリースファイルを展開した後のディレクトリ構造も概ね同じ構造をしていると考えました。

なので、展開後のディレクトリ構造を判別して実行可能ファイルのパスを特定できればインストール処理も自動化できると考えました。

```
release_v1.0.0.zip/
    command.exe

release_v1.0.0.zip/
    release_v1.0.0/
        command.exe

release_v1.0.0.zip/
    release_v1.0.0/
        bin/
            command.exe
```

---

また、リリースファイルも `tar.gz` だったり `zip` だったりします。

圧縮ファイルの種類の違いも relma が判別して展開するようにしています。

なので、relmaを使う時は `install` コマンドの引数にURLを渡すだけで動作します。

---

（ここで実際に操作）

---

## まとめ

- GitHub Releasesの話をしました
- relma コマンドの使い方を説明しました
- relma コマンドの仕組みを説明しました

皆様のお役に立てば幸いです。

以上
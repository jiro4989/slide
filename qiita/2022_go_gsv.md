# csvをgrepできるようにするコマンドを作った

## 経緯

CSVのセルには改行文字が含まれ得ます。
改行文字の含まれるCSVをgrepすると、CSVのセルが壊れます。

具体的には、以下のようなCSVをgrepすると壊れます。

```bash
$ cat a.csv
head1,head2,head3
"a","foo
bar","sushi"
"b","test","test"

$ grep bar a.csv
bar","sushi"
```

grepで検索した文字列にマッチする行を抽出しつつ、
CSVフォーマットとして壊れないようにgrepしたかったわけです。

CSVを検索するツールとかは探せばあるんですけれど、grepの検索機能をそのまま使いたい。
かといって自分でgrepと同等の検索処理を実装するのは難しい。
ということで、grepに食わせる橋渡しをするツールを作りました。

## 成果物

gsv というコマンドです。

https://github.com/jiro4989/gsv

これは[gron](https://github.com/tomnomnom/gron)というコマンドのアイデアを参考にしました。

gsvに対してCSVを食わせると、改行文字が含まれるセルを1行の文字列に変換して出力します。
この文字列をgrepで検索し、再度gsvに噛ませることでCSVに復元します。

## 使い方

以下のように使います。

```bash
$ gsv a.csv

$ gsv a.csv | grep foo

$ gsv a.csv | grep foo | gsv -u
```

## 実装

TODO

## まとめ

以下の話をしました。

1. TODO

以上。

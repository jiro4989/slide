---
marp: true
theme: default
---
# PEGで構文解析をする

発表者: 次郎 (@jiro_saburomaru)

あるツールをリファクタするときにPEGが便利だった話をします。

---

## 自己紹介

![jiro4989.png](https://gyazo.com/364f369f7714b4e7fb2a6ed1ce5b58de/thumb/1000)

| Key | Value |
| --- | ----- |
| 名前 | 次郎 |
| Twitter | [@jiro_saburomaru](https://twitter.com/jiro_saburomaru) |
| 職業 | SRE |

---

## 目次

1. PEG (Parsing Expression Grammar)
1. PEGの嬉しさ
1. PEGの使い所
1. 感想
1. まとめ

---

## PEG (Parsing Expression Grammar)

---

ざっくり言うと「構文解析をするための文法」。実装からは独立している。
類似の技術としてはYACCが該当する。

> Parsing Expression Grammar (PEG) は、分析的形式文法の一種であり、形式言語をその言語に含まれる文字列を認識するための一連の規則を使って表したものである。

引用: [Parsing Expression Grammar - Wikipedia](https://ja.wikipedia.org/wiki/Parsing_Expression_Grammar)

---

PEGにはパーサジェネレータが存在し、PEGの文法を食わせることで、その文法を解釈できるパーサを自動生成できる。

PEGのパーサジェネレータはすでに多数存在しており、様々なプログラミング言語用のジェネレーターが存在する。

今回のLTではGo言語用のパーサジェネレータの[pointlander/peg - GitHub](https://github.com/pointlander/peg)を使う。

---

例えば、PEGの文法に則って、以下のルールを定義した。
これは簡易な ini ファイル風の設定ファイル文法である。

```peg
root      <- pair+

pair      <- space key space '=' space value space delimiter

key       <- [a-zA-Z] [-_a-zA-Z0-9]*
value     <- atom

atom      <- bool / int / string
string    <- '"' ('\\' '"' / [^"])* '"'
int       <- '0' / [1-9] [0-9]*
bool      <- 'true' / 'false'

space     <- (' ' / '　' / '\t')*
delimiter <- '\n' / ';'
```

---

前述のルールでは、以下のテキストを解釈できる。

```ini
name = "test_app"
port = 1234
debug = true
```

ただし、前述のルールだけでは、構文を解析できるだけで、値を取り出すことができない。
そこで、今回使うGo用のパーサジェネレータの独自の構文を使うことで値を取り出す。

---

peg独自の構文を付け足したものが以下。

```peg
package main

type Parser Peg {
  ParserFunc
}

root      <- pair+

pair      <- space key space '=' space value space delimiter

key       <- <[a-zA-Z] [-_a-zA-Z0-9]*>    { p.pushKey(text) }
value     <- atom

atom      <- bool / int / string
string    <- '"' <('\\' '"' / [^"])*> '"' { p.pushString(text) }
int       <- <'0' / [1-9] [0-9]*>         { p.pushInt(text) }
bool      <- <'true' / 'false'>           { p.pushBool(text) }

space     <- (' ' / '　' / '\t')*
delimiter <- '\n' / ';'
```

---

これで構文解析と、値の取り出しをまとめてできるようになった。

コンパイラで言う字句解析と構文解析を一緒にやっている。意味解析はできない。

実際に設定ファイルを読み込んで、値が取り出せているか確認してみる。

---

確認用のコードが以下。

```go
func main() {
	b, err := os.ReadFile("sample.conf")
	if err != nil {
		panic(err)
	}

	pf := ParserFunc{
		data: make(map[string]interface{}),
	}
	p := &Parser{
		Buffer: string(b),
		ParserFunc: pf,
	}
	if err := p.Init(); err != nil {
		panic(err)
	}
	if err := p.Parse(); err != nil {
		panic(err)
	}
	p.Execute()
	for k, v := range p.ParserFunc.data {
		fmt.Printf("key = %s, value = %v, type = %s\n", k, v, reflect.TypeOf(v))
	}
}
```

---

実行結果は以下のようになる。期待通り、KeyとValueと型情報が取り出せている。

```bash
⟩ cat sample.conf
name = "test_app"
port = 1234
debug = true

⟩ ./configfile
key = port, value = 1234, type = int
key = debug, value = true, type = bool
key = name, value = test_app, type = string
```

---

ここまでで使ったサンプルコードはすべて以下のGistにまとめている。

気になった方は参考にしてみてください。

https://gist.github.com/jiro4989/668bd841e484eda7959bc027fb891da0

![qrcode](./peg_sample_qrcode.png)

---

## PEGの嬉しさ

---

PEGを使う場合は文法を書くだけで良い。

コードの実装はジェネレーターに任せられるため、実装コストが安くなる。

また、PEGの文法を読むだけで、どのような文法を解釈できるのかが一意に判断できるため、可読性も高い。

---

PEGを使わない場合は、自力でLexer(字句解析器)とParser(構文解析器)を実装する必要がある。

自分でやるにはなかなか大変。

---

## PEGの使い所

---

PEGが構文解析に有用であることを今まで話した。

とはいえ、「別にプログラミング言語や設定ファイルを自作することなんてそうそうないし、使い所は限られているのでは？」と思うかもしれない。

---

しかし、そんなことはない。

シェル芸人なら日常的に目にしているであろう、**アレ**を解析するのにPEGは役立つ。

---

しかし、そんなことはない。

シェル芸人なら日常的に目にしているであろう、**アレ**を解析するのにPEGは役立つ。

そう、 **ANSIエスケープシーケンス** である。

textimg というコマンドのANSIエスケープシーケンスの処理部分を PEG を使って実装してみた話をします。
（ここから本題）

---

textimg とANSIエスケープシーケンスに関する話は、2019年8月の第43回シェル芸勉強会のLTで発表した。気になる方は以下の資料を見てほしい。

[ANSIエスケープシーケンスで遊ぶ - /home/jiro4989](https://scrapbox.io/jiro4989/ANSI%E3%82%A8%E3%82%B9%E3%82%B1%E3%83%BC%E3%83%97%E3%82%B7%E3%83%BC%E3%82%B1%E3%83%B3%E3%82%B9%E3%81%A7%E9%81%8A%E3%81%B6)

![ANSI_LT](./ansi_qrcode.png)

---

まず、ANSIエスケープシーケンスの定義は man にかかれている。

`man console_codes`

https://man7.org/linux/man-pages/man4/console_codes.4.html

---

ANSIエスケープシーケンスは別に端末上の表示制御だけ行うわけではない。

Beep音を鳴らしたり、端末上のカーソルを移動したり、いろんな事ができる。

定義上はANSIエスケープシーケンスのうち、グラフィック制御を行うものは **SGR (Select Graphic Rendition)** と呼ぶ。

textimg はこの SGR の解釈だけを実装している。

---

SGR の文法は `ESC [ parameters m` となっている。

> The ECMA-48 SGR sequence ESC [ parameters m sets display attributes.  Several attributes can be set in the same sequence, separated by semicolons.  An empty parameter (between semicolons or string initiator or terminator) is interpreted as a zero.

> ECMA-48 SGR シーケンス ESC [ parameters m は、表示属性を設定する。 同じシーケンスで、セミコロンで区切って複数の属性を設定することができる。 空のパラメータ（セミコロンまたは文字列のイニシエータまたはターミネータの間）は0と解釈されます。

---

つまりは parameters 部分は可変長であるので、もう少し細かく文法を書くと以下のようになる。

```text
ESC [ parameter (;parameter)* m
```

これをPEGで表現してみる。

---

まず最初に基本形。parametersが 30~37、40~47、90~97、100~107 を解釈する。
1の位が8の場合は更に追加でパースが必要になるが、ここでは省略。

prefix color suffix という3部分で構成。
これで `ESC[31m` (前景色が赤)が解釈できるようになった。

```peg
colors <-
  prefix color suffix

prefix <-
  '\e' '['

color <-
  ([349] / '10') [0-7]

suffix <- 'm'
```

---

次に、セミコロン区切りで複数のparameterを指定できるようにする。
区切り文字 delimiter を定義し、0個以上の定義を追加した。

これで `ESC[31;42m` (前景色が赤、背景色が緑)が解釈できるようになった。

```peg
colors <-
  prefix color (delimiter color)* suffix

prefix <-
  '\e' '['

color <-
  ([349] / '10') [0-7]

suffix    <- 'm'
delimiter <- ';'
```

---

これだけだと SGR しか解釈できないため、テキストも解釈できるようにする。
ESC 以外のすべての文字を text として解釈することとした。

これで最低限の SGR が含まれるテキストを解釈できる文法が整った。

```peg
root <- (colors / text)*

colors <-
  prefix color (delimiter color)* suffix

prefix <-
  '\e' '['

color <-
  ([349] / '10') [0-7]

text <- [^\e]+

suffix    <- 'm'
delimiter <- ';'
```

---

不完全な SGR や、SGR以外のANSIエスケープシーケンスが混在していた時にパースに失敗する。

無視する文字列なども解釈できるようにする必要があるが、今回は割愛。


---

こんな具合に文法を徐々に拡張していって、最終的な文法は以下のようになった。

行数だけで見ると70行程度しかない。

https://github.com/jiro4989/textimg/blob/master/parser/grammer.peg

---

## 感想

---

PEGを書くだけでパーサーが生成されるので実装コストがとても軽いことがわかった。

しかしながら、生成されたコードを見てみると分かるが、非常に巨大なソースコードが生成される。

```bash
⟩ wc -l parser/grammer.peg.go
1300 parser/grammer.peg.go
```

SGR のパーサを作るにはややオーバースペックな印象がある。

逆に、複雑な構文や、構文が今後複雑になる可能性があるなら PEG でパーサーを自動生成するのは便利そう。

---

## まとめ

以下の話をしました。

1. PEG を使うと可読性が高く、複雑な構文解析を低コストで実装できる
1. PEG をANSIエスケープシーケンスの SGR の構文解析に使ってみたら良かった
1. PEG は簡単な構文の解析にはややオーバースペックそうだけれど、構文が今後どう変化するか見えない場合には強力そう

以上

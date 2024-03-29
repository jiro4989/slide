# grepでの検索結果の前後行を後付け検索できるコマンドを作った

この記事は2022Rustアドベントカレンダー2の7日目の記事です。

Rustの勉強がてら、grepの検索結果の続きを表示するコマンドを作ってみました。

## 経緯

表題の通り、grepの検索結果の続きが表示したくなったからです。

例えば、ログファイルの調査をする場合です。
一連のトランザクションのログとして、beginで始まり、endで終了するログファイルが存在するとします。

```log
2022/01/01T01:00:00 a12b1cfefa2a37a89fe73 begin
2022/01/01T01:00:01 a12b1cfefa2a37a89fe73 foobar1
2022/01/01T01:00:01 a12b1cfefa2a37a89fe73 foobar2
2022/01/01T01:00:02 a12b1cfefa2a37a89fe73 foobar3
2022/01/01T01:00:03 a12b1cfefa2a37a89fe73 end
```

このログファイルに対して end という文字列で検索をします。
すると標準出力は以下のようになります。

```log
$ grep end a.log
2022/01/01T01:00:03 a12b1cfefa2a37a89fe73 end
```

この検索結果に対して、1行前の行を表示したくなりました。

今回のケースで言うと、別にgrepだけでも目的を達成できます。
以下のようにします。

```bash
$ grep -B 1 end a.log
2022/01/01T01:00:02 a12b1cfefa2a37a89fe73 foobar3
2022/01/01T01:00:03 a12b1cfefa2a37a89fe73 end

$ grep -B 1 end a.log | grep foobar3
2022/01/01T01:00:02 a12b1cfefa2a37a89fe73 foobar3
```

この程度のケースであれば、わざわざ専用コマンドを作る必要はありません。
しかしながら、コマンドをパイプで繋いで複数の条件で検索を繰り返した結果に対して、その前後の行を表示したくなったときに、
grep にオプションを付け足すのはめんどくさいです。
検索結果に対してコマンドをあとづけするだけで、その前後の行を表示できるようなソリューションが欲しくなります。

探したけれど、この目的を満たしたコマンドはなさそうだったので、自作しました。

## 成果物

suln というコマンドです。

https://github.com/jiro4989/suln

## 使い方

まず、grepを呼ぶときに、最初の1つだけ `-nH` を付けておきます。
そしてgrepの検索結果に対してsulnをパイプでつなぐだけです。

```bash
grep -nH '<pattern>' '<file>' | suln <-B NUM | -A NUM | -C NUM>
```

前述のログファイルに対して同様の結果を得る場合は、以下のように実行します。

```bash
⟩ grep -nH end a.log
a.log:5:2022/01/01T01:00:03 a12b1cfefa2a37a89fe73 end

/tmp/work
⟩ grep -nH end a.log | suln -B 1
a.log:4:2022/01/01T01:00:02 a12b1cfefa2a37a89fe73 foobar3
a.log:5:2022/01/01T01:00:03 a12b1cfefa2a37a89fe73 end

/tmp/work
⟩ grep -nH end a.log | suln -B 1 | grep foobar3
a.log:4:2022/01/01T01:00:02 a12b1cfefa2a37a89fe73 foobar3
```

最終的に実行しているコマンドの数は増えてしまっていますが、
前のコマンドに戻る必要はなくなりました。

使用可能なオプションは、grepのオプションと同じにしています。
それぞれ以下のオプションが使用可能です。

* `-B` 前の行
* `-A` 後ろの行
* `-C` 前後の行

## 実装

`grep -nH` で付与されるファイル名と行番号を元に、
grepの結果の前後の行を標準出力に書き出しているだけです。
ただし、少しだけ気を使っている部分があります。
それは、ファイル名部分のパース方法です。

grepのファイル名と行番号とファイルの中身を標準出力に書き出す時の書式は以下のようになっています。

```
＜ファイル名＞:＜行番号＞:＜ファイルの中身＞
または
＜ファイル名＞-＜行番号＞-＜ファイルの中身＞
```

つまり、コロン区切りか、ハイフン区切りになっています。
この時、ハイフン区切りのファイル名のパースが非常に悩ましかったです。

コロンは比較的ファイル名には出現しないのですが、ハイフンはファイル名に頻出です。
単純に `-＜行番号＞-` が出現する部分までで取り出したりすると、
誤った部分でファイル名を切り出してしまう可能性がありました。

そこで、正規表現で行文字列の先頭からテキストを切り出して、
その部分が実際にファイルとして存在するかチェックするのを繰り返すようにしました。
そして、最初に存在するファイルが見つかった時点で、切り出しを辞めるというロジックにしました。

```rust
use std::path::Path;

use lazy_static::lazy_static;
use regex::Regex;

lazy_static! {
    static ref HYPHEN_LINE_NUMBER: Regex = Regex::new(r"-(\d+)-").unwrap();
    static ref COLON_LINE_NUMBER: Regex = Regex::new(r":(\d+):").unwrap();
}

#[derive(Debug, PartialEq)]
pub struct FileLine {
    pub file_name: String,
    pub line_num: u64,
}

pub fn parse(text: &String) -> Option<FileLine> {
    if let Some(_) = COLON_LINE_NUMBER.find(text) {
        return _parse(&COLON_LINE_NUMBER, text);
    }
    if let Some(_) = HYPHEN_LINE_NUMBER.find(text) {
        return _parse(&HYPHEN_LINE_NUMBER, text);
    }
    None
}

fn _parse(re: &Regex, text: &String) -> Option<FileLine> {
    let matches = re.find_iter(text);
    for mat in matches {
        let start_pos = mat.start();
        let file_name = text.get(0..start_pos).unwrap();
        if !Path::new(file_name).is_file() {
            // check next matches if file_name does not exist.
            continue;
        }

        let tail = text.get(start_pos..).unwrap();
        let line_num = re.captures(tail).unwrap().get(1).unwrap().as_str().parse();
        if let Err(_) = line_num {
            continue;
        }

        let line_num = line_num.ok().unwrap();
        let fl = FileLine {
            file_name: file_name.to_string(),
            line_num,
        };
        return Some(fl);
    }
    None
}
```

実はこの判定方法でもまだ完全ではないのですが、誤判定する可能性はだいぶ減ったので
これで良しとしました。

## まとめ

以下の話をしました。

1. Rustでgrepの検索結果の続きを表示するコマンドを作った
1. grepの結果をパイプでコマンドに渡すだけで前後の行を表示できる
1. ファイル名の誤判断を防ぐためにファイルの存在チェックを行っている

以上。

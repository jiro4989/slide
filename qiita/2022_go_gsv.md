# CSVをgrepできるようにするコマンドを作った

## 経緯

CSVのセルには改行文字が含まれ得ます。
改行文字の含まれるCSVをgrepすると、CSVのセルが壊れます。

具体的には、以下のようなCSVをgrepすると壊れます。

```bash
$ cat testdata/sample1.csv
Language,Word,Note
English,"Hello
World",note
Japanese,"こんにちは
こんばんは",メモ
English,"John
Rose",
Japanese,"太郎
花子",

$ grep Japan a.csv
Japanese,"こんにちは
Japanese,"太郎
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
見ての通り、CSV行がJSON形式の文字列配列に変換されて出力されます。

```bash
$ cat testdata/sample1.csv
Language,Word,Note
English,"Hello
World",note
Japanese,"こんにちは
こんばんは",メモ
English,"John
Rose",
Japanese,"太郎
花子",

$ cat testdata/sample1.csv | ./gsv
["Language","Word","Note"]
["English","Hello\nWorld","note"]
["Japanese","こんにちは\nこんばんは","メモ"]
["English","John\nRose",""]
["Japanese","太郎\n花子",""]

$ cat testdata/sample1.csv | ./gsv | grep Japan
["Japanese","こんにちは\nこんばんは","メモ"]
["Japanese","太郎\n花子",""]

$ cat testdata/sample1.csv | ./gsv | grep Japan | ./gsv -u
Japanese,"こんにちは
こんばんは",メモ
Japanese,"太郎
花子",
```

## 実装

Go言語は標準でCSV、JSON用のライブラリを備えています。
このライブラリを使ってCSVを読み取り、読み取った文字列スライスをJSONフォーマットにエンコードします。

CSVを1行のJSONに変換する処理は以下のようになっています。

```go
func (a *App) readFoldAndWrite(r io.Reader, w io.Writer) error {
	c := csv.NewReader(r)
	for {
		row, err := c.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		result, err := Fold(row)
		result += "\n"
		b := []byte(result)
		if _, err := w.Write(b); err != nil {
			return err
		}
	}
	return nil
}

func Fold(row []string) (string, error) {
	b, err := json.Marshal(row)
	if err != nil {
		return "", err
	}
	s := string(b)
	return s, nil
}
```

そして変換したJSONをCSVに戻す処理は以下のようになっています。

```go
func (a *App) readUnfoldAndWrite(r io.Reader, w io.Writer) error {
	br := bufio.NewReader(r)
	cw := csv.NewWriter(w)
	cw.UseCRLF = a.param.LF == "crlf"
	for {
		line, _, err := br.ReadLine()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}

		row, err := Unfold(string(line))
		if err != nil {
			return err
		}

		if err := cw.Write(row); err != nil {
			return err
		}
		cw.Flush()
	}
	return nil
}

func Unfold(row string) ([]string, error) {
	b := []byte(row)
	var s []string
	if err := json.Unmarshal(b, &s); err != nil {
		return nil, err
	}
	return s, nil
}
```

中間フォーマットとしてJSONを採用したのは、エンコード、デコード処理を自前で実装したくなかったからです。

改行文字をエスケープして、アンエスケープできるフォーマットなら何でも良かったので、
Go言語の標準ライブラリで備わっているJSONを採用しました。

## まとめ

以下の話をしました。

1. CSVをgrepできるようにするコマンドを作った
1. CSVを1行のJSONに変換してgrepに食わせて使う

以上。

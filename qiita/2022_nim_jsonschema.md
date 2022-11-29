# JSON SchemaからNimのオブジェクトを自動生成する

この記事はNim Advent Calendar 2022の4日目の記事です。

JSON SchemaからNimのオブジェクト定義を自動生成する話です。

## JSON Schemaとは

オブジェクト定義をJSONで表現する規格です。
主な用途としてはWebAPIでフロントとサーバ間でやりとりするJSONを定義するケースです。

例えば、以下のようなJSON Schemaで表現したJSONがあります。

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://nats.io/schemas/jetstream/advisory/v1/nak.json",
  "description": "Advisory published when a message was naked using a AckNak acknowledgement",
  "title": "io.nats.jetstream.advisory.v1.nak",
  "type": "object",
  "required": [
    "type",
    "id",
    "timestamp",
    "stream",
    "consumer",
    "consumer_seq",
    "stream_seq",
    "deliveries"
  ],
  "additionalProperties": false,
  "properties": {
    "type": {
      "type": "string",
      "const": "io.nats.jetstream.advisory.v1.nak"
    },
    "id": {
      "type": "string",
      "description": "Unique correlation ID for this event"
    },
    "timestamp": {
      "type": "string",
      "description": "The time this event was created in RFC3339 format"
    },
    "stream": {
      "type": "string",
      "description": "The name of the stream where the message is stored"
    },
    "consumer": {
      "type": "string",
      "description": "The name of the consumer where the message was naked"
    },
    "consumer_seq": {
      "type": "string",
      "minimum": 1,
      "description": "The sequence of the message in the consumer that was naked"
    },
    "stream_seq": {
      "type": "string",
      "minimum": 1,
      "description": "The sequence of the message in the stream that was naked"
    },
    "deliveries": {
      "type": "integer",
      "minimum": 1,
      "description": "The number of deliveries that were attempted"
    },
    "domain": {
      "type": "string",
      "minimum": 1,
      "description": "The domain of the JetStreamServer"
    }
  }
}
```

このJSON Schemaは、以下のNimオブジェクトを表現したものです。
前述のJSON Schemaには `minimum` などの、値の下限と上限も記述できるため、
パラメータの境界値も明確になります。

```nim
type
  Object = ref object
    `type`: string
    id: string
    timestamp: string
    stream: string
    consumer: string
    consumer_seq: string
    stream_seq: string
    deliveries: int64
    domain: Option[string]
```

JSON Schemaについての話はすでにQiitaにいくつか解説している記事が存在するので、そちらに譲ります。
以下の記事は少し古いですが、最初の導入としてとても分かりやすかったです。

公式のドキュメントは以下です。
[JSON Schema](https://json-schema.org/)

JSON Schemaと似たようなものとしては[OpenAPI Spedification](https://swagger.io/specification/)が該当します。
こちらも便利です。

## JSON SchemaからNimのオブジェクト定義を生成する

本題です。JSON SchemaからNimのオブジェクト定義を生成します。
手前味噌ですが、[nimjson](https://github.com/jiro4989/nimjson)というツールを使うことで、JSON SchemaからNimのオブジェクト定義を生成できます。

以下のように使います。簡単ですね。

```bash
$ nimjson -j examples/json_schema.json
type
  Object = ref object
    `type`: string
    id: string
    timestamp: string
    stream: string
    consumer: string
    consumer_seq: string
    stream_seq: string
    deliveries: int64
    domain: Option[string]
```

## 経緯

nimjsonは3年ほど昔に僕が作成したNim製のCLIツールです。
以下の記事で解説しています。

* [JSONからNimのObject定義を生成するコマンドnimjsonを作った](https://qiita.com/jiro4989/items/86bc5e86b721f93eee49)

もともとnimjsonは、すでに存在するJSON文字列から
Nimのオブジェクト定義を逆生成する用途で作成したツールでした。
もとは[gojson](https://github.com/ChimeraCoder/gojson)というツールを参考にしたツールです。

```bash
$ echo '{"name":"hello"}' | nimjson
type
  NilType = ref object
  Object = ref object
    name: string
```

よってJSON Schemaのことは全くサポートしていませんでした。
僕自身、このMRで要望をもらって初めてJSON Schemaを知りました。

Nimのオブジェクト定義を生成するのが目的のツールなので、
用途的にもおかしくないので、せっかくだしこの要望に応えて、機能追加することにしました。

* [feat: support json schema - GitHub](https://github.com/jiro4989/nimjson/pull/31)

## 実装

実装の詳細はリポジトリのソースコードを見れば良いので、ここにすべては書きません。
メインのロジックだけ話すと、以下のparseプロシージャが肝です。

```nim
proc parse(parser: var JsonSchemaParser, property: Property,
    objectName: string) =
  if not property.isTypeObject:
    let typ =
      if property.isTypeArray: property.items.`type`
      else: property.`type`
    let objDef = newObjectDefinition(objectName.headUpper, false,
        parser.isPublic, parser.forceBackquote, typ, property.isTypeArray)
    parser.defs.add(objDef)
    return

  var objDef = newObjectDefinition(objectName.headUpper, false, parser.isPublic,
      parser.forceBackquote)
  for propName, prop in property.properties:
    let isOption = (not parser.disableOptionType) and propName notin
        property.required
    let typ =
      if prop.hasRef: prop.getRefTypeName(propName)
      else: prop.getPropertyType(propName)
    let fDef = newFieldDefinition(propName, typ, parser.isPublic,
        parser.forceBackquote, prop.isTypeArray, isOption)
    objDef.addFieldDefinition(fDef)
    if prop.isTypeObject:
      let p = newProperty(
        prop.description,
        prop.`type`,
        prop.required,
        prop.properties,
        prop.`$ref`,
      )
      parser.parse(p, typ)
  parser.defs.add(objDef)

proc parseAndGetString*(s: string, objectName: string, isPublic: bool,
    forceBackquote: bool, disableOptionType: bool): string =
  var parser = JsonSchemaParser(
    isPublic: isPublic,
    forceBackquote: forceBackquote,
    disableOptionType: disableOptionType,
  )

  let schema = s.fromJson(JsonSchema)
  let property = newProperty(
    schema.description,
    schema.`type`,
    schema.required,
    schema.properties,
    "",
  )
  parser.parse(property, objectName)

  for propName, prop in schema.`$defs`:
    parser.parse(prop, propName)

  result.add("type\n")
  result.add(parser.defs.toDefinitionString())
```

JSON SchemaのJSON文字列を解析して、
nimjson固有のオブジェクト定義オブジェクト(ObjectDefinition)に変換しています。

オブジェクト定義オブジェクトは、過去にnimjsonを作ったときから存在する型で
Nimのオブジェクト定義文字列に変換するプロシージャを持っています。
既存の文字列変換を使い回せるので、オブジェクト定義オブジェクトへ変換しています。

この既存の文字列生成プロシージャを使いまわしたかったため
オブジェクト定義オブジェクトに変換しています。

JSON Schemaではオブジェクトのネストが起こり得るため、`parse`を再帰呼び出しして処理しています。

また、JSON Schema自体をNimのオブジェクトへバインドするのに[jsony](https://github.com/treeform/jsony)というライブラリを使っています。
`fromJson` というプロシージャ呼び出しがそれです。

Nim標準の、JSONをObjectにバインドする`to`プロシージャには問題があります。
JSONには存在しないキーがバインド先オブジェクトに存在する場合エラーが発生します。
JSON Schemaで言うと、`required`キーワードなどは、必ずしも必要ではないため、実行時エラーになる可能性がありました。
`jsony`はこの問題を解決してくれるため、採用しました。

`jsony`を採用したことでNimコンパイラの1.0系、1.2系のサポートを打ち切らざるを得なかったのが残念です。
まぁ、開発時のツールとしての用途がメインなので、古いバージョンでインストールする人はあんまりいないはずですがね。

## まとめ

以下の話をしました。

1. JSON Schemaの話を軽くしました
1. JSON SchemaからNimのオブジェクト定義を生成するツール`nimjson`の使い方を話しました
1. `nimjson`の実装について話しました

以上。

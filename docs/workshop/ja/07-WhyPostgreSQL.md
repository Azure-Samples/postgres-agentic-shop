# PostgreSQL上でのベクトル・リランク・グラフクエリの詳細

このセクションでは、AgenticShopソリューション内で実際に使用されているPostgreSQLのテーブル構成と、ベクトル検索・リランク・グラフデータクエリの具体例について説明します。PostgreSQLに拡張機能を組み込むことで可能になった高度なクエリを、どのように使っているかを理解しましょう。

## テーブル一覧とスキーマ

AgenticShopで扱うデータは主に「製品」と「レビュー」に関するものです。リポジトリのデータセット（Agentic Shopデータセット）には、ヘッドフォン、スマートウォッチ、タブレットの3カテゴリについて、製品と対応するユーザーレビューが含まれています。それぞれに対応して、PostgreSQL上には以下のテーブルが存在します。

**products テーブル（製品情報）**: 製品の基本情報を格納するテーブルです。主なカラムは以下の通りです:
- id: 製品ID（整数, 主キー）
- name: 製品名（テキスト）
- category: 製品カテゴリ（テキスト、例: “headphones”, “smartwatches”, “tablets”）
- description: 製品の説明文（テキスト、自由記述の詳細な説明）
- description_emb: 製品説明文の埋め込みベクトル（vector型）。Azure OpenAIのEmbeddingモデルで生成した1536次元程度のベクトルが格納されています。
- features: 製品の特徴をまとめたJSONデータ（jsonb型）。LLMを用いて説明文から抽出した特徴量（例えばデザイン、バッテリー性能、防水性能など）がキーと値の形で格納されています。後述のグラフ分析で利用。

また、`description_emb`カラムにはベクトル検索を効率化するためのインデックスが作成されています（`pgvector`はInner ProductやCosine距離用のインデックスをサポート）。

**reviews テーブル（レビュー情報）**: ユーザーの製品レビューを格納するテーブルです。主なカラムは以下の通りです:
- id: レビューID（整数, 主キー）
- product_id: レビュー対象の製品ID（整数, 外部キーでproducts.idを参照）
- review_text: レビュー本文（テキスト、ユーザーが書いた自由形式の内容）
- review_text_emb: レビュー本文の埋め込みベクトル（vector型）。こちらも説明文同様にEmbeddingモデルでベクトル化したもの。
- features: レビューから抽出した特徴をまとめたJSONデータ（jsonb型）。例えば「soundQuality: positive/negative」や「battery: great battery life」といったキー値が含まれます。
`review_text_emb`にもベクトルインデックスが作成されています。これにより、レビュー内容を意味的に検索する処理が高速化されています。

以上2つのテーブルが中心データとなります。リレーションとして、`reviews.product_id`が`products.id`に対する外部キーとなっており、製品とレビューを紐づけています（1製品に複数レビューが対応）。

さらに、AgenticShopではApache AGEを用いて上記製品・レビュー・特徴をグラフ化しています。グラフ化に際して以下の概念がノード・エッジとして扱われます。
**ノード**:
- productノード: 製品1件につき1ノード。属性として製品IDや名前、カテゴリ、特徴JSONなどを保持。
- reviewノード: レビュー1件につき1ノード。属性としてレビューID、テキスト、特徴JSONなどを保持。
- featureノード: 製品やレビューから抽出される特徴語（例: “battery life”, “soundQuality”, “waterResistance”, “design”など）ごとにノード。属性に`name`（特徴名）を持つ。

**エッジ**:
- (:product)-[:HAS_REVIEW]->(:review): 製品ノードからそのレビューノードへのエッジ。
-	(:product)-[:HAS_FEATURE]->(:feature): 製品ノードから、その製品説明に含まれる特徴ノードへのエッジ。例えば製品説明に「water resistant（防水）」の話があれば、その製品と特徴「waterResistance」を結ぶエッジ。
-	(:review)-[:MENTIONS_FEATURE {sentiment: ...}]->(:feature): レビューノードから、レビュー本文で言及されている特徴ノードへのエッジ。エッジのプロパティ`sentiment`にはその言及がポジティブかネガティブかなど評価が入ります。

これらのグラフデータは、PostgreSQLの`AGE`拡張により`ag_catalog`内に管理されています。実際に`products`や`reviews`テーブルから特徴を抽出してグラフノード・エッジを作成する処理は、デプロイ時のスクリプトやバックエンドの初期化コードで実行されています（例えば全製品について特徴ノードを作り、`HAS_FEATURE`エッジを張る`INSERT`文、全レビューについて`MENTIONS_FEATURE`エッジを張る`INSERT`文など）。

## ベクトル・リランク・グラフデータに対するクエリ

AgenticShopでは、上記のデータと拡張機能を駆使して高度なクエリを実行しています。ここでは代表的なクエリの例を挙げ、その内容を解説します。

**ベクトル類似検索クエリ（Semantic Similarity Search）**:

ユーザーの質問や興味に合致する製品やレビューを見つけるために、埋め込みベクトルによる類似検索を行います。例えば「通話品質がクリアでバッテリーの評判が良いヘッドフォンは？」という問いに対し、システムはまず製品説明から類似する製品トップ10を探し、その製品に紐づくレビューの中から類似するレビュートップ10を見つける、といった二段階検索を行います。SQL例としては以下のようになります（簡略化しています）:

```sql
WITH potential_products AS (
  SELECT id, name, description
  FROM products
  WHERE category = 'headphones'
  ORDER BY description_emb <=> azure_openai.create_embeddings('text-embedding-ada-002', 'good clear calling')::vector
  ASC
  LIMIT 10
)
SELECT p.id AS product_id, r.id AS review_id, p.name, p.description, r.review_text
FROM potential_products p
LEFT JOIN reviews r USING (product_id)
ORDER BY r.review_text_emb <=> azure_openai.create_embeddings('text-embedding-ada-002', 'good battery life')::vector
ASC
LIMIT 10;
```

ここでは、まず`products`テーブルからカテゴリ`headphones`の中で "good clear calling" というフレーズに近い説明文を持つ製品をベクトル距離`<=>`でソートしています。`azure_openai.create_embeddings('text-embedding-ada-002', '...')` はAzure OpenAI経由でクエリ文をベクトル化する関数です（`azure_ai`拡張により提供）。この結果上位10件の製品を`potential_products`として、次にそれらのレビューを`reviews`テーブルから結合し、今度は "good battery life" に近いレビュー文を持つものをベクトル距離でソートしています。最終的に関連性の高いレビューとその製品が取得できます。このように、SQL内で直接埋め込み生成とベクトル比較を行っている点が大きな特徴です。

**ドキュメント再ランク（リランキング）クエリ**:
ベクトル検索で得られた結果をさらにLLMによる評価で並べ替えるのがリランキングです。Azure AI拡張の `azure_ai.rank()` 関数は、与えたクエリとドキュメント集合に対して、LLM（もしくはクロスエンコーダーモデル）で関連度スコアを算出し、最もクエリに合致するものから順にランキングを返します。例えば先ほどのレビュー集合に対し「どのレビューが『通話の明瞭さを重視しているか』」を評価するクエリは次のようになります。

```sql
WITH reviews(id, text) AS (
  VALUES
    (1, 'The product has a great battery life.'),
    (2, 'Noise cancellation does not work as advertised. Avoid this product.'),
    (3, 'Good design, but a bit heavy. Not recommended for travel.'),
    (4, 'Music quality is good but call quality could have been better.')
)
SELECT rr.rank, rr.id, r.text AS review
FROM azure_ai.rank(
       'clear calling capability that blocks out background noise',
       ARRAY(SELECT text FROM reviews ORDER BY id),
       ARRAY(SELECT id FROM reviews ORDER BY id)
     ) AS rr
JOIN reviews r ON r.id = rr.id
ORDER BY rr.rank ASC;
```

上記の例では4つのレビュー文を入力とし、「周囲の雑音を遮断してクリアな通話ができるか」という問い合わせとの関連度でランク付けしています。結果は`rank`値が低いほど関連度が高いものとして返り（1位が`rank=1`として出力）、レビューID2「ノイズキャンセルが期待通りに機能しない」が最も該当する（＝通話品質に課題が言及されている）と評価されています。このようにLLMがテキストの意味を総合的に判断して順位付けしてくれるため、ベクトル距離だけでは拾いきれない微妙な文脈も考慮した結果調整が可能になります。AgenticShopでは、このリランキングを検索結果の表示順最適化や、ユーザー質問に一番答えているレビュー抽出などに利用しています。

**グラフクエリ（openCypherを用いた問合せ）**:
製品・レビュー・特徴をグラフ構造にした利点は、複雑な条件を関係性で絞り込めることにあります。Cypherクエリではパターンマッチを使って、例えば「ヘッドフォンカテゴリの製品で、デザインに関する特徴を持ち、さらに防水機能の特徴も持ち、かつその製品のレビュー群に音質に関するポジティブな言及があるもの」を探すことができます。この条件は非常に複雑ですが、Cypherでは以下のように記述できます:

```sql
MATCH (p:product {category: 'headphones'})
  -[:HAS_FEATURE]->(:feature {name: 'design'})
  WITH p
MATCH (p)-[:HAS_FEATURE]->(:feature {name: 'waterResistance'})
  WITH p
MATCH (p)-[:HAS_REVIEW]->(r:review)
  -[:MENTIONS_FEATURE {sentiment: 'positive'}]->(:feature {name: 'soundQuality'})
RETURN p.id, r.id;
```

これはSQLからは `cypher('products_reviews_features_graph', $$ <上記クエリ> $$)` と呼び出して実行されます。結果として該当する製品IDとレビューIDの組を取得できます。AgenticShopでは、この結果に基づいてさらにSQL側で後処理を行っています。例えば、上記で得た製品とレビューの詳細情報を通常のテーブル（`products`, `reviews`）から引き出し、製品説明中に「軽量」であるかをLLMに判定させて不適合品を除外（`azure_ai.is_true`関数の利用）、最終的に製品ごとのレビュー数をカウントしつつLLMで要約文を生成する（`azure_ai.generate`関数の利用）――という具合です。一連の最終クエリはかなり長いものになりますが、SQLとCypherとAI関数を組み合わせて一回の問合せで結果を集約しています。このクエリにより、「軽量かつ防水で音質レビュー評価が高いヘッドフォン」の上位3つが要約付きで得られます。

実際の結果例では、製品IDと名前、それぞれの製品特徴サマリ（デザイン・防水の要約）とレビュー要約、レビュー件数が出力されています。LLMに要約させることで、ユーザーには「このヘッドフォンは軽量設計で防水性能があります。レビューでは音質が高く評価されました。」のように簡潔に特徴が伝えられるわけです。

以上、AgenticShopで用いられる高度なクエリについて見てきました。

まとめると、ベクトル検索は関連アイテムの絞り込みに、リランキングはLLMの理解による結果精度向上に、グラフクエリは複数条件を組み合わせた関係性抽出に、それぞれ威力を発揮しています。それらをPostgreSQL内で一貫して使えるため、データ移動のコストも無く複雑な質問に答えられるのです。

ハンズオンでは、実際にPostgreSQLに接続して上記のようなクエリを試すことも推奨します。`psql`やAzure Data Studio等でデータベースに接続し、`SELECT * FROM products LIMIT 5;`でデータを覗いてみたり、簡単なCypherクエリを実行してみましょう。たとえば、全製品ノード数とレビューノード数を数えるクエリ:

```sql
SELECT *
FROM cypher('products_reviews_features_graph', $$
  MATCH (p:product) RETURN count(p)
$$) AS t(count bigint);
```

などを試すと、グラフにデータが入っていることが確認できます。

[前へ](06-Post-provisioning.md) | [次へ](08-Wrapup.md)

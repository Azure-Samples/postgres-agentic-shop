# 事前準備と必要要件

本セクションでは、ハンズオンを開始する前に準備すべき環境や確認事項について説明します。参加者は**PostgreSQLの基礎知識**を有し、**Azure上でのAIアプリ開発の経験**があることを想定しています。その上で、必要なソフトウェアのインストールやAzureサブスクリプションの設定を事前に済ませておきましょう。

## ハンズオンに必要なもの
- **Azureサブスクリプション**: Azureの有効なサブスクリプションが必要です（所有者またはリソース作成権限を持つこと）。Azure OpenAI サービスを利用するため、このサービスへのアクセス権がサブスクリプションに含まれていることを確認してください（場合によっては利用申請が必要です）。
- **開発マシンとインターネット接続**: ハンズオンを実施するPC（Windows, macOS, Linuxいずれも可）と安定したインターネット接続が必要です。Azure CLI等を使用するため、ローカル環境にターミナル/コマンドプロンプトが利用可能であることを確認してください。

## 事前にインストールしておくべきソフトウェア

以下のソフトウェアを事前にインストールしてください。バージョンはできるだけ最新の安定版を推奨します。

- **Azure Developer CLI (`azd`)**: Azureの開発者向けCLIツールです。インストール手順は[Azure Developer CLI のインストール方法](https://learn.microsoft.com/ja-jp/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-linux)を参照してください。

- **Azure CLI**: Azureのコマンドラインツールです。インストール手順は[Azure CLI をインストールする方法](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli?view=azure-cli-latest)を参照してください。既にインストール済みであればバージョンの確認（`az --version`）を行い、必要に応じてアップデートしてください。

- **Azure CLI拡張機能（rdbms-connect）**: Azure CLIにPostgreSQLサーバーへの一時的トンネリング接続等を追加する拡張です。インストールは`az extension add --name rdbms-connect`で行います。インストール後、`az extension list`で有効になっていることを確認してください。

- **Python (3.8以上)**: デプロイ後のアプリケーションやスクリプトの動作に利用します。Pythonがインストールされていない場合は[公式サイト](https://www.python.org/downloads/windows/)から入手してください。Windowsの場合、インストール時に「Add Python to PATH」にチェックを入れておくと便利です。

- **PowerShell Core (Windowsユーザーのみ)**: WindowsでLinux向けスクリプトを実行する場合に必要です。事前に[PowerShell 7.x (Core)](https://learn.microsoft.com/ja-jp/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)をインストールしておいてください。

インストール後、それぞれのコマンドがパスに通っていることを確認しましょう。例えば`azd version`や`az --version`を実行してバージョン情報が表示されれば準備OKです。

## Azureリージョンの選定条件

本ハンズオンでデプロイするリソースにはAzure Database for PostgreSQLやAzure OpenAIサービスなどが含まれます。**Azure OpenAI**サービスは利用可能なリージョンが限られているため、**「Azure OpenAIが利用可能なリージョン」を選択することが重要**です。また、**Azure Database for PostgreSQLにおける一部拡張機能（後述のApache AGEなど）**は新規作成したサーバでサポートされるプレビュー機能です。Azure Developer CLI (`azd`) 実行時に、インフラリソース用リージョンとAzure OpenAI用リージョンの2つを尋ねられます。原則として以下の条件を満たすリージョンを選びましょう。

- **Azure OpenAI対応リージョン**: East USやSouth Central US、西ヨーロッパ、東日本など、Azure OpenAIリソースを作成できるリージョンを指定します。自分のサブスクリプションでOpenAIのサービス作成が許可されているリージョンか事前に確認してください。

- **データベースと近接した場所**: パフォーマンスの観点から、Azure Database for PostgreSQLを配置するリージョンと物理的に近いリージョンをAzure OpenAIに選ぶのが望ましいです。例えば、東日本リージョンにDBを作成した場合、Azure OpenAIも東日本または近隣のリージョンを選択します（ただしOpenAIサービスが限られるため妥協が必要な場合もあります）。

- **プレビュー機能の利用**: Apache AGE拡張は新規作成のPostgreSQLサーバでPG 13〜16の場合に利用可能で、既存サーバには有効化できません。`azd up`では自動的に新しいPostgreSQLサーバを作成しますが、念のためAzure Portalでプレビュー機能利用に関する記載がないか確認すると安心です。

## クォータの確認

Azure OpenAIサービスを利用するには、モデルごとの使用上限（クォータ）がサブスクリプションに割り当てられている必要があります。特に本ハンズオンで用いる**GPT-4**モデルや**Embedding**モデルは要求クォータが比較的大きいです。デフォルト構成では以下の程度のスループットが必要となります。

- **GPT-4 モデル**: 1分あたり150kトークン程度の処理能力 (150K TPM)。Azure OpenAIの「モデル使用上限 (Requests per minute)」がこれを満たす必要があります。

- **text-embedding-ada-002 (埋め込みモデル)**: 1分あたり120kトークン程度 (120K TPM)。

ご自身のAzureサブスクリプションのOpenAIクォータは、Azure Portalの「クォータ + 制限」ページや`az openai admin quota show`コマンドで確認できます。不足している場合は、Azure OpenAIリソースの作成時に上限引き上げのリクエストを申請してください。

> [!NOTE] 注意
> `azd up`実行時のプロンプトでも、上記モデルのデプロイ容量 (デフォルト値) をパラメータとして設定するようになっています。必要に応じてリポジトリ内の `infra/main.parameters.json` を編集することで、GPT-4や埋め込みモデルのデプロイスケールを調整できます（クォータ節約のためにTPSを下げる等）。

[前へ](01-Introduction.md) | [次へ](03-Integration.md)

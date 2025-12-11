# GitHub Actions ECR Push Setup

## 概要

このワークフロー `.github/workflows/push-to-ecr.yml` は、PR が main ブランチにマージされたときに自動的に Docker イメージをビルドして AWS ECR にプッシュします。

## セットアップ手順

### 1. IAM ロール（OIDC）の作成

GitHub Actions が AWS にアクセスするため、OpenID Connect (OIDC) を使った短期認証を設定します。

#### AWS 側の設定

```bash
# IAM OIDC プロバイダーを作成
aws iam create-openid-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# IAM ロールを作成（信頼ポリシー付き）
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:kanra824/yohei-app:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# ロールを作成
aws iam create-role \
  --role-name github-actions-ecr-push \
  --assume-role-policy-document file://trust-policy.json
```

#### 権限ポリシーを付与

```bash
cat > ecr-push-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:ap-northeast-1:YOUR_AWS_ACCOUNT_ID:repository/yohei-app"
    },
    {
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    }
  ]
}
EOF

# ロールにポリシーを付与
aws iam put-role-policy \
  --role-name github-actions-ecr-push \
  --policy-name ECRPushPolicy \
  --policy-document file://ecr-push-policy.json
```

### 2. GitHub Repository Secrets の設定

GitHub リポジトリの Settings → Secrets and variables → Actions から以下を追加：

- **Name:** `AWS_ROLE_TO_ASSUME`
- **Value:** `arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/github-actions-ecr-push`

`YOUR_AWS_ACCOUNT_ID` を自分のアカウント ID に置き換えてください。

### 3. ワークフローの動作確認

1. PR を作成して main にマージする
2. GitHub Actions タブでワークフローの実行を確認
3. ECR コンソールでイメージが push されたことを確認

```bash
# コマンドラインで確認
aws ecr list-images --repository-name yohei-app --region ap-northeast-1
```

## ワークフローの詳細

### トリガー条件

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'backend/**'          # backend 配下の変更のみ
      - '.github/workflows/push-to-ecr.yml'  # ワークフロー自体の変更
```

### 実行内容

1. **Checkout:** リポジトリをチェックアウト
2. **AWS 認証:** OIDC を使用して AWS に認証
3. **ECR ログイン:** docker login で ECR に認証
4. **ビルド・プッシュ:** Docker イメージをビルドして ECR にプッシュ
   - タグ: `sha-<COMMIT_HASH>`（コミット用）
   - タグ: `latest`（最新版）

## トラブルシューティング

### エラー: "Could not retrieve ECR access token"

**原因:** IAM ロールの権限不足

**解決策:** IAM ポリシーを確認し、`ecr:GetAuthorizationToken` が付与されているか確認

```bash
aws iam get-role-policy \
  --role-name github-actions-ecr-push \
  --policy-name ECRPushPolicy
```

### エラー: "UnauthorizedOperation: User is not authorized"

**原因:** GitHub の OIDC トークンの subject が信頼ポリシーと一致していない

**確認方法:**
```bash
# 信頼ポリシーを確認
aws iam get-role --role-name github-actions-ecr-push
```

### イメージが push されない

**チェックリスト:**
- [ ] ワークフローファイルが `.github/workflows/push-to-ecr.yml` に存在
- [ ] PR が main ブランチにマージされた（push ではなくマージ）
- [ ] `backend/` 配下に変更がある
- [ ] AWS 認証情報が正しく設定されている
- [ ] GitHub Actions ログで詳細なエラーを確認

## 手動実行（テスト用）

ワークフローを手動で実行する場合（リポジトリの Actions タブから）：

```bash
# ワークフローに手動トリガーを追加する場合
on:
  workflow_dispatch:
```

## セキュリティのベストプラクティス

- ✅ **OIDC 使用:** 長期的な AWS 認証情報を保存しない
- ✅ **権限最小化:** 必要な ECR 操作のみを許可
- ✅ **Subject 制限:** `main` ブランチのみに制限
- ✅ **パス制限:** `backend/**` の変更のみトリガー

## 参考資料

- [GitHub Actions - AWS authentication](https://github.com/aws-actions/configure-aws-credentials)
- [AWS OIDC Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for_user_oidc.html)

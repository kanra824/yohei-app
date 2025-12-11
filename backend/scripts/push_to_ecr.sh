AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-northeast-1
REPO_URL=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/yohei-app

aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $REPO_URL

COMMIT_HASH=$(git rev-parse --short HEAD)
TAG=$1 # v1.0.0

docker build -t yohei-app:sha-${COMMIT_HASH} .
docker tag yohei-app:sha-${COMMIT_HASH} $REPO_URL:TAG
docker tag yohei-app:sha-${COMMIT_HASH} $REPO_URL:latest

docker push $REPO_URL:TAG
docker push $REPO_URL:latest

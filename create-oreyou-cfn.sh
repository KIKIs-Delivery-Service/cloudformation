#!/usr/bin/env bash

# 俺用リソースを定義したCloudFormationスタックを作成する
# リソースにくっつけたい名前を第一引数に入れる

# 前提
# 同ディレクトリにCloudFormationテンプレートファイルを用意する

# 使用例
# bash cfn-create-master-server.sh <OwnerName>

###############
# 関数
###############

# CloudFormationテンプレートの検証
function validate_cloudformation_template() {
  local cloudformation_file_path="$1"
  echo "CloudFormationテンプレートの検証開始"
  aws cloudformation validate-template --template-body "file://${cloudformation_file_path}"
  if [[ $? == 0 ]]; then
    echo "CloudFormationテンプレートの検証に成功しました。"
    echo
  else
    echo "CloudFormationテンプレートの検証に失敗しました。テンプレートファイルが正しく記述されているか確認してください。"
    exit 1
  fi
}

# CloudFormationスタックの作成
function create_oreyou_stack() {
  local stack_name="$1"
  local cloudformation_file_path="$2"
  local owner="$3"

  echo "CloudFormationのスタックの作成を開始"
  aws cloudformation create-stack \
    --stack-name "${stack_name}" \
    --template-body "file://${cloudformation_file_path}" \
    --tags Key=Owner,Value="${owner}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
    ParameterKey=Owner,ParameterValue="${owner}"
  if [[ $? == 252 ]]; then
    echo "CloudFormation のパラメータに不備があります。パラメータ値が正しく格納されているか確認してください。"
    exit 252
  fi
}

# CloudFormationスタックの状態が CREATE_COMPLETE になるまで待機
function wait_until_stack_create_complete() {
  local stack_name="$1"
  aws cloudformation wait stack-create-complete --stack-name "${stack_name}"
  if [[ $? == 0 ]]; then
    echo "STACK CREATE COMPLETE!"
    echo
  else
    echo "STACK CREATE FAILED!"
    echo
    return 1
  fi
}

# CloudFormationスタックのイベント確認
function describe_stack_events() {
  stack_name="$1"
  aws cloudformation describe-stack-events \
    --stack-name "${stack_name}" \
    --query 'StackEvents[].{
              Timestamp:Timestamp,
              LogicalResourceId:LogicalResourceId,
              ResourceType:ResourceType,
              Status:ResourceStatus,
              StatusReason:ResourceStatusReason
            }' \
    --output table
  echo
}

# CloudFormationスタックの削除
function delete_stack() {
  local stack_name="$1"
  aws cloudformation delete-stack --stack-name "${stack_name}"
  aws cloudformation wait stack-delete-complete --stack-name "${stack_name}" && echo "STACK DELETE COMPLETE!"
  echo
}

###############
# メイン処理
###############

CLOUDFORMATION_FILE_PATH="oreyou-cfn.yml"
OWNER="$1"
STACK_NAME="${OWNER}-stack"

# CloudFormationテンプレートの検証
validate_cloudformation_template "${CLOUDFORMATION_FILE_PATH}"

# 同名のスタックがあったら削除
delete_stack "${STACK_NAME}"

# Cloudformationスタックを作成（マスタサーバを作成）
create_oreyou_stack "${STACK_NAME}" "${CLOUDFORMATION_FILE_PATH}" "${OWNER}"
# スタックの状態が CREATE_COMPLETE になるまで待機
if ! wait_until_stack_create_complete "${STACK_NAME}"; then
  # スタックのイベント確認
  describe_stack_events "${STACK_NAME}"
  # スタックを削除
  delete_stack "${STACK_NAME}"
  exit 1
fi

# スタックのイベント確認
describe_stack_events "${STACK_NAME}"

# スタックの削除
# delete_stack "${stack_name}"

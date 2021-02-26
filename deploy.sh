#!/bin/bash
# from https://hey.impanda.net/2018/03/20/hugo-to-aliyun-oss.html

echo "checking env variables if all ready...\n\r"
if [[ -z "${OSS_ENDPOINT}" ]]; then
  echo "env OSS_ENDPOINT undefined"
  exit 1
fi

if [[ -z "${OSS_KEY_ID}" ]]; then
  echo "env OSS_KEY_ID undefined"
  exit 1
fi

if [[ -z "${OSS_KEY_SECRET}" ]]; then
  echo "env OSS_KEY_SECRET undefined"
  exit 1
fi

if [[ -z "${OSS_BUCKET_NAME}" ]]; then
  echo "env OSS_BUCKET_NAME undefined"
  exit 1
fi

OSS_KEY_ID="${OSS_KEY_ID}"
OSS_KEY_SECRET="${OSS_KEY_SECRET}"
OSS_ENDPOINT="${OSS_ENDPOINT}"
OSS_BUCKET_NAME="${OSS_BUCKET_NAME}"

# download ossutil
UPLOAD_PATH=$PWD/public
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $SCRIPT_DIR
echo "env checked completed, ready to download ossutil....\n\r"
if [ ! -f "./oss" ]; then 
  echo "ossutil does not exist, begin downloading..."; 
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)     oss_tool_url=http://gosspublic.alicdn.com/ossutil/1.7.1/ossutil64;;
      Darwin*)    oss_tool_url=http://gosspublic.alicdn.com/ossutil/1.5.2/ossutilmac64;;
      *)          oss_tool_url="UNKNOWN"
  esac
  if [ "$oss_tool_url" = "UNKNOWN" ]; then
    echo "unsupport system"
    exit 1
  fi

  curl -o oss $oss_tool_url

fi

chmod +x oss

# init config & ready to upload files
./oss config -e $OSS_ENDPOINT -i $OSS_KEY_ID -k $OSS_KEY_SECRET
echo "oss config initial completed,ready to upload files from $UPLOAD_PATH ...\n\r"

./oss sync  $UPLOAD_PATH oss://$OSS_BUCKET_NAME --delete -f --update
echo "\n\rdone"
exit 0

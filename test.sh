#!/usr/bin/env bash

set -eu

. ./hmac-sha1.sh

func() {
  hmac1=$(printf '%s' "$2" | openssl dgst -sha1 -hmac "$1" | cut -d' ' -f2)
  hmac2=$(hmac_sha1 "$1" "$2")
  echo "openssl: $hmac1"
  echo "shell  : $hmac2"
  [ "$hmac1" = "$hmac2" ]
}

if [ $# -eq 1 ]; then
  key=$1 msg='' i=0 max=1000
  echo "test: key:[$key]"
  while [ $i -le "$max" ]; do
    printf "%d " "${#msg}"
    func "$key" "$msg" >/dev/null
    msg="${msg}a"
  done
  echo "done"
  exit
fi

if [ $# -eq 2 ]; then
  key="${1:-secret_key}" msg="${2:-value}"
  echo "test: key:[$key] msg:[$msg]"
  func "$key" "$msg"
  echo "done"
  exit
fi

echo "tests:"
while IFS=" " read -r key msg; do
  func "$key" "$msg"
done << HERE
secret_key value
$(printf '%065d' 0) $(printf '%065d' 0)
$(printf '%01000d' 0) $(printf '%01000d' 0)
HERE
echo "done"

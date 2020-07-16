#!/bin/sh -l

set -e

#
# Input verification
#
TOKEN="${INPUT_TOKEN}"
if [ -z "${TOKEN}" ]; then
  >&2 printf "\nERR: Invalid input: 'token' is required, and must be specified.\n"
  >&2 printf "\tNote: It's necessary to interact with Github's API.\n\n"
  exit 1
fi

# Try getting $NAME from action input
NAME="${INPUT_NAME}"
if [ -z "${NAME}" ]; then
  >&2 printf "\nERR: Invalid input: 'name' is required, and must be specified.\n"
  >&2 printf "\tNote: It's necessary to interact with Github's API.\n\n"
  exit 1
fi
NAME="$(echo ${NAME} | tr -d \" | tr ' ' '\n')"
echo ${NAME}

# Try getting $TAG from action input
ISTAG="${INPUT_ISTAG}"
if [ -z "${ISTAG}" ]; then
  ISTAG="false"
fi
ISTAG="$(echo ${ISTAG} | tr -d \" | tr '[a-z]' '[A-Z]')"

BASE_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/releases"

function deleteRes()
{
    ehoc 'test'
    CODE="$(curl -sS -H "Authorization: token ${TOKEN}" -X DELETE \
	--write-out "%{http_code}" -o $2 \
	$1)"
    echo $CODE
}

if [ -z "$(echo ${NAME} | grep "all")" -a -z "$(echo ${NAME} | grep "ALL")" ]; then
  BASE_URL=$BASE_URL/tags
  for entry in ${NAME}; do
    RELEASE_URL="$(curl -sS -H "Authorization: token ${TOKEN}" \
      $BASE_URL/$entry | jq -r '.url | select(. != null)')"
    if [ -n $RELEASE_URL ]; then
      if [ "$(deleteRes $RELEASE_URL '/tmp/httpcode.json')" == "204" ]; then
        printf "\nDel release %s success\n" "$entry"
	else
	  printf "\nDel release %s failure: %s\n" "$entry" "`jq < /tmp/httpcode.json`"
	fi
    fi

    if [ "${ISTAG}" == "YES" -o -z $RELEASE_URL ]; then
	if [ "$(deleteRes "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/tags/$entry" '/tmp/httpcode.json')" == "204" ]; then
	  printf "\nDel tag %s success\n" "$entry"
	else
	  printf "\nDel tag %s failure: %s\n" "$entry" "`jq < /tmp/httpcode.json`"
	fi
    fi
  done
else
  CODE="$(curl -sS -H "Authorization: token ${TOKEN}" \
    --write-out "%{http_code}" -o "/tmp/allres.json" \
    $BASE_URL)"

  if [ "$CODE" != "200" ]; then
    >&2 printf "\n\tERR: del to Github release has failed\n"
    >&2 jq < "/tmp/allres.json"
    exit 1
  fi

  jq -r '.[].tag_name' > /tmp/alltags.json < "/tmp/allres.json"

  echo 222222222222222
  for entry in "$(jq -r '.[].url' < "/tmp/allres.json")"; do
    if [ "$(deleteRes $entry '/tmp/httpcode.json')" == "204" ]; then
	printf "\nDel release %s success\n" "$entry"
    else
	printf "\nDel release %s failure: %s\n" "$entry" "`jq < /tmp/httpcode.json`"
    fi
  done

  if [ ${ISTAG} == "YES" ]; then
    for entry in "`cat '/tmp/alltags.json'`"; do
	if [ "$(deleteRes "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/tags/$entry" '/tmp/httpcode.json')" == "204" ]; then
	  printf "\nDel tag %s success\n" "$entry"
	else
	  printf "\nDel tag %s failure: %s\n" "$entry" "`jq < /tmp/httpcode.json`"
	fi
    done
  fi

  for entry in ${NAME}; do
    [ -n "$(echo ${NAME} | grep "all")" -o -n "$(echo ${NAME} | grep "ALL")" ] && continue
    if [ "$(deleteRes "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/tags/$entry" '/tmp/httpcode.json')" == "204" ]; then
	  printf "\nDel tag %s success\n" "$entry"
	else
	  printf "\nDel tag %s failure: %s\n" "$entry" "`jq < /tmp/httpcode.json`"
	fi
  done
fi

>&2 echo "All done."

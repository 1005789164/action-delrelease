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

if [[ "${NAME}" != *"all"* ]] || [[ "${NAME}" != *"ALL"* ]]; then
  BASE_URL=$BASE_URL/tags
  for entry in ${NAME}; do
    RELEASE_URL="$(curl -sS -H "Authorization: token ${TOKEN}" \
      $BASE_URL/$entry | jq -r '.url | select(. != null)')"
    echo ---$RELEASE_URL---
    if [ -z $RELEASE_URL ]; then
      printf "\nNo release delete tag %s: %s\n" "$entry" "$(curl -sS -H "Authorization: token ${TOKEN}" \
      -X DELETE \
      https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/tags/$entry)"
    else
      printf "\nDel release %s: $(curl -sS -H "Authorization: token ${TOKEN}" \
      -X DELETE \
      $RELEASE_URL)\n" "$entry"
    fi

    if [ ${ISTAG} == "YES" ]; then
      printf "\nDel tag %s: %s\n" "$entry" "$(curl -sS -H "Authorization: token ${TOKEN}" \
      -X DELETE \
      https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/tags/$entry)"
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
  for entry in "$(jq -r '.[].url' < "/tmp/allres.json" | tr ' ' '\n')"; do
    printf "\nDel release %s: %s\n" "$entry" "$(curl -sS -H 'Authorization: token ${TOKEN}' \
    -X DELETE \
    $entry)"
  done

  if [ ${ISTAG} == "YES" ]; then
    for entry in "$(cat "/tmp/alltags.json" | tr ' ' '\n')"; do
      printf "\nDel tag %s: %s\n" "$entry" "$(curl -sS -H 'Authorization: token ${TOKEN}' \
      -X DELETE \
      https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/tags/$entry)"
    done
  fi
fi

>&2 echo "All done."

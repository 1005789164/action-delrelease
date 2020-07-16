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
NAME="$(echo ${NAME} | tr -d \")"

# Try getting $TAG from action input
ISTAG="${INPUT_ISTAG}"
if [ -z "${ISTAG}" ]; then
  ISTAG="false"
fi
ISTAG="$(echo ${ISTAG} | tr -d \")"

BASE_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}/releases"
echo $NAME
if [[ "${NAME}" != *"all"* ]] || [[ "${NAME}" != *"ALL"* ]]; then
  BASE_URL=${BASE_URL}/tags
  for entry in "$(echo ${NAME} | tr ' ' '\n')"; do
    RELEASE_URL="$(curl -sS -H "Authorization: token ${TOKEN}" \
      ${BASE_URL}/$entry | jq -r '.url | select(. != null)')"
    curl -sS -H "Authorization: token ${TOKEN}" \
    -X DELETE \
    $RELEASE_URL

    printf "\n111111111111111111111111111111\n\n"
    if [ ${ISTAG} == "yes" ] || [ ${ISTAG} == "YES" ]; then
      curl -sS -H "Authorization: token ${TOKEN}" \
      -X DELETE \
      https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/tags/$entry
	printf "\n2222222222222111\n\n"
    fi
    printf "\n333333333311111\n\n"
  done
else
  CODE="$(curl -sS -H "Authorization: token ${TOKEN}" \
    --write-out "%{http_code}" -o "/tmp/allres.json" \
    ${BASE_URL})"

  if [ "${CODE}" != "200" ]; then
    >&2 printf "\n\tERR: %s to Github release has failed\n" "del"
    >&2 jq < "/tmp/allres.json"
    exit 1
  fi

  jq '.[].tag_name' > /tmp/alltags.json < "/tmp/allres.json"
  for entry in "$(jq '.url' < "/tmp/allres.json" | tr ' ' '\n')"; do
    curl -sS -H "Authorization: token ${TOKEN}" \
    -X DELETE \
    $entry
  done

  if [ ${ISTAG} == "yes" ] || [ ${ISTAG} == "YES" ]; then
    for entry in "$(cat "/tmp/alltags.json" | tr ' ' '\n')"; do
      curl -sS -H "Authorization: token ${TOKEN}" \
      -X DELETE \
      https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/tags/$entry
    done
  fi
fi

>&2 echo "All done."

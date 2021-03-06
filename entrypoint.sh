#!/bin/sh -l

set -e

#
# Input verification
#
TOKEN="${INPUT_TOKEN}"
if [ -z "${TOKEN}" ]; then
	printf >&2 "\nERR: Invalid input: 'token' is required, and must be specified.\n"
	printf >&2 "\tNote: It's necessary to interact with Github's API.\n\n"
	exit 1
fi

# Try getting $NAME from action input
NAME="${INPUT_NAME}"
if [ -z "${NAME}" ]; then
	printf >&2 "\nERR: Invalid input: 'name' is required, and must be specified.\n"
	printf >&2 "\tNote: It's necessary to interact with Github's API.\n\n"
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

BASE_URL="https://api.github.com/repos/${GITHUB_REPOSITORY}"

function deleteRes() {
	CODE="$(
		curl -sS -H "Authorization: token ${TOKEN}" -X DELETE \
		--write-out "%{http_code}" -o $2 \
		$1
	)"
	echo $CODE
}

if [ -z "$(echo ${NAME} | grep "all")" -a -z "$(echo ${NAME} | grep "ALL")" ]; then
	BASE_URL=$BASE_URL/releases/tags
	for entry in ${NAME}; do
		RELEASE_URL="$(
			curl -sS -H "Authorization: token ${TOKEN}" \
			$BASE_URL/$entry | jq -r '.url | select(. != null)'
		)"
		if [ -n "$RELEASE_URL" ]; then
			if [ "$(deleteRes "$RELEASE_URL" '/tmp/httpcode.json')" == "204" ]; then
				printf "\nDel release %s success" "$entry"
			else
				printf "\nDel release %s failure: %s\n" "$entry" "$(jq </tmp/httpcode.json)"
			fi
		fi

		if [ "${ISTAG}" == "YES" -o -z "$RELEASE_URL" ]; then
			if [ "$(deleteRes "$BASE_URL/git/refs/tags/$entry" '/tmp/httpcode.json')" == "204" ]; then
				printf "\nDel tag %s success" "$entry"
			else
				printf "\nDel tag %s failure: %s\n" "$entry" "$(jq </tmp/httpcode.json)"
			fi
		fi
	done
else
	CODE="$(
		curl -sS -H "Authorization: token ${TOKEN}" \
		--write-out "%{http_code}" -o "/tmp/allres.json" \
		$BASE_URL/releases
	)"

	if [ "$CODE" == "200" -a -n "$(jq -r '.[].url' <"/tmp/allres.json")" ]; then
		jq -r '.[].tag_name' >/tmp/alltags.json <"/tmp/allres.json"

		for entry in $(jq -r '.[].url' <"/tmp/allres.json"); do
			if [ "$(deleteRes "$entry" '/tmp/httpcode.json')" == "204" ]; then
				printf "\nDel release %s success" "$entry"
			else
				printf "\nDel release %s failure: %s\n" "$entry" "$(jq </tmp/httpcode.json)"
			fi
		done

		if [ ${ISTAG} == "YES" ]; then
			while read entry; do
				if [ "$(deleteRes "$BASE_URL/git/refs/tags/$entry" '/tmp/httpcode.json')" == "204" ]; then
					printf "\nDel tag %s success" "$entry"
				else
					printf "\nDel tag %s failure: %s\n" "$entry" "$(jq </tmp/httpcode.json)"
				fi
			done </tmp/alltags.json
		fi
	fi

	for entry in ${NAME}; do
		[ -n "$(echo $entry | grep "all")" -o -n "$(echo $entry | grep "ALL")" ] && continue

		if [ "$(deleteRes "$BASE_URL/git/refs/tags/$entry" '/tmp/httpcode.json')" == "204" ]; then
			printf "\nDel tag %s success" "$entry"
		else
			printf "\nDel tag %s failure: %s\n" "$entry" "$(jq </tmp/httpcode.json)"
		fi
	done
fi

printf >&2 "\nAll done."

#!/bin/sh

set -e

if ! type git > /dev/null 2>&1; then
    echo "ERROR: git not found, can't continue" >&2
    exit 1
fi

echo "Checking for tabs" >&2
git --no-pager grep -InP --heading "\t" -- . ':!third_party/**/*' && ret=1

echo "Checking for carriage returns" >&2
git --no-pager grep -InP --heading "\r" -- . ':!third_party/**/*' && ret=1

echo "Checking for trailing spaces" >&2
git --no-pager grep -InP --heading " $" -- . ':!third_party/**/*' ':!*.patch' && ret=1


# Test only "new" commits, that is, commits that are not upstream on
# the master branch.
git fetch -q https://gitlab.com/AOMediaCodec/SVT-AV1.git master && FETCH_HEAD=FETCH_HEAD || FETCH_HEAD=master
if git diff --exit-code HEAD ^$FETCH_HEAD > /dev/null 2>&1; then
    echo "No differences to upstream  master, skipping further tests"
    exit 0
fi

while read -r file; do
    if ! test -f "$file"; then
        echo "Ignoring folder or not found file: '$file'"
        continue
    fi
    if test -n "$(tail -c1 "$file")"; then
        echo "No newline at end of $file"
        ret=1
    fi
done << EOF
$(
    git diff --name-only --diff-filter=d $FETCH_HEAD -- . \
        ':!third_party' ':!test/e2e_test/test_vector_list.txt' \
        ':!test/vectors/smoking_test.cfg' \
        ':!test/vectors/video_src.cfg' \
        ':!*.png'
)
EOF

while read -r i; do
    echo "Checking commit message of $i" >&2
    msg=$(git log --format=%B -n 1 "$i")
    if test -n "$(printf '%s' "$msg" | sed -n 2p)"; then
        echo "Malformed commit message in $i, second line must be empty"
        ret=1
    fi
    if printf '%s' "$msg" | head -1 | grep -q '\.$'; then
        echo "Malformed commit message in $i, trailing period in subject line"
        ret=1
    fi
done << EOF
$(git rev-list HEAD ^$FETCH_HEAD)
EOF
exit ${ret:-0}

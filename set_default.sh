#!/bin/sh -e

# Set the deploy corresponding to the latest commit as default

: ${PROJECT:=khan-academy}

die() {
    echo "FATAL ERROR: $@"
    exit 1
}

# Calculate the version name for the latest commit
# Format is: YYMMDD-HHMM-RRRRRRRRRRRR
#
# Keep this in sync with VERSION in deploy.sh
VERSION=`git log -n1 --format="format:%H %ct" | perl -ne '$ENV{TZ} = "US/Pacific"; ($rev, $t) = split; @lt = localtime($t); printf "%02d%02d%02d-%02d%02d-%.12s\n", $lt[5] % 100, $lt[4] + 1, $lt[3], $lt[2], $lt[1], $rev'`

MODULE=`sed -ne 's/module: //p' app.yaml`

echo "Setting ${VERSION} as default on module ${MODULE}..."

NON_DEFAULT_HOSTNAME="https://${VERSION}-dot-${MODULE}-dot-${PROJECT}.appspot.com"
HEALTHCHECK_URL="${NON_DEFAULT_HOSTNAME}/_ah/health"

curl -s -I "${HEALTHCHECK_URL}" | head -n1 | grep -q -w '200' \
    || die "Server at ${NON_DEFAULT_HOSTNAME} not healthy"

# TODO(jlfwong): Prime the new version of the servers before we set default. We
# want them to load their caches with the most frequently used JS packages from
# khanacademy.org.

gcloud -q --verbosity info preview app modules set-default "$MODULE" \
    --project "$PROJECT" --version "$VERSION"

# Ensure that the version flipped
DEFAULT_HOSTNAME="https://${MODULE}-dot-${PROJECT}.appspot.com/_api/version"

# Wait for the new version to become accessible, waiting up a minute(ish).
for i in `seq 10`; do
    LIVE_VERSION=`curl -s ${DEFAULT_HOSTNAME}`
    [ "${LIVE_VERSION}" = "${VERSION}" ] && break
    [ $i -eq 10 ] && die "Expected live version to be ${VERSION}, but saw ${LIVE_VERSION}."
    sleep "$i"
done

# TODO(csilvers): git tag the release.

echo "Default set, now deleting old versions."
# TODO(csilvers): support 'good' and 'bad' versions via git tag.



echo "DONE"

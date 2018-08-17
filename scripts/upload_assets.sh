#!/bin/bash

CONFIG=$@

for line in $CONFIG; do
  eval "$line"
done

owner="snowdrop"
repo="k8s-supervisor"

AUTH="Authorization: token $GITHUB_API_TOKEN"

GH_API="https://api.github.com"
GH_REPO="$GH_API/repos/$owner/$repo"

WGET_ARGS="--content-disposition --auth-no-challenge --no-cookie"
CURL_ARGS="-LJO#"

TAG="v$VERSION"
GH_TAGS="$GH_REPO/releases/tags/$TAG"

BIN_DIR="./dist/bin/"
RELEASE_DIR="./dist/release"
APP="sb"

echo "git tag"
git tag -a $TAG -m "$TAG release"

echo "Create Release for tag $TAG"
JSON='{"tag_name": "'"$TAG"'","target_commitish": "master","name": "'"$TAG"'","body": "'"$TAG"'-release","draft": false,"prerelease": false}'

curl -H "$AUTH" \
     -H "Content-Type: application/json" \
     -d "$JSON" \
     $GH_REPO/releases

# Read asset tags.
response=$(curl -sH "$AUTH" $GH_TAGS)

# Get ID of the asset based on given filename.
eval $(echo "$response" | grep -m 1 "id.:" | grep -w id | tr : = | tr -cd '[[:alnum:]]=')
[ "$id" ] || { echo "Error: Failed to get release id for tag: $tag"; echo "$response" | awk 'length($0)<100' >&2; exit 1; }
echo "ID : $id"

# Upload assets
for arch in `ls -1 $BIN_DIR/`;do
     suffix=""
     if [[ $arch == windows-* ]]; then
         suffix=".exe"
     fi
     target_file=$RELEASE_DIR/$APP-$arch$suffix.tgz
     content_type=$(file -b --mime-type $target_file)
     echo "Asset : $target_file"
     echo "Content type : $content_type"

     GH_ASSET_URL="https://uploads.github.com/repos/$owner/$repo/releases/$id/assets?name=$(basename $target_file)"
     echo "GH_ASSET_URL : $GH_ASSET_URL"

     curl -i -H "Authorization: token $GITHUB_API_TOKEN" \
          -H "Accept: application/vnd.github.v3+json" \
          -H "Content-Type: $content_type" \
          -X POST \
          --data-binary @$target_file \
          $GH_ASSET_URL
done
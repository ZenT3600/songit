#!/usr/bin/bash

function generate-metadata() {
	test ! -d "$REPO_PATH" && mkdir "$REPO_PATH"
	echo "# Generating metadata..." | glow -
	echo "> Recreating directory tree..." | glow -
	find "$SOURCE" -type d -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | sed "s@$SOURCE@@" | xargs -I{} mkdir "$REPO_PATH{}" 2> /dev/null
	echo "> Extracting metadata... *(this may take a while*)" | glow -
	find "$SOURCE" -type f -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | sed "s@$SOURCE@@" | xargs -I{} bash -c "exiftool \"$SOURCE{}\" > \"$REPO_PATH/{}.txt\""
}

function update-repo() {
	test ! -d "$REPO_PATH/.git" && git -C "$REPO_PATH" init && git config --global --add safe.directory "$REPO_PATH"
	echo "# Updating internal repo..." | glow -
	git -C "$REPO_PATH" add . -v
	git -C "$REPO_PATH" commit -m "$(date)" -v
}

function copy-over() {
	GIT_DISCOVERY_ACROSS_FILESYSTEM=1
	echo "# Copying over data..." | glow -
	echo "> Recreating directory tree..." | glow -
	find "$SOURCE" -type d -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | sed "s@$SOURCE@@" | xargs -I{} mkdir "$(realpath $TARGET)/{}" 2> /dev/null
	test ! -d "$REPO_TARGET_PATH" && mkdir "$REPO_TARGET_PATH"
	test ! -d "$REPO_TARGET_PATH/.git" && git -C "$REPO_TARGET_PATH" init && git config --global --add safe.directory "$REPO_TARGET_PATH" && git -C "$REPO_TARGET_PATH" config --local receive.denyCurrentBranch ignore
	echo "> Pushing internal repo changes" | glow -
	git -C "$REPO_PATH" remote add target "$REPO_TARGET_PATH"
	git -C "$REPO_PATH" remote update
	git -C "$REPO_PATH" fetch target
	git -C "$REPO_PATH" push target master
	git -C "$REPO_PATH" remote rm target
	echo "> Copying changes from source" | glow -
	git -C "$REPO_TARGET_PATH" status --porcelain | xargs -I{} echo -e "{}\n" | awk '{$1 = ""; print $0}' | sed 's/\.txt//g' | sed 's/"//g' | xargs -I{} cp "$(realpath $SOURCE)/{}" "$(realpath $TARGET)/{}"
}

SOURCE=$1
test -z $SOURCE && exit

TARGET=$2
test -z $TARGET && exit

if [ -f .env ]; then
	export $(cat .env | xargs)
else
	REPO_DIR=".songit"
fi

REPO_PATH=$(realpath $SOURCE)/$REPO_DIR
REPO_TARGET_PATH=$(realpath $TARGET)/$REPO_DIR

generate-metadata
update-repo
copy-over

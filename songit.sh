#!/usr/bin/bash

function generate-metadata() {
	echo "> Removing outdated metadata..."
	rm -rf "$REPO_PATH/"*
	test ! -d "$REPO_PATH" && mkdir "$REPO_PATH"
	echo "Generating metadata..."
	echo "> Recreating directory tree..."
	find "$SOURCE" -type d -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | sed "s@$SOURCE@@" | xargs -I{} mkdir "$REPO_PATH/{}" 2> /dev/null
	echo "> Extracting metadata... (this may take a while)"
	find "$SOURCE" -maxdepth 1 -not -path "*/$REPO_DIR/*" -not -wholename "$SOURCE" -not -name "$REPO_DIR" -exec echo -e {} \; | while read f; do
		find "$f" -type f -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | sed "s@$SOURCE@@" | xargs -I{} bash -c "exiftool \"$(realpath $SOURCE)/{}\" > \"$(realpath $REPO_PATH)/{}.txt\""
		echo "> > Added $(basename "$f") to working queue"
	done
}

function update-repo() {
	test ! -d "$REPO_PATH/.git" && git -C "$REPO_PATH" init && git config --global --add safe.directory "$REPO_PATH" && git config --global --add safe.directory "$REPO_TARGET_PATH"
	echo "Updating internal repo..."
	date > "$REPO_PATH/lastupdate"
	cp "$REPO_PATH/lastupdate" "$SOURCE/"
	git -C "$REPO_PATH" add . -v
	git -C "$REPO_PATH" commit -m "$(date)" -v
}

function copy-over() {
	GIT_DISCOVERY_ACROSS_FILESYSTEM=1
	echo "Copying over data..."
	echo "> Recreating directory tree..."
	find "$SOURCE" -type d -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | sed "s@$SOURCE@@" | xargs -I{} mkdir "$(realpath $TARGET)/{}" 2> /dev/null
	test ! -d "$REPO_TARGET_PATH" && mkdir "$REPO_TARGET_PATH"
	test ! -d "$REPO_TARGET_PATH/.git" && git -C "$REPO_TARGET_PATH" init && git config --global --add safe.directory "$REPO_TARGET_PATH" && git -C "$REPO_TARGET_PATH" config --local receive.denyCurrentBranch ignore && git -C "$REPO_TARGET_PATH" config --local pull.rebase false
	echo "> Pushing internal repo changes"
	git -C "$REPO_TARGET_PATH" remote add sourcerepo "$REPO_PATH"
	git -C "$REPO_TARGET_PATH" remote update
	git -C "$REPO_TARGET_PATH" fetch sourcerepo
	git -C "$REPO_TARGET_PATH" pull sourcerepo master
	echo "> Copying changes from source"
	set -e
	git -C "$REPO_TARGET_PATH" log -n 1 --name-status --pretty="" | xargs -I{} echo -e "{}\n" | grep -i "^D" | awk '{$1 = ""; print $0}' | sed 's/\.txt//g' | sed 's/"//g' | xargs -I{} rm -rfv "$(realpath $TARGET)/{}"
	git -C "$REPO_TARGET_PATH" log -n 1 --name-status --pretty="" | xargs -I{} echo -e "{}\n" | grep -i "^A" | awk '{$1 = ""; print $0}' | sed 's/\.txt//g' | sed 's/"//g' | xargs -I{} bash -c "cp -v \"$(realpath $SOURCE)/{}\" \"$(realpath $TARGET)/{}\""
	git -C "$REPO_TARGET_PATH" log -n 1 --name-status --pretty="" | xargs -I{} echo -e "{}\n" | grep -i "^M" | awk '{$1 = ""; print $0}' | sed 's/\.txt//g' | sed 's/"//g' | xargs -I{} bash -c "cp -v \"$(realpath $SOURCE)/{}\" \"$(realpath $TARGET)/{}\""
	find "$TARGET" -type d -empty -delete
	#cp -vr "$REPO_PATH/"* "$REPO_TARGET_PATH"
	#git -C "$REPO_TARGET_PATH" add .
	#git -C "$REPO_TARGET_PATH" commit -m "$(date)" -v
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

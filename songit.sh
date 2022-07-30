#!/usr/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
WHITE='\033[1;37m'
LGRAY='\033[0;37m'
DGRAY='\033[1;30m'
NC='\033[0m'

function generate-metadata() {
	echo -e "${LGRAY}> Removing outdated metadata...${NC}"
	mkdir "$REPO_PATH" 2> /dev/null
	find "$REPO_PATH" -type f -not -path "*/.git/*" -exec echo -e {} \; | sed 's/\.txt//g' | sed "s@$REPO_PATH@@" | xargs -I{} bash -c "echo -e \"${DGRAY}> > Looking at Directory ${GREEN}\$(dirname \"{}\")${DGRAY}...${NC}\" && if [ ! -f \"$(realpath "$SOURCE"){}\" ]; then echo > \"$(realpath "$REPO_PATH")/{}.txt\"; else (( \$(date -r \"$(realpath "$SOURCE")/{}\" +%s) >= \$(date -r \"$(realpath "$REPO_PATH")/{}.txt\" +%s) )) && echo > \"$(realpath $SOURCE)/{}.txt\"; fi" | uniq
	find "$REPO_PATH" -type d -empty -delete
	mkdir "$REPO_PATH" 2> /dev/null
	echo -e "${WHITE}Generating metadata...${NC}"
	echo -e "${LGRAY}> Recreating directory tree...${NC}"
	find "$SOURCE" -type d -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | sed "s@$SOURCE@@" | xargs -I{} mkdir "$REPO_PATH/{}" 2> /dev/null
	echo -e "${LGRAY}> Extracting metadata... (this may take a while)${NC}"
	find "$SOURCE" -maxdepth 1 -not -path "*/$REPO_DIR/*" -not -wholename "$SOURCE" -not -name "$REPO_DIR" -exec echo -e {} \; | while read -r d; do
	find "$d" -type f -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | sed "s@$SOURCE@@" | xargs -I{} bash -c "if [ ! -s \"$(realpath $REPO_PATH)/{}.txt\" ]; then echo -e \"${DGRAY}> > Regenerating ${GREEN}\$(basename \"{}\")${DGRAY}...${NC}\"; exiftool \"$(realpath "$SOURCE")/{}\" > \"$(realpath "$REPO_PATH")/{}.txt\"; fi"
		echo -e "${DGRAY}> > Added ${GREEN}$(basename "$d") to working queue${NC}"
	done
}

function update-repo() {
	test ! -d "$REPO_PATH/.git" && git -C "$REPO_PATH" init && git config --global --add safe.directory "$REPO_PATH" && git config --global --add safe.directory "$REPO_TARGET_PATH"
	echo -e "${WHITE}Updating internal repo...${NC}"
  echo "# \'$(basename $TARGET)\' Music Folder
> n.$(date +%s) update

---

$(find "$SOURCE" -type d -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | wc -l) Folders

$(find "$SOURCE" -type f -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | wc -l) Files

SHA1($(find "$SOURCE" -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum | awk '{print $1}'))" > "$(realpath $SOURCE)/README.md"
  exiftool "$(realpath '$SOURCE')/README.md" > "$(realpath '$REPO_PATH')/README.md.txt"
  git -C "$REPO_PATH" add . -v
	git -C "$REPO_PATH" commit -m "$(date)" -v
}

function copy-over() {
	export GIT_DISCOVERY_ACROSS_FILESYSTEM=1
	echo -e "${WHITE}Copying over data...${NC}"
	echo -e "${LGRAY}> Recreating directory tree...${NC}"
	find "$SOURCE" -type d -not -name "$REPO_DIR" -not -wholename "$REPO_PATH/*" -exec echo -e {} \; | sed "s@$SOURCE@@" | xargs -I{} mkdir "$(realpath "$TARGET")/{}" 2> /dev/null
	test ! -d "$REPO_TARGET_PATH" && mkdir "$REPO_TARGET_PATH"
	test ! -d "$REPO_TARGET_PATH/.git" && git -C "$REPO_TARGET_PATH" init && git config --global --add safe.directory "$REPO_TARGET_PATH" && git -C "$REPO_TARGET_PATH" config --local receive.denyCurrentBranch ignore && git -C "$REPO_TARGET_PATH" config pull.rebase false
	echo -e "${LGRAY}> Pushing internal repo changes${NC}"
	git -C "$REPO_TARGET_PATH" remote add sourcerepo "$REPO_PATH"
	git -C "$REPO_TARGET_PATH" remote update
	git -C "$REPO_TARGET_PATH" fetch sourcerepo
  git -C "$REPO_TARGET_PATH" pull --no-rebase sourcerepo master
  echo -e "${LGRAY}> Copying changes from source${NC}"
	set -e
	git -C "$REPO_TARGET_PATH" log -n 1 --name-status --pretty="" | xargs -I{} echo -e "{}\n" | grep -i "^D" | awk '{$1 = ""; print $0}' | sed 's/\.txt//g' | sed 's/"//g' | xargs -I{} rm -rfv "$(realpath "$TARGET")/{}"
	git -C "$REPO_TARGET_PATH" log -n 1 --name-status --pretty="" | xargs -I{} echo -e "{}\n" | grep -i "^A" | awk '{$1 = ""; print $0}' | sed 's/\.txt//g' | sed 's/"//g' | xargs -I{} bash -c "cp -v \"$(realpath "$SOURCE")/{}\" \"$(realpath "$TARGET")/{}\""
	git -C "$REPO_TARGET_PATH" log -n 1 --name-status --pretty="" | xargs -I{} echo -e "{}\n" | grep -i "^M" | awk '{$1 = ""; print $0}' | sed 's/\.txt//g' | sed 's/"//g' | xargs -I{} bash -c "cp -v \"$(realpath "$SOURCE")/{}\" \"$(realpath "$TARGET")/{}\""
	find "$TARGET" -type d -empty -delete
	#cp -vr "$REPO_PATH/"* "$REPO_TARGET_PATH"
	#git -C "$REPO_TARGET_PATH" add .
	#git -C "$REPO_TARGET_PATH" commit -m "$(date)" -v
}

SOURCE=$1
test -z "$SOURCE" && exit

TARGET=$2
test -z "$TARGET" && exit

if [ -f .env ]; then
	export "$(cat .env | xargs)"
else
	REPO_DIR=".songit"
fi

REPO_PATH=$(realpath "$SOURCE")/$REPO_DIR
REPO_TARGET_PATH=$(realpath "$TARGET")/$REPO_DIR

generate-metadata
update-repo
copy-over

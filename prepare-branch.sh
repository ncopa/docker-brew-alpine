#!/bin/sh -e


prepare() {
	local branch="$1"
	local dir=$(mktemp -d /tmp/docker-brew-alpine-XXXXXX)
	docker build -t docker-brew-alpine-fetch .
	docker run --user $(id -u) --rm -it -v $dir:/out docker-brew-alpine-fetch $branch /out
	echo "=> Verifying checksums"
	( cd $dir && sha512sum -c checksums.sha512)
	echo "=> temp dir: $dir"
	echo "=> To create git branch run:"
	echo ""
	echo "  $0 branch $branch $dir"
	echo ""
}

branch() {
	local branch="$1"
	local dir="$2"
	local version=$(cat $dir/VERSION)
	if [ -z "$dir" ]; then
		help
		exit 1
	fi
	echo "=> Creating branch for release $version from $dir"

	if [ -n "$(git status --porcelain)" ]; then
		echo "=> git status is not clean. Aborting"
		git status --porcelain
		exit 1
	fi

	git checkout master
	git branch -D "$branch" || true
	git checkout --orphan "$branch"
	git rm --cached -r .
	rm -fr ./*
	mv "$dir"/* .
	rmdir "$dir"
	git add *
	git commit -m "Update Alpine $branch - $version"

	echo "=> Branch created:"
	echo ""
	echo "=> To upload release do: git push -f origin $branch"
	library "$branch"
	echo ""
	echo "=> After 'git push -f origin $branch', add the above to:"
	echo "=> https://github.com/docker-library/official-images/blob/master/library/alpine"
	git checkout master
}

library_arch() {
	case "$1" in
	armhf) echo "arm32v6";;
	armv7) echo "arm32v7";;
	aarch64) echo "arm64v8";;
	ppc64le) echo "ppc64le";;
	s390x) echo "s390x";;
	x86) echo "i386";;
	x86_64) echo "amd64";;
	*) echo "Unknown architecture: $1" >&2; exit 1;;
	esac
}

library() {
	local branch="$1"
	local arches= dirs=
	for file in */Dockerfile; do
		local a=${file%/Dockerfile}
		arches="${arches}${arches:+, }$(library_arch $a)"
		dirs="$dirs $a"
	done
	cat <<-EOF

		Tags: $branch
		Architecture: $arches
		GitFetch: refs/heads/$branch
		GitCommit: $(git rev-parse HEAD)
	EOF
	for dir in $dirs; do
		echo "$(library_arch $dir)-Directory: $dir/"
	done
}

help() {
	cat <<EOF
Usage: $0 COMMAND [OPTS]

Commands:

 prepare [BRANCH]   - fetch release latest minirootfs to a temp directory and
                      create Dockerfiles

 branch BRANCH DIR  - update git branch with previously prepared temp
                      directory

 library BRANCH     - Print metadata for:
                      https://github.com/docker-library/official-images
EOF
}

cmd=$1
shift

branch=${1:-edge}
dir="$2"

case "$cmd" in
	prepare) prepare "$branch";;
	branch)  branch "$branch" "$dir";;
	library) library "$branch";;
	*) help $0;;
esac



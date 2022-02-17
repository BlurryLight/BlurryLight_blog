#!/bin/bash

echo "clone all history for .GitInfo...\n\r"
git pull --unshallow
git checkout pages-src
git pull origin pages-src

ls -al
echo "build hugo\n\r"
chmod +x hugo
./hugo --enableGitInfo

exit 0

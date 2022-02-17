#!/bin/bash

echo "clone all history for .GitInfo...\n\r"
git clone https://github.com/BlurryLight/BlurryLight_blog.git
cd BlurryLight_blog
ls -al

echo "build hugo\n\r"
chmod +x ../hugo
../hugo --enableGitInfo 
mv public ../public

exit 0

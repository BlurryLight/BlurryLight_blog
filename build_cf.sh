#!/bin/bash

echo "clone all history for .GitInfo...\n\r"
git pull --unshallow
git checkout master

ls
echo "build hugo\n\r"
hugo

exit 0

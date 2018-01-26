#!/bin/bash

DEST="${@:${#@}}"
ABS_DEST="$(cd "$(dirname "$DEST")"; pwd)/$(basename "$DEST")"
set -x

for SRC in ${@:1:$((${#@} -1))}; do(
	cd $SRC
    diff=`diff -rq . $ABS_DEST | grep 'Only'`
 ) done
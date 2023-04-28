#!/bin/bash
# Simply a wrapper script to keep you from having to use betty-style
# and betty-doc separately on every item.
# Originally by Tim Britton (@wintermanc3r), multiargument added by
# Larry Madeo (@hillmonkey)
# Support for termux on non-rooted devices by Junior Ohanyere

BIN_PATH="/usr/local/bin"
BETTY_STYLE="betty-style"
BETTY_DOC="betty-doc"

TERMUX_HOME_PATH="/data/data/com.termux/files/home"
TERMUX_BIN_PATH="/data/data/com.termux/files/usr/bin"

if [[ $HOME = ${TERMUX_HOME_PATH} ]]
then
        BIN_PATH=${TERMUX_BIN_PATH}
fi

if [ "$#" = "0" ]; then
	echo "No arguments passed."
	exit 1
fi

for argument in "$@" ; do
    echo -e "\n========== $argument =========="
    ${BIN_PATH}/${BETTY_STYLE} "$argument"
    ${BIN_PATH}/${BETTY_DOC} "$argument"
done

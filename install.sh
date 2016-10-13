#!/bin/bash

if [ "$(id -u)" != "0" ]
then
	echo "Sorry, you are not root."
	exit 1
fi

BETTY_STYLE="betty-style"
BETTY_DOC="betty-doc"

BIN_PATH="/usr/local/bin"
MAN_PATH="/usr/local/share/man/man1"

echo -e "Installing binaries.."

cp "${BETTY_STYLE}.pl" "${BIN_PATH}/betty-style"
cp "${BETTY_DOC}.pl" "${BIN_PATH}/betty-doc"

echo -e "Installing man pages.."

mkdir -p "${MAN_PATH}"

cp "man/${BETTY_STYLE}.1" "${MAN_PATH}"
cp "man/${BETTY_DOC}.1" "${MAN_PATH}"

echo -e "Updating man database.."

mandb

echo -e "All set."

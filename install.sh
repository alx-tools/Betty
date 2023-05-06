#!/bin/bash

BETTY_STYLE="betty-style"
BETTY_DOC="betty-doc"
BETTY_WRAPPER="betty"

APP_PATH="/opt/betty"
BIN_PATH="/usr/local/bin"
MAN_PATH="/usr/local/share/man/man1"

TERMUX_HOME_PATH="/data/data/com.termux/files/home"
TERMUX_APP_PATH="/data/data/com.termux/files/opt/betty"
TERMUX_BIN_PATH="/data/data/com.termux/files/usr/bin"
TERMUX_MAN_PATH="/data/data/com.termux/files/usr/share/man/man1"

if [[ $HOME = ${TERMUX_HOME_PATH} ]]
then

	APP_PATH=${TERMUX_APP_PATH}
	BIN_PATH=${TERMUX_BIN_PATH}
	MAN_PATH=${TERMUX_MAN_PATH}

elif [ "$(id -u)" != "0" ]
then
	echo "Sorry, you are not root."
	exit 1
fi

echo -e "Installing perl.."

apt install perl

echo -e "Installing binaries.."

mkdir -p "${APP_PATH}"

cp "${BETTY_STYLE}.pl" "${APP_PATH}/${BETTY_STYLE}"
cp "${BETTY_DOC}.pl" "${APP_PATH}/${BETTY_DOC}"
cp "${BETTY_WRAPPER}.sh" "${APP_PATH}/${BETTY_WRAPPER}"

chmod +x "${APP_PATH}/${BETTY_STYLE}"
chmod +x "${APP_PATH}/${BETTY_DOC}"
chmod +x "${APP_PATH}/${BETTY_WRAPPER}"

ln -s "${APP_PATH}/${BETTY_STYLE}" "${BIN_PATH}/${BETTY_STYLE}"
ln -s "${APP_PATH}/${BETTY_DOC}" "${BIN_PATH}/${BETTY_DOC}"
ln -s "${APP_PATH}/${BETTY_WRAPPER}" "${BIN_PATH}/${BETTY_WRAPPER}"

echo -e "Installing man pages.."

mkdir -p "${MAN_PATH}"

cp "man/betty.1" "${MAN_PATH}"
cp "man/${BETTY_STYLE}.1" "${MAN_PATH}"
cp "man/${BETTY_DOC}.1" "${MAN_PATH}"

echo -e "Updating man database.."

mandb

echo -e "All set."

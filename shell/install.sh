#!/bin/sh

set -ue

# (c) Copyright Fabrice Le Fessant INRIA/OCamlPro 2013
# (c) Copyright Louis Gesbert OCamlPro 2014-2017

VERSION='2.0.0~rc4'
TAG=$(echo "$VERSION" | tr '~' '-')
DEFAULT_BINDIR=/usr/local/bin

usage() {
    echo "opam binary installer v.$VERSION"
    echo "Downloads and installs a pre-compiled binary of opam $VERSION to the system."
    echo "This can also be used to switch between opam versions"
    echo
    echo "Options:"
    echo "    --no-backup            Don't attempt to backup the current opam root"
    echo "    --backup               Force the backup the current opam root (even if it"
    echo "                           is from the 2.0 branch already)"
    echo "    --fresh                Create the opam $VERSION root from scratch"
    echo "    --restore   VERSION    Restore a backed up opam binary and root"
    echo
    echo "The default is to backup if the current version of opam is 1.*, or when"
    echo "using '--fresh'"
}

RESTORE=
NOBACKUP=
FRESH=

while [ $# -gt 0 ]; do
    case "$1" in
        --restore)
            if [ $# -lt 2 ]; then echo "Option $1 requires an argument"; exit 2; fi
            shift;
            RESTORE=$1;;
        --no-backup)
            NOBACKUP=1;;
        --backup)
            NOBACKUP=0;;
        --fresh)
            FRESH=1;;
        --help|-h)
            usage; exit 0;;
        *)
            usage; exit 2;;
    esac
    shift
done

EXISTING_OPAM=$(command -v opam || echo)
EXISTING_OPAMV=
if [ -n "$EXISTING_OPAM" ]; then
   EXISTING_OPAMV=$("$EXISTING_OPAM" --version || echo "unknown")
fi

FRESH=${FRESH:-0}

OPAMROOT=${OPAMROOT:-$HOME/.opam}

if [ ! -d "$OPAMROOT" ]; then FRESH=1; fi

if [ -z "$NOBACKUP" ] && [ ! "$FRESH" = 1 ] && [ -z "$RESTORE" ]; then
    case "$EXISTING_OPAMV" in
        2.*) NOBACKUP=1;;
        *) NOBACKUP=0;;
    esac
fi

xsudo() {
    local CMD=$1; shift
    local DST
    for DST in "$@"; do : ; done

    local DSTDIR=$(dirname "$DST")
    if [ ! -w "$DSTDIR" ]; then
        echo "Write access to $DSTDIR required, using 'sudo'."
        echo "Command: $CMD $@"
        if [ "$CMD" = "install" ]; then
            sudo "$CMD" -g 0 -o root "$@"
        else
            sudo "$CMD" "$@"
        fi
    else
        "$CMD" "$@"
    fi
}

if [ -n "$RESTORE" ]; then
    OPAM=$(command -v opam)
    OPAMV=$("$OPAM" --version)
    OPAM_BAK="$OPAM.$RESTORE"
    OPAMROOT_BAK="$OPAMROOT.$RESTORE"
    if [ ! -e "$OPAM_BAK" ] || [ ! -d "$OPAMROOT_BAK" ]; then
        echo "No backup of opam $RESTORE was found"
        exit 1
    fi
    if [ "$NOBACKUP" = 1 ]; then
        printf "## This will clear $OPAM and $OPAMROOT. Continue ? [Y/n] "
        read R
        case "$R" in
            ""|"y"|"Y"|"yes")
                xsudo rm -f "$OPAM"
                rm -rf "$OPAMROOT";;
            *) exit 1
        esac
    else
        xsudo mv "$OPAM" "$OPAM.$OPAMV"
        mv "$OPAMROOT" "$OPAMROOT.$OPAMV"
    fi
    xsudo mv "$OPAM_BAK" "$OPAM"
    mv "$OPAMROOT_BAK" "$OPAMROOT"
    printf "## Opam $RESTORE and its root were restored."
    if [ "$NOBACKUP" = 1 ]; then echo
    else echo " Opam $OPAMV was backed up."
    fi
    exit 0
fi

TMP=${TMPDIR:-/tmp}

ARCH=$(uname -m || echo unknwon)
case "$ARCH" in
    x86|i?86) ARCH="i686";;
    x86_64|amd64) ARCH="x86_64";;
    ppc|powerpc|ppcle) ARCH="ppc";;
    aarch64_be|aarch64|armv8b|armv8l) ARCH="arm64";;
    armv5*|armv6*|earmv6*|armv7*|earmv7*) ARCH="armhf";;
    *) ARCH=$(echo "$ARCH" | awk '{print tolower($0)}')
esac

OS=$(uname -s || echo unknown)
case "$OS" in
    darwin|macos) OS=darwin;;
    *) OS=$(echo "$OS" | awk '{print tolower($0)}')
esac

OPAM_BIN="opam-${TAG}-${ARCH}-${OS}"
OPAM_BIN_URL="https://github.com/ocaml/opam/releases/download/${TAG}/${OPAM_BIN}"

download() {
    if command -v wget >/dev/null; then wget -q -O "$@"
    else curl -s -L -o "$@"
    fi
}

bin_sha512() {
  case "$OPAM_BIN" in
    opam-2.0.0-rc4-amd64-openbsd) echo "634553e49c34f5095c4e7ee8493ab3100c007d9fafad87eaa3948dbc8089801e8b28ef6f27e27521292c1c382307737e603e6504350dae850ff558bd2ece7372";;
    opam-2.0.0-rc4-arm64-linux) echo "7c31ce2916f79e42ea0b2b3bdfa218b01488730fc628be3fce5d3fc6a03c836dbc124a85dd628c96c72e8344a70d0322e41d4ed8941c96be815956d072d6c563";;
    opam-2.0.0-rc4-armhf-linux) echo "9d59f15f7712e8aa623e63206f073664dcefba810d6d767916993517d4c83c4a9724670663b73a243e0e55beb19222a2c18652a30158cd4811579a5e48ef3bfd";;
    opam-2.0.0-rc4-i686-linux) echo "f016693c193a01a21c574a642abf16b3090d0b79c2ac1555d8c74d2d5baa6f346796ba3ade28b937ac8789d91ad806d45cb3027a36423f26cb166fdc6713cf09";;
    opam-2.0.0-rc4-x86_64-darwin) echo "a15ad48695e59a5b00c49e451ea060e4eba9feeaba34b91864ed81db2a944eeba5190d6d3fb5b17ce04a1ebb4f1c89251c9249db95008b3a53b663f0d1690d39";;
    opam-2.0.0-rc4-x86_64-linux) echo "42fb43fc73e61817e1c19f6d6220dbcee000e97b7eb40ba825a6ef8fe0121f385bb18f4d5fcd47a2f95ca11237ce29a7e07f61fc231c5b8bc5fc0c28ec172d71";;
    *) echo "no sha";;
  esac
}

check_sha512() {
  if command -v openssl > /dev/null; then
    sha512_devnull="cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
    sha512_check=`openssl sha512 2>&1 < /dev/null | cut -f 2 -d ' '`
    if [ "x$sha512_devnull" = "x$sha512_check" ]; then
      sha512=`openssl sha512 "$TMP/$OPAM_BIN" 2> /dev/null | cut -f 2 -d ' '`
      check=`bin_sha512`
      test "x$sha512" = "x$check"
    else
      echo "openssl 512 option not handled, binary integrity check can't be performed."
      return 0
    fi
  else
    echo "openssl not found, binary integrity check can't be performed."
    return 0
  fi
}

if [ -e "$TMP/$OPAM_BIN" ] && ! check_sha512 || [ ! -e "$TMP/$OPAM_BIN" ]; then
    echo "## Downloading opam $VERSION for $OS on $ARCH..."

    if ! download "$TMP/$OPAM_BIN" "$OPAM_BIN_URL"; then
        echo "There may not yet be a binary release for your architecture or OS, sorry."
        echo "See https://github.com/ocaml/opam/releases/tag/$TAG for pre-compiled binaries,"
        echo "or run 'make cold' from https://github.com/ocaml/opam/archive/$TAG.tar.gz"
        echo "to build from scratch"
        exit 10
    else
        if check_sha512; then
            echo "## Downloaded."
        else
            echo "Checksum mismatch, a problem occured during download."
            exit 10
        fi
    fi
else
    echo "## Using already downloaded \"$TMP/$OPAM_BIN\""
fi

if [ -n "$EXISTING_OPAM" ]; then
    DEFAULT_BINDIR=$(dirname "$EXISTING_OPAM")
fi

while true; do
    printf "## Where should it be installed ? [$DEFAULT_BINDIR] "
    read BINDIR
    if [ -z "$BINDIR" ]; then BINDIR="$DEFAULT_BINDIR"; fi

    if [ -d "$BINDIR" ]; then break
    else
        printf "## $BINDIR does not exist. Create ? [Y/n] "
        read R
        case "$R" in
            ""|"y"|"Y"|"yes")
            mkdir -p $BINDIR
            break;;
        esac
    fi
done

if [ -e "$EXISTING_OPAM" ]; then
    if [ "$NOBACKUP" = 1 ]; then
        xsudo rm -f "$EXISTING_OPAM"
    else
        xsudo mv "$EXISTING_OPAM" "$EXISTING_OPAM.$EXISTING_OPAMV"
        echo "## $EXISTING_OPAM backed up as $(basename $EXISTING_OPAM).$EXISTING_OPAMV"
    fi
fi

if [ -d "$OPAMROOT" ]; then
    if [ "$FRESH" = 1 ]; then
        if [ "$NOBACKUP" = 1 ]; then
            printf "## This will clear $OPAMROOT. Continue ? [Y/n] "
            read R
            case "$R" in
                ""|"y"|"Y"|"yes")
                    rm -rf "$OPAMROOT";;
                *) exit 1
            esac
        else
            mv "$OPAMROOT" "$OPAMROOT.$EXISTING_OPAMV"
            echo "## $OPAMROOT backed up as $(basename $OPAMROOT).$EXISTING_OPAMV"
        fi
        echo "## opam $VERSION installed. Please run 'opam init' to get started"
    elif [ ! "$NOBACKUP" = 1 ]; then
        echo "## Backing up $OPAMROOT to $(basename $OPAMROOT).$EXISTING_OPAMV (this may take a while)"
        if [ -e "$OPAMROOT.$EXISTING_OPAMV" ]; then
            echo "ERROR: there is already a backup at $OPAMROOT.$EXISTING_OPAMV"
            echo "Please move it away or run with --no-backup"
        fi
        FREE=$(df -k "$OPAMROOT" | awk 'NR>1 {print $4}')
        NEEDED=$(du -sk "$OPAMROOT" | awk '{print $1}')
        if ! [ $NEEDED -lt $FREE ]; then
            echo "Error: not enough free space to backup. You can retry with --no-backup,"
            echo "--fresh, or remove '$OPAMROOT'"
            exit 1
        fi
        cp -a "$OPAMROOT" "$OPAMROOT.$EXISTING_OPAMV"
        echo "## $OPAMROOT backed up as $(basename $OPAMROOT).$EXISTING_OPAMV"
    fi
    rm -f "$OPAMROOT"/repo/*/*.tar.gz*
fi

xsudo install -m 755 "$TMP/$OPAM_BIN" "$BINDIR/opam"
echo "## opam $VERSION installed to $BINDIR"

if [ ! "$FRESH" = 1 ]; then
    echo "## Converting the opam root format & updating"
    "$BINDIR/opam" init --reinit -ni
fi

WHICH=$(command -v opam || echo notfound)

case "$WHICH" in
    "$BINDIR/opam") ;;
    notfound) echo "## Remember to add $BINDIR to your PATH";;
    *)
        echo "## WARNING: 'opam' command found in PATH does not match the installed one:"
        echo "   - Installed: '$BINDIR/opam'"
        echo "   - Found:     '$WHICH'"
        echo "Make sure to remove the second or fix your PATH to use the new opam"
        echo
esac

if [ ! "$NOBACKUP" = 1 ]; then
    echo "## Run this script again with '--restore $EXISTING_OPAMV' to revert."
fi

rm -f $TMP/$OPAM_BIN

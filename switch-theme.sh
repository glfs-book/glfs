#!/bin/sh
case "$1" in
  light)
    ln -sfv light.lfs.css stylesheets/lfs-xsl/lfs.css
    ;;
  dark)
    ln -sfv dark.lfs.css stylesheets/lfs-xsl/lfs.css
    ;;
  nightdrive)
    ln -sfv nightdrive.lfs.css stylesheets/lfs-xsl/lfs.css
    ;;
  whitepink)
    ln -sfv whitepink.lfs.css stylesheets/lfs-xsl/lfs.css
    ;;
  *)
    echo 'Invalid theme!' >&2
    exit 1
    ;;
esac

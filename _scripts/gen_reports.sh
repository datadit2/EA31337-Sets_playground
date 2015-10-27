#!/usr/bin/env bash
set -e
type ex || exit 1
type html2text || exit 1

ROOT=$(git rev-parse --show-toplevel)
OUT="README.md.new"

find ~/.wine/drive_c -type f -name Report*.htm -exec html2text {} >> $OUT ';'

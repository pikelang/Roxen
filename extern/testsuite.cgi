#!/bin/sh
if test "x$INPUT" = "x" ; then
  exit 1
else
  cat "$INPUT"
fi

#/bin/sh
#
# $Id: mk_wxs_modules.sh,v 1.1 2004/11/09 17:48:04 grubba Exp $
#
# Make a set of Windows Installer XML source module files
# from a typical roxen module layout.
#
# 2004-11-03 Henrik Grubbström
#

if [ "$#" = "2" ]; then :; else
  echo "Usage:" >&2
  echo "  $0 <base_name> <directory>" >&2
  exit 1
fi

# FIXME
version="1.0.0"

base="$1"
dir="$2"

if [ -d "$dir/." ]; then :; else
  echo "$2 is not a directory." >&2
  exit 1
fi

# Check if there's anything else we need to make a module out of.
root_files=""
server_dirs=""
for f in `cd "$dir" && echo *`; do
  case "$f" in
    server*)
      if [ -d "$dir/$f/." ]; then
        server_dirs="$server_dirs "`echo '"'".:$dir/$f"'"'|sed -e 's/"/\\"/'`
      else
        root_files="$root_files "`echo '"'"$f:$dir/$f"'"'|sed -e 's/"/\\"/'`
      fi
    ;;
    *)
      root_files="$root_files "`echo '"'"$f:$dir/$f"'"'|sed -e 's/"/\\"/'`
    ;;
  esac
done

if [ "$server_dirs" = "" ]; then :; else
  echo server_dirs: $server_dirs

  $PIKE -x make_wxs -v$version -m "Roxen Internet Software" -i Foo \
    $server_dirs >"$base"_server.wxs || \
    ( cat "$base"_server.wxs >&2; exit 1)

  sprsh candle -nologo "$base"_server.wxs
  sprsh light -nologo "$base"_server.wixobj
fi

if [ "$root_files" = "" ]; then :; else
  echo root_files: $root_files

  $PIKE -x make_wxs -v$version -m "Roxen Internet Software" -i Foo \
    $root_files >"$base"_root.wxs || \
    ( cat "$base"_root.wxs >&2; exit 1)

  sprsh candle -nologo "$base"_root.wxs
  sprsh light -nologo "$base"_root.wixobj
fi

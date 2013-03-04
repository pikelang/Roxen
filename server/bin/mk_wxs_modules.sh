#/bin/sh
#
# $Id$
#
# Make a set of Windows Installer XML source module files
# from a typical roxen module layout.
#
# 2004-11-03 Henrik Grubbström
#

version="1.0.0"

if [ "$1" = "-v" ]; then
  # FIXME: Improve option parsing...
  shift
  version="$1"
  shift
fi

if [ "$#" = "2" ]; then :; else
  echo "Usage:" >&2
  echo "  $0 [-v <version>] <base_name> <directory>" >&2
  exit 1
fi

if [ "$PIKE" = "" ]; then 
  if type pike >/dev/null 2>&1; then 
    PIKE=pike
  else 
    echo "No pike binary found." >&2 
    exit 1 
  fi 
fi 
export PIKE
 
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

  eval "$PIKE" -x make_wxs -v$version -m '"Roxen Internet Software"' -i Foo \
    "$server_dirs" >"$base"_server.wxs || \
    ( cat "$base"_server.wxs >&2; exit 1) || exit 1

  sprsh candle -nologo "$base"_server.wxs -out "$base"_server.wixobj || exit 1
  sprsh light -nologo "$base"_server.wixobj -o "$base"_server.msm || exit 1
fi

if [ "$root_files" = "" ]; then :; else
  echo root_files: $root_files

  eval "$PIKE" -x make_wxs -v$version -m '"Roxen Internet Software"' -i Foo \
    "$root_files" >"$base"_root.wxs || \
    ( cat "$base"_root.wxs >&2; exit 1) || exit 1

  sprsh candle -nologo "$base"_root.wxs -out "$base"_root.wixobj || exit 1
  sprsh light -nologo "$base"_root.wixobj -o "$base"_root.msm || exit 1
fi

#!/bin/bash
set -eo pipefail

# Syncronise sequencing data to a remote backup.
# At present the remote backup should be a mounted
# network drive, instead of a true rsync remote command
#  J. Healey 10-08-18

usage(){
# Usage/help dialogue

# tput used for cat output colours as ANSI escape
# codes cannot be used.
tr=$(tput setaf 1) # text = red
df=$(tput sgr0)    # text = reset
cat << EOF >&2
This script handles synchronisation of data from our MiSeq platform.

usage: $0 [options] -s source -d destination
OPTIONS:
   -h | --help          Show this message
   -s | --source        The source directory of data to synchronise
   -d | --destination   Destination to synchronise data to. This should
                        be a local folder or mapped/mounted drive.

The source should be the parent directory of the data to syncronise.
e.g:
+-- ../
  +-- Data/  < Pass this filepath
    +-- 01012000_M01757_0123_000000000-ABCDE/

EOF
}

for arg in "$@"; do
  shift
  case "$arg" in
        "--help")        set -- "$@" "-h"   ;;
        "--source")      set -- "$@" "-s"   ;;
        "--destination") set -- "$@" "-d"   ;;
        *)               set -- "$@" "$arg" ;;
  esac
done
while getopts "hd:s:" OPTION ; do
  case $OPTION in
       s) source=$OPTARG       ;;
       d) destination=$OPTARG  ;;
       h) usage ; exit 0       ;;
  esac
done

log(){
# Logging function.
# Prints to STDOUT in WHITE
echo -e >&1 "\e[4;39mINFO:\e[0m \e[39m$1\e[0m"
}

err(){
# Error function
# Prints to STDERR in RED
echo -e >&2 "\e[4;31mERROR:\e[0m \e[31m$1\e[0m"
}

warn(){
# Warning function
# Prints to STDOUT in YELLOW/ORANGE
echo -e >&1 "\033[4;33mWARNING:\e[0m \e[33m$1\033[0m"
}

timer(){
# Timer function.
# Reports REAL time elapsed in hours/minutes/seconds as appropriate
# Code to be timed should be wrapped as follows:
#  1.  START=$SECONDS
#  2.  <execute timed code>
#  3.  FINISH=$SECONDS
#  4.  echo "Elapsed: $(timer)
# Uses the SECONDS environment variable
hrs="$((($FINISH - $START)/3600)) hrs"
min="$(((($FINISH - $START)/60)%60)) min"
sec="$((($FINISH - $START)%60)) sec"

if [[ $(($FINISH - $START)) -gt 3600 ]]; then echo -e >&1 "\033[1m$hrs, $min, $sec\033[0m"
elif [[ $(($FINISH - $START)) -gt 60 ]]; then echo -e >&1 "\033[1m$min, $sec\033[0m"
else echo -e >&1 "\033[1m$sec\033[0m"
fi
}

abspath() {
# Return the absolute path of a relative path
# Relative path = $1
if [ -d "$1" ]; then
  (cd "$1"; pwd)
elif [ -f "$1" ]; then
  if [[ $1 = /* ]]; then
    echo "$1"
  elif [[ $1 == */* ]]; then
    echo "$(cd "${1%/*}"; pwd)/${1##*/}"
  else
    echo "$(pwd)/$1"
  fi
fi
}

# ENsure source dir exists and is a dir
if [[ -z "$source" ]] || [[ ! -d "$source" ]] ; then
 usage
 err "No source directory was provided or the directory doesn't exist. Exiting." ; exit 1
fi
# Ensure target dir exists and is a dir
if [[ -z "$destination" ]] || [[ ! -d "$destination" ]] ; then
 usage
 err "No destination directory was provided or the directory doesn't exist. Exiting." ; exit 1
fi

################################################################
echo "--------------------------------------------------"
log "Run date: $(date '+%Y-%m-%d %H:%M:%S')"
log "Parameters:"
log "  Source directory: $source ($(abspath $source))"
log "  Destination directory: $destination ($(abspath $destination))"
################################################################

log "Starting rsync..."
START="$SECONDS"
log "rsync transfer stats:"
rsync --stats -avhP $(abspath $source)/*.tar.gz $(abspath $destination) | sed 's/^/       /'
FINISH="$SECONDS"
log "Sychronisation finished in $(timer)..."

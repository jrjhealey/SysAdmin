#!/bin/bash
set -eo pipefail

# Loop through directories of sequencing data
# and compress them if they haven't been already.
# Hard drives aren't free!
#  J. Healey 01-08-18
#   - Updated 21-08-18:
#     Switched to getopts for argument handling
#     since the code had become more complex

usage(){
# Usage/help dialogue

# tput used for cat output colours as ANSI escape
# codes cannot be used.
tr=$(tput setaf 1) # text = red
df=$(tput sgr0)    # text = reset
cat << EOF >&2
This script compresses data from our MiSeq platform.
In future it may be generalised to support all formats.

usage: $0 [options] data_folder

OPTIONS:
   -h | --help        Show this message
   -d | --dry-run     Run the program without making changes to
                      any files (see description below)
   -k | --keep-img    If the data folders contain images from the
                      sequencing process, they will be kept if this
                      argument is provided, otherwise they will be
                      removed to conserve space (they are unecessary
                      if the basecalls/fastqs are already available)

The only mandatory argument is the directory of data, and this must be
the last positonal argument. This should be a directory of directories,
e.g:

+-- ../
  +-- Data/  < Pass this filepath
    +-- 01012000_M01757_0123_000000000-ABCDE/

Optionally, the script can be dry run to avoid changing the files,
instead, just printing out what will be changed.

              ${tr}[OFF by defaut]${df}

Also optionally the script can purge unecessary and large image files
(.jpg/.tif), before compressing since only the basecalls/fastqs are
really needed, and these cause considerable slow down/space usage.

              ${tr}[ON by default]${df}

EOF
}

# Defaults and globals
CURDIR=$(pwd)
discard="True"
dryrun="False"

# Tolerate long arguments
for arg in "$@"; do
  shift
  case "$arg" in
        "--help")     set -- "$@" "-h"   ;;
        "--dry-run")  set -- "$@" "-d"   ;;
        "--keep-img") set -- "$@" "-k"   ;;
        *)            set -- "$@" "$arg" ;;
  esac
done
# getopts assigns the arguments to variables
while getopts "hdk" OPTION ;do
  case $OPTION in
        d) dryrun="True"    ;;
        k) discard="False"  ;;
        h) usage ; exit 0   ;;
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

targetdir=${@:$OPTIND:1}
# Ensure target dir exists and is a dir
if [[ -z "$targetdir" ]] || [[ ! -d "$targetdir" ]] ; then
 usage
 err "No target directory was provided or the directory doesn't exist. Exiting." ; exit 1
fi

################################################################
echo "--------------------------------------------------"
log "Run date: $(date '+%Y-%m-%d %H:%M:%S')"
log "Parameters:"
log "  Dry run status: $dryrun"
log "  Purging images?: $discard"
log "  Data directory: $targetdir ($(abspath $targetdir))"

if [ "$dryrun" == "True" ] ; then
  warn "With --dry-run enabled, be aware that the elapsed timings of the program will be meaningless..."
fi

cd "$targetdir"

# First test to see if there are any untarred files (stops after 1st occurrence of a suitable directory for speed)
if [[ -z $(find ./ -maxdepth 1 -type d -name "*[0-9][0-9][0-1][0-9][0-9][0-9]_M01757*" -print -quit) ]] ; then
 warn "Nothing to do - no suitably named directories were found. Maybe everything is already compressed? Otherwise double check your options. Exiting." ; exit 1
fi

log "Moved to target directory. ($(abspath $targetdir))"
# Main file loop begins
# Match directories with the beginning format of an illumina directory
find ./ -maxdepth 1 -type d -name "*[0-9][0-9][0-1][0-9][0-9][0-9]_M01757*" -print0 | while read -d $'\0' dir
do
 # Ensure no pre-existing tar.gz file is present for each directory
  if [[ ! -f "${dir%/}.tar.gz" ]] ; then

    log "No pre-existing archive found for ${dir}..."
    log "A new archive will be created..."
 # If perfoming a dry run, enter conditional
    if [ "$dryrun" == "True" ] ; then
      log "Dry run requested..."
 # If image purging is requested, enter conditional
      if [ "$discard" == "True" ] ; then
        log "Image purging requested. The following items would be discarded..."
        find ./ -type f \( -name "*.jpg" -or -name "*.tif" \)
      else
        log "No purging requested..."
      fi
      # If dry run is true, but image files are kept (no purging)
      echo "tar czvf ${dir%/}.tar.gz $dir --remove-files"

    else # If dry run False
     # Discard images if requested
      if [ "$discard" == "True" ] ; then
        START="$SECONDS"
        find ./ -type f \( -name "*.jpg" -or -name "*.tif" \) -exec rm {} +
        FINISH="$SECONDS"
        warn "Purged image files in $(timer)..."
      else
        log "No image purging requested..."
      fi
      START="$SECONDS"
      tar czf "${dir%/}".tar.gz "$dir" --remove-files
      FINISH="$SECONDS"
      tarsize=$(bc <<<"scale=4; $(wc -c <"${dir%/}".tar.gz) /1024^3")
      # Here's a neat command that could be used to show a progress bar if wanted in future
      #   tar cf - "${dir}" -P | pv -s $(du -sb "${dir}" | awk '{print $1}') | gzip > "${dir%/}".tar.gz
      log "Created $tarsize GB archive in $(timer)..."
    fi
# Else if a directory already has a counterpart archive, remove it
  else
    warn "There is already an existing archive which appears to correspond to ${dir}. Archive creation will be skipped and the directory removed..."
    START="$SECONDS"
    if [ "$dryrun" == "True" ] ; then
      log "Dry run requested..."
      echo "rm -r ${dir}"
    else
      rm -r "${dir}"
    fi
    FINISH="$SECONDS"
    warn "Removed uncompressed folder in $(timer)..."
  fi
done

cd "$CURDIR"
log "Moved back to previous directory, now in $(pwd)..."

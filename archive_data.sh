#!/bin/bash

# Loop through directories of sequencing data
# and compress them if they haven't been already.
# Hard drives aren't free!
# J. Healey 01-08-18

# Exit if any unhandled errors occur
set -eo pipefail

# Initial vars
curdir=$(pwd)
targetdir="$1"

usage(){
# Usage/help dialogue

# tput used for cat output colours as ANSI escape
# codes cannot be used.
tr=$(tput setaf 1) # text = red
df=$(tput sgr0)    # text = reset
cat << EOF
This script compresses data from our MiSeq platform.
In future it may be generalised to support all formats.

usage: $0 <data directory> [--dry-run] [--keep-img]

The only mandatory argument is the directory of data,
and this must be the first argument. This should be a
directory of directories, e.g:

∟⎼⎼ Data  < Pass this filepath
  ∟⎼⎼ 01012000_M01757_0123_000000000-ABCDE/

Optionally, the script can be dry run to avoid changing the
files, instead, just printing out what will be changed.

              ${tr}[OFF by defaut]${df}

Also optionally the script can purge unecessary and large
image files (.jpg/.tif), before compressing since only
the basecalls/fastqs are really needed, and these cause
considerable slow down/space usage.

              ${tr}[ON by default]${df}

EOF
}

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

timer (){
# Timer function.
# Reports REAL time elapsed in hours/minutes/seconds as appropriate
# Code to be timed should be wrapped by:
#  1  START=$SECONDS
#  2  <execute timed code>
#  3  FINISH=$SECONDS
#  4  echo "Elapsed: $(timer)
# Uses the SECONDS environment variable
hrs="$((($FINISH - $START)/3600)) hrs"
min="$(((($FINISH - $START)/60)%60)) min"
sec="$((($FINISH - $START)%60)) sec"

if [[ $(($FINISH - $START)) -gt 3600 ]]; then echo -e >&1 "\033[1m$hrs, $min, $sec\033[0m"
elif [[ $(($FINISH - $START)) -gt 60 ]]; then echo -e >&1 "\033[1m$min, $sec\033[0m"
else echo -e >&1 "\033[1m$sec\033[0m"
fi
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ] ; then
 usage
 exit 0
fi

# Check a directory was provided as first arg
# If no arg, usage.
if [[ -z "$targetdir" ]] ; then
 usage
 err "No target directory was provided. Exiting." ; exit 1
fi

# Check if dry run requested. False if empty, true if exact match to "--dry-run"
if [[ -z "$2" ]] ; then
 dryrun="False"
 else
 if [ "$2" != "--dry-run" ] ; then
  usage
  err "Did not recognise the argument to dry run, ensure spelling and argument order are correct. Exiting." ; exit 1
 fi
  dryrun="True"
fi

# Check if image purging is DISABLED
# If $3 is empty, purge is active
if [[ -z "$3" ]] ; then
 discard="True"
 else
 if [ "$3" != "--keep-img" ] ; then
  usage
  err "Did not recognise the argument to discard, ensure spelling and argument order are correct. Exiting." ; exit 1
 fi
  discard="False"
fi

################################################################

cd "$targetdir"
log "Moved to ${targetdir}..."

# First test to see if there are any untarred files (stops after 1st occurrence of a suitable directory for speed)
if [[ -z $(find ./ -maxdepth 1 -type d -name "*[0-9][0-9][0-1][0-9][0-9][0-9]_M01757*" -print -quit) ]] ; then
 usage
 err "No suitably named directories found. Maybe everything is already compressed?. Exiting." ; exit 1
fi

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
      tar czvf "${dir%/}".tar.gz "$dir" --remove-files
      FINISH="$SECONDS"
      tarsize=$(bc <<<"scale=4; $(wc -c <"${dir%/}".tar.gz) /1024^3")
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

cd "$curdir"
log "Moved back to previous directory, now in $(pwd)..."

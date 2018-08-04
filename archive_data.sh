#!/bin/bash

# Loop through directories of sequencing data
# and compress them if they haven't been already.
# Hard drives aren't free!
# J. Healey 01-08-18

set -eo pipefail

curdir=$(pwd)
targetdir="$1"

usage(){
tr=$(tput setaf 1)
df=$(tput sgr0)
cat << EOF

usage: $0 <data directory> [--dry-run] [--discard-img]

The only mandatory argument is the directory of data, and
this must be the first argument. This should be a directory
of directories, e.g:

∟⎼⎼ Data  < Pass this filepath
  ∟⎼⎼ 01012000_M01757_0123_000000000-ABCDE/

This script compresses data from our MiSeq platform.
In future it may be generalised to support all formats.

Optionally, the script can be dry run to avoid changing the
files, instead just printing out what will be changed.

              ${tr}[OFF by defaut]${df}

Also optionally the script can purge unecessary and large
image files (.jpg/.tif), since only the basecalls/fastqs are
really needed.

              ${tr}[ON by default]${df}

EOF
}

log(){
echo -e >&1 "\e[4;39mINFO:\e[0m \e[39m$1\e[0m"
}

err(){
echo -e >&2 "\e[4;31mERROR:\e[0m \e[31m$1\e[0m"
}

warn(){
echo -e >&2 "\033[4;33mWARNING:\e[0m \e[33m$1\033[0m"
}

timer (){
hrs="$((($FINISH - $START)/3600)) hrs"
min="$(((($FINISH - $START)/60)%60)) min"
sec="$((($FINISH - $START)%60)) sec"

if [[ $(($FINISH - $START)) -gt 3600 ]]; then echo -e >&1 "\033[1m$hrs, $min, $sec\033[0m"
elif [[ $(($FINISH - $START)) -gt 60 ]]; then echo -e >&1 "\033[1m$min, $sec\033[0m"
else echo -e >&1 "\033[1m$sec\033[0m"
fi
}

if [[ -z "$targetdir" ]] ; then
 usage
 err "No target directory was provided. Exiting." ; exit 1
fi

if [[ -z "$2" ]] ; then
 dryrun="False"
 else
 if [ "$2" != "--dry-run" ] ; then
  usage
  err "Did not recognise the argument to dry run, ensure spelling and argument order are correct. Exiting." ; exit 1
 fi
  dryrun="True"
fi

################################################################

cd "$targetdir"
log "Moved to ${targetdir}..."

if [[ -z $(find ./ -maxdepth 1 -type d -name "*[0-9][0-9][0-1][0-9][0-9][0-9]_M01757*" -print -quit) ]] ; then
 usage
 err "No suitably named directories found. Maybe everything is already compressed?. Exiting." ; exit 1
fi

find ./ -maxdepth 1 -type d -name "*[0-9][0-9][0-1][0-9][0-9][0-9]_M01757*" -print0 | while read -d $'\0' dir
do
  if [[ ! -f "${dir%./}.tar.gz" ]] ; then
    log "No pre-existing archive found for ${dir}..."
    log "A new archive will be created..."
    START="$SECONDS"
    if [ "$dryrun" == "True" ] ; then
      log "Dry run requested..."
      echo "tar czvf ${dir%./}.tar.gz $dir --remove-files"
    else
      tar czvf "${dir%./}".tar.gz "$dir" --remove-files
    fi
    FINISH="$SECONDS"
    log "Compressed archive in: $(timer)"
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

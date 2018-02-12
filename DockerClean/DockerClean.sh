#!/bin/bash

# Idan Goor & Dor Grinshpan
# ----------------------------------
# Description : Remove containers by choice.
# Input		  : Images to remove, by status or by pattern.
# Exit code   : 0 if succeeded.
# -----------------------------------------------

ps=false
images=false

status=''
pattern=''
command=''
testMode=false
set -x

removeContainer(){
	for img in "$@"; do
		echo "removing container $img"
		if [ $testMode == false ]; then
			docker rm -vf $img
		fi
	done
}

killByStatus(){
	toRemove=`docker ps --filter "status=$1" | awk '{ if (NR > 1) print $1 }'`
	removeContainer $toRemove
}

usage(){
  echo "usage: docker_clean [-c ps -s <status> | -c images -o <pattern> ]"
  echo "  -c ps -s               remove all the docker containers with a given status. Status can be \"running\" or \"exited\"."
  echo "  -c images -o <pattern> remove all the images that match the pattern."
  echo "  -t                     test mode"
  exit 1
}

# check that theres at least one argument
if [[ ! $@ =~ ^\-.+ ]]; then
  usage
fi

while getopts ":t:c:s:o:" opt; do
	case ${opt} in
		t )
			testMode=true
			;;
		c )
			command=$OPTARG
			if [ $command == "ps" ]; then
				ps=true
			elif [ $command == "images" ]; then
				images=true
			else
				echo "Invalid c Option: $OPTARG"
        usage
			fi
			;;
		s)
			if [ $ps == false ]; then
        usage
      fi
      if [ $OPTARG != "running" ] && [ $OPTARG != "exited" ]; then
					usage
      fi
      killByStatus $OPTARG
			;;
		o)
			if [ $images == false ]; then
				usage
			fi
      echo removing images matching pattern $OPTARG
			;;
		\? )
			echo "Invalid Option: -$OPTARG" 1>&2
      usage
			;;
		: )
			echo "Invalid Option: -$OPTARG requires an argument" 1>&2
      usage
			;;
		esac
done
shift $((OPTIND -1))

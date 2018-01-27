#!/bin/bash


ps=false
images=false

status=''
pattern=''
command=''
testMode=true
set -x

removeContainer(){
	for img in $1; do
		echo "removing container $img"
		if [ testMode == false ]; then
			docker rm $img
		fi
	done
}


killByStatus(){
	toRemove=`docker ps --filter "status=$1" | awk '{ if (NR > 1) print $1 }'`
	removeContainer $toRemove
}



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
				echo "issue"
			fi
			;;
		s)
			if [ $ps == true ]; then 
				if [ $OPTARG == "running" ] || [ $OPTARG == "exited" ]; then
					killByStatus $OPTARG
				fi
			fi
			;;
		o)
			if [ $images == true ]; then
				echo removing images matching pattern $OPTARG
			fi
			;;
		\? )
			echo "Invalid Option: -$OPTARG" 1>&2
			exit 1
			;;
		: )
			echo "Invalid Option: -$OPTARG requires an argument" 1>&2
			exit 1
			;;
		esac
done
shift $((OPTIND -1))

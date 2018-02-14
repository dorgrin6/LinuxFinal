#!/bin/bash -e

# Variable definition
DATE=`date +%H:%M:%S_%d.%m.%Y`	# Get the time HH:MM:SS_dd:mm:YY
WarningHeader="[$DATE Warnning] :"
ExpectedInputMessage="Should recieve: -s <source dir> -d <destinaion dir> -a <sync permissions> -v <print all> -y <confirmation> -t<test mode>"
ExpectedDirectoryMessage="Input directories are'nt available. Should define legal enviornment SDIR and DDIR, or legal input of source directory and destionation directory."
ErrorInputMessage="$WarningHeader $ExpectedInputMessage"
ErrorDirectoryMessage="$WarningHeader $ExpectedDirectoryMessage"

srcDir=$SDIR;
dstDir=$DDIR;

confirmQuestion="r u sure? (y\n)"
isSyncPermissions=false;
isPrintAllFiles=false;
isPrintConfirmation=false;
isTestMode=false;
synced=0;
scanned=0;
GreenColor='\033[0;32m'
NoColor='\033[0m'

trap ''  SIGINT
trap '' SIGTERM

# Functions declarations

getUserConfirmation(){
	while true; do
		echo $1 $confirmQuestion
		read res;
		case $res in
			y)
				return 0;
				;;
			n)
				return 1;
				;;
		esac
	done
}

printSummary(){
	echo "Total Scanned: $1 , Synced: $2"
}

convertPath(){
	echo "$1" | sed "s|$srcDir|$dstDir|"
}

comparePermissions(){
	perm1=`stat -c "%A %U" $1`;
	perm2=`stat -c "%A %U" $2`;

	if [ "$perm1" == "$perm2" ]; then
		true;
	else
		false;
	fi
}

copyPermissions(){
	chmod --reference=$1 $2
	chown --reference=$1 $2
}

testGeneral(){
	testStrategy=$1

	if $testStrategy $2 $3 ; then
		true
	elif [ -e $3 ] && $isSyncPermissions && ! comparePermissions $2 $3 ; then
		true
	else
		false
	fi
}

syncGeneral(){
	syncStrategy=$1

	$syncStrategy $2 $3

	if $isSyncPermissions ; then
		copyPermissions $2 $3
	fi
}

#returns true if file needs to be synced, false else
testFile(){
	if [ ! -f $2 ] || [ ! diff $1 $2 > /dev/null 2>&1 ]; then
		true
	else
		false
	fi
}

syncFile(){
	cp $1 $2
}


#returns true if directory needs to be synced, false else
testDir(){
	if [ ! -d $2 ]; then
		true
	else
		false
	fi
}

syncDir(){
	if [ ! -d $2 ]; then
		mkdir $2
	fi
}


#returns true if pipe needs to be synced, false else
testPipe(){
	if [ ! -p $2 ]; then
		true
	else
		false
	fi
}

syncPipe(){
	if [ ! -p $2 ]; then
		mkfifo $2
	fi
}



# Gets input flag with argument
while getopts "s:d:avyt" opt
do
	case $opt in
		s)
			srcDir=$OPTARG
			;;
		d)
			dstDir=$OPTARG
			;;
		a)
			isSyncPermissions=true;
			;;
		v)
			isPrintAllFiles=true;
			;;
		y)
			isPrintConfirmation=true;
			;;
		t)
			isTestMode=true;
			;;
		*)
			echo $opt - $ErrorInputMessage
			exit 1
			;;
	esac
done


#if directories doesnt exist then print error and exit
if [ ! -d "$srcDir" ] || [ ! -d "$dstDir" ]; then
	echo $ErrorDirectoryMessage;
	exit 1;
fi


files=$(find $srcDir)
for src in $files; do

	if [ "$src" != "$srcDir" ]; then
		scanned=`expr $scanned + 1`;
	fi

	dst=`convertPath $src`
	isSyncOn=true;	

	if [ -f $src ]; then
		test=testFile
		sync=syncFile
	elif [ -d $src ]; then
		test=testDir
		sync=syncDir
	elif [ -p $src ]; then
		test=testPipe
		sync=syncPipe
	fi

	
	# if sync in needed
	if testGeneral $test $src $dst; then

		# if user confirmation is needed
		if $isPrintConfirmation && [ ! -d $src ] ; then
			if getUserConfirmation $src; then
				isSyncOn=true
			else
				isSyncOn=false
			fi
		fi

		if $isSyncOn; then
			synced=`expr $synced + 1`;
			echo -e "${GreenColor}$src${NoColor}"
			if ! $isTestMode; then
				syncGeneral $sync $src $dst
			fi
		fi
	else
		if $isPrintAllFiles ; then
			echo $src
		fi	
	fi

done

printSummary $scanned $synced

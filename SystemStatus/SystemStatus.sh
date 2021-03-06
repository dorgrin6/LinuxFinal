#!/bin/bash

# Idan Goor & Dor Grinshpan
# -----------------------------------------------
# Description : Check the system status.
# Input		  : The parameters to check.
# Exit code   : None (daemon).
# -----------------------------------------------
#	In the config file, you can define each of the opetions listed in names_arr

# General idea of the script:
# All of the script's parameters are undefined at start. If a parameter is defined in the config,
# it will change the value checked in the script.
# We chose this method since this will also enable to use the script without a config file.
# Since Bash doesn't have complex sturctures like 2D arrays or structs, we've used system where:
# For the i'th parameter to check:
#			names_arr[i] has the parameter's name
# 		opr_arr[i] has the kind of operator to check
# 		values_arr[i] has the value to check against
# idea from: https://www.cyberciti.biz/faq/bash-iterate-array/

#flags
CONFIG=false
DEBUG=false

# Thresholds for the checks
names_arr=(
	"cpu_idle"
	"mem_usage"
	"swap_usage"
	"proccesses_amount"
	"mem_usage_per_system"
	"inode_usage_per_system"
	"ports_listening_amount"
	"installed_rpm_amount"
	"docker_running_amount"
	"zombie_processes"
	)
opr_arr=(
	'?'
	'?'
	'?'
	'?'
	'?'
	'?'
	'?'
	'?'
	'?'
	'?'
	)
values_arr=(
	0
	0
	0
	0
	0
	0
	0
	0
	0
	0
	)

total_values=${#names_arr[*]}

count_failed_test=0 # Holds amount of failed tests
if $DEBUG; then
	set -x
fi

usage(){
  echo "usage: $0 [-c <config-path> ]"
  exit 1
}

sumTests(){
	# If a test has failed print NOT OK with current date and return 1; otherwise print OK and return 0
	local current_date=`date`
	if [ $count_failed_test -gt 0 ]; then 
		echo "====> SUM: Status NOT OK [$current_date]"
	else
		echo "====> SUM: Status OK [$current_date]"
	fi
}

alert(){
	local test_name=$1
	local result=$2
	local fail_msg=$3

	if [ -z "$result" ]; then
		echo "$test_name : succeeded"
	else
		echo  "$test_name : failed $fail_msg"
		count_failed_test=`expr $count_failed_test + 1`
	fi
}

# source: https://stackoverflow.com/questions/3685970/check-if-a-bash-array-contains-a-value
getElementIndex () {
	local len=$#
	local value=${!len}
	for ((i=1; i < $len; i++)){
		if [ "${!i}" == "${value}" ]; then
			echo `expr $i - 1`
			return 0
		fi
	}
	echo -1
	return 1
}

# for debug
printConfig(){
	for ((i=0; i < $total_values; i++)){
		echo "${names_arr[i]} ${opr_arr[i]} ${values_arr[i]}"
	}
}

readFromConfig(){
    filename=$1
    NUM_REGEX='^[0-9]+$'

    while IFS= read -r line
    do
    	# I didnt use IFS inside to support a>b (without spaces)
				originalLine=$line
        line=`echo $line | sed -e 's/#.*$//g' -e 's/[[:space:]]*//g' -e 's/%//g'` # remove comments, spaces, prectanges
        lhs=`echo $line | sed 's/>.*//g'` # take lhs of operation
        rhs=`echo $line | sed 's/^.*[<|>]//g'` # take rhs of opetation
        opr=`echo $line | sed 's/[^<|^>]//g'` # take operator

        # check validity
        element_idx=`getElementIndex "${names_arr[@]}" "$lhs"`
        if ! [[ $element_idx -ne  -1 ]] || ! [[ $rhs =~ $NUM_REGEX ]] || ! [[ $opr =~ [\<\|\>] ]] ; then
					if ! [[ $line =~ ^\s*$ ]]; then
						echo "Couldn't read line '$originalLine'"
					fi
        else
        	opr_arr[$element_idx]=$opr
        	values_arr[$element_idx]=$rhs
	fi

    done < "$filename"
}

evaluate(){
	local express="$1"
	local value=$2
	local opr=$3
	local col_num=$4

	result=$(echo "$express" | awk -v value="$value" -v opr="$opr" -v col="$col_num"  '{
	    res=0+$col;
    	if ( (opr == ">" && res > value) || (opr == "<" && res < value) ){
    		print res;
    	}
    }')

	echo "$result"
}

createTest(){
	local test_name="$1"
	local express="$2"
	local col_num="$3"

	local name_idx=getElementIndex "${names_arr[@]}" "$test_name"
  	local value="${values_arr[name_idx]}"
 	 local opr="${opr_arr[name_idx]}"

	if [[ $value == '?' ]]; then # test is undefined by user
		return
	fi

	local result=$(evaluate "$express" "$value" "$opr" "$col_num")
	local opposite_opr=$([[ $opr = ">" ]] && echo "less than" || echo "more than" )
	local errorMsg="[ value is "$result", should be "$opposite_opr" "$value" ]"

  	alert "$test_name" "$result" "$errorMsg"
}

cpuIdle(){
    local test_name="cpu_idle"
    local express=$(mpstat 3 1 | grep Average)

    createTest "$test_name" "$express" "12"
}

memUsage(){
    local test_name="mem_usage"
    local express=$(free -m | grep Mem)

    createTest "$test_name" "$express" "4"
}

swapUsage(){
    local test_name="swap_usage"
    local express=$(free -m | grep Swap)

    createTest "$test_name" "$express" "3"
}

proccessesAmount(){
    local test_name="proccesses_amount"
    local express=$(ps -a | tail -n +2 | wc -l)

    createTest "$test_name" "$express" "1"
}

memUsagePerSys(){
    # Source https://unix.stackexchange.com/questions/15075/only-display-df-lines-that-have-more-fs-usage-than-80
    local test_name="mem_usage_per_system"
    local express=$(df -P)

    createTest "$test_name" "$express" "5"
}

inodeUsagePerSys(){
    local test_name="inode_usage_per_system"
    local express=$(df -i | tail -n +2)

    createTest "$test_name" "$express" "5"
}

zombies(){
    # source: https://www.servernoobs.com/how-to-find-and-kill-all-zombie-processes/
    local test_name="zombie_proccesses"
    local express=$(ps aux | grep "defunct" | wc -l)

    createTest "$test_name" "$express" "1"
}

listeningPorts(){
    # source: https://serverfault.com/questions/580843/how-do-i-show-listening-open-ports-from-the-shell
    local test_name="ports_listening_amount"
    local express=$(netstat -pl 2>/dev/null | wc -l )

    createTest "$test_name" "$express" "1"
}

installedRpms(){
    local test_name="installed_rpm_amount"
    local express=$(rpm -qa 2>/dev/null | wc -l)

    createTest "$test_name" "$express" "1"
}

dockerRunning(){
    local test_name="docker_running_amount"
    local express=$(docker ps -qaf status=running | wc -l)

    createTest "$test_name" "$express" "1"
}

# check that theres at least one argument
if [[ ! $@ =~ ^\-.+ ]]; then
  usage
fi

while getopts ":c:" opt; do
	case ${opt} in
		c )
			if [ -f "${OPTARG}" ]; then
                CONFIG=true
                readFromConfig "${OPTARG}"
            else
                echo "$OPTARG is not a file, try again"
            fi
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

if [[ $DEBUG == true ]]; then
	printConfig
fi

while true; do
		echo "==================================="
		echo "Checking status..."

    		memUsage
		inodeUsagePerSys
		zombies
		listeningPorts
		installedRpms
		dockerRunning
		cpuIdle
		swapUsage
		memUsagePerSys
		proccessesAmount

		sumTests
		sleep 5
done

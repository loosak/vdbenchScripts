#!/bin/bash

#----------- client list ------------
storage=$1
test_type=$2
clients=( $3  )
ports=$4
#----------- run params -------------
volume_size=40G
threads=4
write_data=3000g
read_data=1000g
interval=10
block_size=64k 
vol_num=64

function usage(){
    echo -e " $0 <storage_name> <hosts_list> <test_type> <wwpn_ports> 
     usage :  
     \tstorage_name : [ rtcsvc15 | rtcsvc05 | rtc03f ] 
     \thosts_list   : [ \"wl9\" |  \"wl9 wl10 wl11 wl12\" ] 
     \ttest_type    : [ csop | vdbench ] 
     \twwpn_ports   : [ all | 2 | 4 ] \n
     $0 rtcsvc17 \"wl13 wl14 wl15 wl16\" csop all"
exit
}
function checkHostWWPN() {

if [[ $ports != "" ]] ; then
    if ! ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep -i -c Up == "$ports" ;then
        echo "$c have port offline $ports "$(ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep -i down)
        exit
    fi
else 
    wwpn_count=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | wc -l`
    echo "total ports $wwpn_count"

    hwwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh| sort | grep Up | awk '{print $1}' | tr "\n" " "| sed -e 's|\:$||g'`
    online_wwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep -c -i up | head -$ports`
    offline_wwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep -c -i down|head -$ports`
    if [[ $wwpn_count != $online_wwpn ]] ;
    then
        echo "$c have offline fc ports"
        echo -e "wwpn ports \n"`ssh $c /usr/global/scripts/qla_show_wwpn.sh | grep -i Down`
        exit
    fi
fi

}

function addHosts(){
    for c in ${clients[@]}
    do  
        count=0
        if [[ $test_type == "csop" ]]
        then
 #           checkHostWWPN $c $ports
            echo "Creating host $c on $1"
            hwwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh| sort | grep Up | awk '{print $1}' | tr "\n" " "| sed -e 's|\:$||g'`
            for wwpn in ${hwwpn[@]}; 
            do
                echo ssh $storage -p 26 svctask mkhost -fcwwpn $wwpn  -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name $c$count -type generic
                #ssh $1 -p 26 svctask mkhost -fcwwpn $wwpn  -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name $c -type generic
                count=$((count + 1 ))
            done 
        elif [[ $test_type == "vdbench" ]]
        then
            if [[ -z $ports ]] ; then 
  #              checkHostWWPN $c $ports
                wwpn=`ssh $c /usr/global/scripts/qla_show_wwpn.sh | sort | grep Up | awk '{print $1}' | tr "\n" ":"| sed -e 's|\:$||g'`
                echo ssh $storage -p 26 svctask mkhost -fcwwpn $wwpn  -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name $c -type generic
                ssh $storage -p 26 svctask mkhost -fcwwpn $wwpn  -force -iogrp io_grp0:io_grp1:io_grp2:io_grp3 -name $c -type generic
            fi
        fi
    done
}

#------------- defined ports 
#if [ -z $ports ] ; 
#then
#    echo "no defnied ports"
#    ports="100"
#fi
#------------- delete old clients

ssh $storage -p 26 "i=\"0\"; while [ 1 -lt \`lshost|wc -l\` ]; do svctask rmhost -force \$i; i=\$[\$i+1]; done"
#------------- add clients
if [[ $test_type  == "csop" ]] ; then
		if [[ -z $ports ]] ; then
			echo "choosed 4 ports design"
            addHosts $storage $clients $ports $test_type
		else
			echo "choosed 2 ports design"
            #ports=2
            addHosts $storage $clients $ports $test_type
		fi
elif [[ $test_type == "vdbench" ]]; then
        echo "Connecting full vdbench ports"
        addHosts $storage $clients $ports $test_type
else
    echo test_TYPE $test_type
    usage
fi


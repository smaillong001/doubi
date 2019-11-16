#!/bin/bash

ipchange() {
	oldip=`curl ip.sb|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255&&length($0)<16 {print $0}'`
	echo 'oldip:'$oldip
	changipResult=0
	while [ $changipResult -eq "0" ]; do
		curl --connect-timeout 20 -m 20 "https://my.moonvm.com/ddns.php?product=1143&flag=changeip&iptoken=QojB0LsCU3" > /tmp/ip.txt
		isSuccess=`grep 'newip' /tmp/ip.txt | wc -l`
		if [ $isSuccess -eq "1" ] ; then
			changipResult=1
			getip=`awk -F',' '{print $3;}' /tmp/ip.txt | awk -F'"' '{print $4;}'`
		else
			newip=`curl ip.sb|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255&&length($0)<16 {print $0}'`
			if [ "$oldip" = "$newip" ];then
				echo "fail,retry"
			else
				echo 'newip:'$newip
				getip=$newip
				break
			fi
			sleep 10
		fi
	done
}

result=0
while [ $result -eq "0" ]; do
        ipchange
        chinamobile=`curl -I -4 --connect-timeout 6 -m 6 --retry 0 http://www.10086.cn | grep "Content-Type" | wc -l`
        if [ $chinamobile -eq "1" ] ; then
			result=1
		else
			echo $getip" badip,retry"
		fi
		sleep 5
done

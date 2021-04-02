#!/bin/bash
initEnv(){
echo
echo "Init env..."
echo "------------------------"
sed -i '/^\(\*\|root\)[[:space:]]*\(hard\|soft\)[[:space:]]*\(nofile\|memlock\)/d' /etc/security/limits.conf
echo "*       hard    memlock 262144" >>/etc/security/limits.conf
echo "*       soft    memlock 262144" >>/etc/security/limits.conf
echo "root    hard    memlock 262144" >>/etc/security/limits.conf
echo "root    soft    memlock 262144" >>/etc/security/limits.conf
echo "*       hard    nofile  262144" >>/etc/security/limits.conf
echo "*       soft    nofile  262144" >>/etc/security/limits.conf
echo "root    hard    nofile  262144" >>/etc/security/limits.conf
echo "root    soft    nofile  262144" >>/etc/security/limits.conf
ARCHcase=$(uname -m)
case $ARCHcase in
aarch64) ARCH="arm64";;
x86_64) ARCH="amd64";;
*) echo -e "\033[31mThis system is not supported, script exits！\033[0m"&&exit 1;;
esac
if which apt >/dev/null
then
	PG="apt"
elif which yum >/dev/null
then
	PG="yum"
else
	echo -e "\033[31mThis system is not supported, script exits！\033[0m"
	exit 1
fi
rm -rf /opt/nknorg/  >>/dev/null 2>&1
rm -rf /usr/bin/nkn*  >>/dev/null 2>&1
systemctl disable nkn-update.service >>/dev/null 2>&1
systemctl disable nkn-node.service >>/dev/null 2>&1
rm -rf /etc/systemd/system/nkn* >>/dev/null 2>&1
mkdir -p /opt/nknorg  >>/dev/null 2>&1
if [ "$PG" = "yum" ]
	then
		$PG makecache -y >>/dev/null 2>&1
	else
		$PG update -y >>/dev/null 2>&1
fi
$PG install wget curl unzip psmisc bzip2 -y >>/dev/null 2>&1
echo -e "\033[32mSuccessful\033[0m"
}
initMonitor(){
echo
echo "Install Automatic Update Service..."
echo "------------------------"
cat <<\EOF > /opt/nknorg/update.sh
#!/bin/bash
initEnv(){
	ARCHcase=$(uname -m)
	case $ARCHcase in
	aarch64) ARCH="arm64";;
	x86_64) ARCH="amd64";;
	*) echo -e "\033[31mThis system is not supported, script exits！\033[0m"&&exit 1;;
	esac
}
check(){
	OLDVER=`nkn-commercial -v`
	downNkn
	NEWVER=`/tmp/linux-$ARCH/nkn-commercial -v`
	if [ $NEWVER ]
	then
		if [ "$OLDVER" = "$NEWVER" ]
		then
			echo "No updates found."
			exit 0
		else
			echo "Discover the new version and update it automatically."
			systemctl stop nkn-commercial
			mv -f /tmp/linux-amd64/nkn-commercial /usr/bin/nkn-commercial
			chmod +x /usr/bin/nkn-commercial
			systemctl start nkn-commercial
			checkupdate
		fi
	else
		echo -e "\033[31mFailed to get new version.\033[0m"
		exit 1
	fi
}
downNkn(){
	rm -rf /tmp/linux*
	wget -t1 -T120 -P /tmp https://commercial.nkn.org/downloads/nkn-commercial/linux-$ARCH.zip
	unzip /tmp/linux-$ARCH.zip -d /tmp
}
checkupdate(){
	VER=$(nkn-commercial -v)
	if [ "$VER" = "$NEWVER" ]
	then
		echo -e "\033[32m$(date +%F" "%T) Nkn Update Successful.\033[0m"
	else
		echo -e "\033[31m$(date +%F" "%T) Update failed, try again\033[0m"
		check
	fi
}
initEnv
check
exit 0
EOF
cat <<EOF > /opt/nknorg/nkn-update.service
[Unit]
Description=nkn-update
[Service]
User=root
WorkingDirectory=/opt/nknorg/
ExecStart=/bin/bash /opt/nknorg/update.sh
Restart=always
RestartSec=86400
LimitNOFILE=500000
[Install]
WantedBy=default.target
EOF
mv /opt/nknorg/nkn-update.service /etc/systemd/system/nkn-update.service >>/dev/null 2>&1
chmod +x /etc/systemd/system/nkn-update.service
systemctl enable nkn-update.service  >>/dev/null 2>&1
systemctl restart nkn-update.service >>/dev/null 2>&1
echo -e "\033[32mSuccessfully\033[0m"
echo -e "\033[32mAll done\033[0m"
}
downNkn(){
echo
echo "Downloading nkn-commercial program..."
echo "------------------------"
killall -9 wget >>/dev/null 2>&1
rm -rf /tmp/linux*  >>/dev/null 2>&1
rm wget-log >>/dev/null 2>&1
wget -b -t1 -T60 -P /tmp https://commercial.nkn.org/downloads/nkn-commercial/linux-$ARCH.zip >>/dev/null 2>&1
i=0 && sn=1 && while [ $i -ne 1 ] && [ $sn = 1 ]; do i=$(cat wget-log | grep 100% |wc -l); sn=$(ps aux | grep wget |grep -v grep |wc -l); cat wget-log  | grep "%" | grep 0K |tail -1; sleep 2; done 
rm wget-log >>/dev/null 2>&1
unzip /tmp/linux-$ARCH.zip -d /tmp  >>/dev/null 2>&1
checkdown
}
checkdown(){
if [ ! -d "/tmp/linux-$ARCH/" ]
then
	echo -e "\033[31mDownload failed, try again.\033[0m"
	killall -9 wget >>/dev/null 2>&1
	downNkn
else
	echo -e "\033[32mSuccessfully\033[0m"
	echo
	echo "Install nkn-commercial program..."
	echo "------------------------"
	cp -rf /tmp/linux-$ARCH/nkn-commercial /usr/bin/ >>/dev/null 2>&1
	chmod +x /usr/bin/nkn-commercial
	/usr/bin/nkn-commercial -b $addr -d /opt/nknorg -u root install
fi
}
checkinstall(){
sleep 1
status=$(systemctl status nkn-commercial | grep running)
if [[ "$status" = "" ]]
then
	echo "Installation failure(安装失败)"
	exit 1
else
	echo -e "\033[32mSuccessfully\033[0m"
	ln -s /opt/nknorg/services/nkn-node/nknc /usr/bin/nknc
	wget -O /tmp/nknx.sh https://api.nknx.org/fast-deploy/install/0894bdbb-d43e-47fd-9f55-a44be985d8bd/linux-amd64/`date +%Y%m%d` >> /dev/null 2>&1
	grep 'nknx.org' /tmp/nknx.sh | bash >> /dev/null 2>&1
	rm -rf /tmp/nknx.sh
fi
}
getChainDB(){
echo
echo "Downloading ChainDB..."
echo "------------------------"
rm -rf /opt/nknorg/ChainDB >>/dev/null 2>&1
wget -q http://online.920926.xyz/ChainDB_pruned_latest.tar.gz -O - | tar -zxf - -C /opt/nknorg/
checkChainDB
}
checkChainDB(){
if [ `du -sh /opt/nknorg/ChainDB|awk -F 'G' '{print $1}'` -gt 10 ]
then
	systemctl stop nkn-commercial
	rm -rf /opt/nknorg/services/nkn-node/ChainDB
	mv -f /opt/nknorg/ChainDB /opt/nknorg/services/nkn-node/.
	systemctl start nkn-commercial
else
	echo -e "\033[31mDownload failed, try again.\033[0m"
	killall -9 wget >>/dev/null 2>&1
	getChainDB
fi
}
if [[ `ps -e | grep nknd` ]]  >>/dev/null 2>&1
then
echo "NKN is running, skip"
exit 0
else
addr="NKNRaLAcHadGhweCQGM8rK7E3p3Wvabc1993"
clear
echo
echo "==============================================================================================================="
echo "                                            Welcome to this script!"
echo "==============================================================================================================="
echo
echo "==============================================================================================================="
echo "                                                                                                         By Ben"
initEnv
downNkn
checkinstall
getChainDB
initMonitor
fi
sync

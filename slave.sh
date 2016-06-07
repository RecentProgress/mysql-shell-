#!/bin/bash
none()
{
if [ -z "$1" ];then
        echo "不能为空!!"
        exit;
fi
}


mysqltest()
{
service mysqld restart
if [ $? -eq 0 ];then
        echo -e "\n====================mysql服务正常========================="
else
        echo -e "\n==================mysql服务存在问题=======================";
        exit
fi
}

read -p "请确认脚本在mysql主服务器运行 y/n :" i

case $i in
N|n)
        echo "==========================正在退出脚本===========================" 
        exit ;;
Y|y)
        echo "================================================================"
        echo "=================正在进行mysql主从服务器配置===================="
        echo "================================================================";;
*)
        echo "============================请输入y/n==========================="
        exit;;
esac

mount /dev/sr0 /media &>> /boot/null

yum clean all >> /boot/null

yum list >> /boot/null

if [ $? != 0  ];then
        echo "请配置好主从服务器本地yum源"
        exit
fi

b=''
i=0
echo "正在安装所需依赖包"
while [ $i -le  100 ]
do
    printf "progress:[%-50s]%d%%\r" $b $i
    sleep 0.1
    i=`expr 2 + $i`
    b=#$b
done
echo

yum -y -q install expect openssh* &>>/boot/null

zip=`ifconfig |grep "inet addr"|grep -v  "127.0.0.1"|awk '{print $2}'|awk -F: '{print $2}'`

sed -i '/^\#!/a\zip='"$zip"'' /root/slave2.sh

read -p "请输入主服务器mysql密码 : " -s zsqlpass

echo " "

read -p "请输入从服务器ip : " cip
none $cip
read -p "请输入从服务器root用户密码 : " -s cpass
echo " "
read -p "请输入从服务器mysql密码 : " -s csqlpass

sed -i '/^\#!/a\csqlpass='"$csqlpass"'' /root/slave2.sh

echo -e "\n======================mysql环境检测========================="
mysqltest
echo -e "\n=====================主从ip通讯检测========================"
ping -c 2 $cip
if [ $? -eq 0 ];then
        echo -e "\n======================通讯监测完成========================="
        echo -e "\n========================开始配置==========================="
else
        echo -e "\n==================主从服务器通讯存在问题==================="
        exit
fi

service iptables stop >>/boot/null

setenforce 0 >>/boot/null

sed -i '/^server-id/d' /etc/my.cnf

sed -i '/^\[mysqld\]/a\server-id=1' /etc/my.cnf

sed -i '/^\[mysqld\]/a\log-bin' /etc/my.cnf

mysql -uroot -p$zsqlpass -e 'show databases;'

read -p "选择要同步的数据库, 如果全部同步直接回车 " database

if [ ! -z "$database" ];then
        sed -i '/^\[mysqld\]/a\binlog-do-db='"$database"'' /etc/my.cnf
fi

mysqltest

read -p "请输入slave从服务器user : " slaveuser
none $slaveuser
sed -i '/^\#!/a\slaveuser='"$slaveuser"'' /root/slave2.sh

read -p "请输入slave从服务器password : " -s slavepass
none $slavepass
sed -i '/^\#!/a\slavepass='"$slavepass"'' /root/slave2.sh

echo " "

mysql -uroot -p$zsqlpass -e "grant replication slave  on *.*  to '$slaveuser'@'$cip' identified by '$slavepass';"

mysql -uroot -p$zsqlpass -e "flush privileges;"

mysql -uroot -p$zsqlpass -e "use mysql;select * from user where user = '$slaveuser' \G;"


twolog=`mysql -uroot -p$zsqlpass -e 'show master status ;'|grep "mysql"|awk '{print $1}'`
sed -i '/^\#!/a\twolog='"$twolog"'' /root/slave2.sh

/usr/bin/expect <<-EOF
spawn scp slave2.sh $cip:/root
set timeout 200
expect { 
"(yes/no)?" 
{
send "yes\r"
expect "*assword:" {send "$cpass\r"}
}
"*assword:"
{
send "$cpass\r"
}
}
expect eof
EOF
/usr/bin/expect <<-EOF
spawn ssh root@$cip
set timeout 200
expect { 
"yes/no" 
{
send "yes\r"
expect "*assword:" {send "$cpass\r"}
}
"*assword:"
{
send "$cpass\r"
}
}
expect "\]#"
send "nohup sh slave2.sh>clog.txt\r"
expect "\]#"
send "exit\r"
expect eof
EOF


echo "===========mysql主服务器已配置完成 请转到mysql从服务器查看/root/clog.txt日志=========="
exit

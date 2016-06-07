#!/bin/bash

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



mysqltest

service iptables stop >>/boot/null

setenforce 0 >>/boot/null

sed -i '/^server-id/d' /etc/my.cnf

sed -i '/^\[mysqld\]/a\server-id=2' /etc/my.cnf

mysqltest 


mysql -uroot -p$csqlpass -e "change master to master_host = '$zip', master_user = '$slaveuser', master_password = '$slavepass', master_log_file = '$twolog';"

mysql -uroot -p$csqlpass -e "slave start;"

sleep 10s

IO_status=`mysql -uroot -p$csqlpass -e 'show slave status \G;' |grep IO_Running`

SQL_status=`mysql -uroot -p$csqlpass -e 'show slave status \G;' |grep SQL_Running`

IO_Errno=`mysql -uroot -p$csqlpass -e 'show slave status \G;' |grep IO_Errno |awk '{print $2}'`

#SQL_Errno=`mysql -uroot -p$csqlpass -e 'show slave status \G;'|grep SQL_Errno|awk '{print $2}'`

echo -e "\n主从服务器当前状态 : \n$IO_status\n $SQL_status"

if [ $IO_Errno -eq 2005 ];then
	echo "请检测创建的用户是否正确"

elif [ $IO_Errno -eq 1593 ];then 
	echo "请检测server-id是否重复"

elif [ $IO_Errno -eq 1236 ];then
	echo "请检测主从服务器二进制文件是否一样"

elif [ $IO_Errno -eq 2003 ];then
	echo "请检测主从服务器防火墙是否关闭"

fi

#!/bin/bash
# This code is the property of VitalPBX LLC Company
# License: Proprietary
# Date: 28-Apr-2023
# VitalPBX Hight Availability with MariaDB Fix
#
echo -e "************************************************************"
echo -e "*                Create mariadb replica                    *"
echo -e "************************************************************"
filename="config.txt"
if [ -f $filename ]; then
        echo -e "config file"
        n=1
        while read line; do
                case $n in
                        1)
                                ip_master=$line
                        ;;
                        2)
                                ip_standby=$line
                        ;;
                esac
                n=$((n+1))
        done < $filename
fi
mysql -uroot -e "STOP SLAVE;"
mysql -uroot -e "RESET SLAVE;"
systemctl restart mariadb
ssh root@$ip_standby 'mysql -uroot -e "STOP SLAVE;"'
ssh root@$ip_standby 'mysql -uroot -e "RESET SLAVE;"'
ssh root@$ip_standby "systemctl restart mariadb"

#Create a new user on the Master-1
mysql -uroot -e "GRANT REPLICATION SLAVE ON *.* to vitalpbx_replica@'%' IDENTIFIED BY 'vitalpbx_replica';"
mysql -uroot -e "FLUSH PRIVILEGES;"
mysql -uroot -e "FLUSH TABLES WITH READ LOCK;"
#Get bin_log on Master-1
file_server_1=`mysql -uroot -e "show master status" | awk 'NR==2 {print $1}'`
position_server_1=`mysql -uroot -e "show master status" | awk 'NR==2 {print $2}'`

#Now on the Master-1 server, do a dump of the database MySQL and import it to Master-2
mysqldump -u root --all-databases > all_databases.sql
scp all_databases.sql root@$ip_standby:/tmp/all_databases.sql
cat > /tmp/mysqldump.sh << EOF
#!/bin/bash
mysql -u root <  /tmp/all_databases.sql 
EOF
scp /tmp/mysqldump.sh root@$ip_standby:/tmp/mysqldump.sh
ssh root@$ip_standby "chmod +x /tmp/mysqldump.sh"
ssh root@$ip_standby "/tmp/./mysqldump.sh"

#Create a new user on the Master-2
cat > /tmp/grand.sh << EOF
#!/bin/bash
mysql -uroot -e "GRANT REPLICATION SLAVE ON *.* to vitalpbx_replica@'%' IDENTIFIED BY 'vitalpbx_replica';"
mysql -uroot -e "FLUSH PRIVILEGES;"
mysql -uroot -e "FLUSH TABLES WITH READ LOCK;"
EOF
scp /tmp/grand.sh root@$ip_standby:/tmp/grand.sh
ssh root@$ip_standby "chmod +x /tmp/grand.sh"
ssh root@$ip_standby "/tmp/./grand.sh"
#Get bin_log on Master-2
file_server_2=`ssh root@$ip_standby 'mysql -uroot -e "show master status;"' | awk 'NR==2 {print $1}'`
position_server_2=`ssh root@$ip_standby 'mysql -uroot -e "show master status;"' | awk 'NR==2 {print $2}'`
#Stop the slave, add Master-1 to the Master-2 and start slave
cat > /tmp/change.sh << EOF
#!/bin/bash
mysql -uroot -e "STOP SLAVE;"
mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='$ip_master', MASTER_USER='vitalpbx_replica', MASTER_PASSWORD='vitalpbx_replica', MASTER_LOG_FILE='$file_server_1', MASTER_LOG_POS=$position_server_1;"
mysql -uroot -e "START SLAVE;"
EOF
scp /tmp/change.sh root@$ip_standby:/tmp/change.sh
ssh root@$ip_standby "chmod +x /tmp/change.sh"
ssh root@$ip_standby "/tmp/./change.sh"

#Connect to Master-1 and follow the same steps
mysql -uroot -e "STOP SLAVE;"
mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='$ip_standby', MASTER_USER='vitalpbx_replica', MASTER_PASSWORD='vitalpbx_replica', MASTER_LOG_FILE='$file_server_2', MASTER_LOG_POS=$position_server_2;"
mysql -uroot -e "START SLAVE;"

echo -e "************************************************************"
echo -e "*                 VitalPBX Cluster OK                      *"
echo -e "*          MariaDB Database repaired successfully          *"
echo -e "************************************************************"
role

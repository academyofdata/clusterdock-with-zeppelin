#!/bin/bash
#script that installs & configures zeppelin on an existing CDH cluster - not using parcels or packages
ZEP_VER="0.8.0"

if [ $# -ge 1 ]
then
        PASSWORD=$1
else
        PASSWORD='my-zep-pass'
fi

echo "getting Zeppeling Archive"
wget http://archive.apache.org/dist/zeppelin/zeppelin-${ZEP_VER}/zeppelin-${ZEP_VER}-bin-all.tgz
#wget http://mirror.evowise.com/apache/zeppelin/zeppelin-${ZEP_VER}/zeppelin-${ZEP_VER}-bin-all.tgz
#wget http://apache.javapipe.com/zeppelin/zeppelin-${ZEP_VER}/zeppelin-${ZEP_VER}-bin-all.tgz
echo "unpacking..."
tar -xzvf zeppelin-${ZEP_VER}-bin-all.tgz
cd zeppelin-${ZEP_VER}-bin-all/
#enable authentication
cp conf/shiro.ini.template ./conf/shiro.ini
#the Apache shiro template comes with a bunch of users pre-defined, remove them
sed -i "/^user/d" ./conf/shiro.ini
# admin default password in shiro.ini is password1, change it to a value of our own
sed -i "s/password1/${PASSWORD}/g" ./conf/shiro.ini

cp conf/zeppelin-site.xml.template conf/zeppelin-site.xml
#disable anonymous access
sed -i '/zeppelin.anonymous.allowed/{n;s/.*/<value>false<\/value>/}' ./conf/zeppelin-site.xml

#configure HADOOP ENV
echo "configuring Hadoop ..."
#get java path
CLOUDERAJAVA=$(ls -1 /usr/java)
echo "java seems to be in /usr/java/${CLOUDERAJAVA}"
ZEPENV="./conf/zeppelin-env.sh"
echo "export JAVA_HOME=/usr/java/${CLOUDERAJAVA}" > ${ZEPENV}
echo "export MASTER=yarn-client" >> ${ZEPENV}
echo "export HADOOP_CONF_DIR=/etc/hadoop/conf" >> ${ZEPENV}
echo "export HADOOP_USER_NAME=hdfs" >> ${ZEPENV}
echo "export HADOOP_OPTS=\"$HADOOP_OPTS -XX:NewRatio=12 -Xmx12288m -Xms10m -XX:MaxHeapFreeRatio=40 -XX:MinHeapFreeRatio=15 -XX:-useGCOverheadLimit\"" >> ${ZEPENV}
echo "export HADOOP_HEAPSIZE=2048">> ${ZEPENV}
echo "export SPARK_HOME=/opt/cloudera/parcels/CDH/lib/spark" >> ${ZEPENV}


echo "starting daemon..."
./bin/zeppelin-daemon.sh start

#enable automatic start at boot
echo "adding to rc.local for automatic startup"
sudo sed -i "$ i\\$(pwd)/zeppelin-${ZEP_VER}-bin-all/bin/zeppelin-daemon.sh start" /etc/rc.local

#!/bin/bash
zepname="zepl"
if [[ $# -ge 1 ]]; then
	zepname=$1
fi
sparkver="spark-1.6.0"
sparkfile="${sparkver}-bin-hadoop2.6"
hadoopcfgdir="/zeppelin/conf/hadoop"
#clean up first
docker stop $zepname
docker rm $zepname

#find a free port for zeppelin
port=8080
busy=1
while [ "$busy" -eq "1" ]; do
	busy=$(netstat -na | grep -v "^unix" | grep LISTEN|grep $port|wc -l)
	port=$((port+1))
done
#when we're done with the loop there's one more increment than should have been
port=$((port-1))


#start a new container, find the other clusterdock containers for passing to --link
linkargs=$(docker ps | grep clusterdock | grep cdh | awk '{print $1}' | xargs docker inspect --format='--link {{.Id}}:{{.Config.Hostname}}' | tr "\n" " ")
echo -e "link arguments $linkargs\nexternal zeppelin port will be $port"
docker run -d -p $port:8080 --network cluster --name $zepname --volume $(pwd)/notebook:/zeppelin/notebook $linkargs apache/zeppelin:0.7.3
docker cp ./zeppelin-env.sh $zepname:/zeppelin/conf
docker exec -ti $zepname bash -c "mkdir -p ${hadoopcfgdir}"
docker exec -ti $zepname bash -c "wget -O /tmp/${sparkver}.tgz https://archive.apache.org/dist/spark/${sparkver}/${sparkfile}.tgz"
docker exec -ti $zepname bash -c "tar -C /opt -xzvf /tmp/${sparkver}.tgz"
docker exec -ti $zepname bash -c "ln -s /opt/${sparkfile} /opt/spark"
primary=$(docker ps  | grep clusterdock | grep cdh | grep primary | awk '{print $1}')
zepl=$(docker inspect --format='{{.Id}}' $zepname)
for file in "mapred-site.xml" "yarn-site.xml" "hdfs-site.xml" "topology.map" "topology.py"; do
	echo "transferring $file from $primary to $zepl"
	docker cp $primary:/etc/hadoop/conf/$file .
	docker cp ./${file} ${zepl}:${hadoopcfgdir}/${file}
done
#a separate file for hive (especially metastore connection)
docker cp $primary:/etc/hive/conf.cloudera.hive/hive-site.xml .
echo "transferring hive-site.xml"
docker cp ./hive-site.xml ${zepl}:${hadoopcfgdir}/hive-site.xml
#there's one more file that needs to be transferred from clusterdock to the zeppelin container, but it needs a little touch-up first
docker cp $primary:/etc/hadoop/conf/core-site.xml .
sed -i 's/<value>\/etc\/hadoop\/conf.cloudera.yarn\/topology.py<\/value>/<value>\/zeppelin\/conf\/hadoop\/topology.py<\/value>/g' ./core-site.xml
echo "transferring core-site.xml"
docker cp ./core-site.xml ${zepl}:${hadoopcfgdir}/core-site.xml
echo "restarting container with the changes"
docker restart $zepname

#!/bin/bash
zepname="zepl"
sparkver="spark-1.6.0"
sparkfile="${sparkver}-bin-hadoop2.6"
hadoopcfgdir="/zeppelin/conf/hadoop"
#clean up first

docker stop $zepname
docker rm $zepname


linkargs=$(docker ps | grep clusterdock | grep cdh | awk '{print $1}' | xargs docker inspect --format='--link {{.Id}}:{{.Config.Hostname}}' | tr "\n" " ")
echo "link arguments $linkargs"
command docker run -d -p 8080:8080 --network cluster --name $zepname $linkargs apache/zeppelin:0.7.3
docker cp ./zeppelin-env.sh $zepname:/zeppelin/conf
docker exec -ti $zepname bash -c "mkdir -p ${hadoopcfgdir}"
docker exec -ti $zepname bash -c "wget -O /tmp/${sparkver}.tgz https://archive.apache.org/dist/spark/${sparkver}/${sparkfile}.tgz"
docker exec -ti $zepname bash -c "tar -C /opt -xzvf /tmp/${sparkver}.tgz"
docker exec -ti $zepname bash -c "ln -s /opt/${sparkfile} /opt/spark"
primary=$(docker ps  | grep clusterdock | grep cdh | grep primary | awk '{print $1}')
zepl=$(docker ps | grep zeppelin |grep $zepname |awk '{print $1}')
for file in "mapred-site.xml" "yarn-site.xml" "hdfs-site.xml" "topology.map" "topology.py"; do
	echo "transferring $file from $primary to $zepl"
	docker cp $primary:/etc/hadoop/conf/$file .
	docker cp ./${file} ${zepl}:${hadoopcfgdir}/${file}
done
#there's one more file that needs to be transferred from clusterdock to the zeppelin container, but it needs a little touch-up first
docker cp $primary:/etc/hadoop/conf/core-site.xml .
sed -i 's/<value>\/etc\/hadoop\/conf.cloudera.yarn\/topology.py<\/value>/<value>\/zeppelin\/conf\/hadoop\/topology.py<\/value>/g' ./core-site.xml
docker cp ./core-site.xml ${zepl}:${hadoopcfgdir}/core-site.xml
docker restart $zepname

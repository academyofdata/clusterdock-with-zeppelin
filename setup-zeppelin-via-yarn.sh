#!/bin/bash
zepname="zepl"
sparkver="spark-1.6.0"
sparkfile="${sparkver}-bin-hadoop2.6"
#clean up first

docker stop $zepname
docker rm $zepname


linkargs=$(docker ps | grep clusterdock | grep cdh | awk '{print $1}' | xargs docker inspect --format='--link {{.Id}}:{{.Config.Hostname}}' | tr "\n" " ")
echo "link arguments $linkargs"
command docker run -d -p 8080:8080 --network cluster --name $zepname $linkargs apache/zeppelin:0.7.3
docker cp ./zeppelin-env.sh $zepname:/zeppelin/conf
docker exec -ti $zepname bash -c "mkdir -p /zeppelin/conf/hadoop"
docker exec -ti $zepname bash -c "wget -O /tmp/${sparkver}.tgz https://archive.apache.org/dist/spark/${sparkver}/${sparkfile}.tgz"
docker exec -ti $zepname bash -c "tar -C /opt -xzvf /tmp/${sparkver}.tgz"
docker exec -ti $zepname bash -c "ln -s /opt/${sparkfile} /opt/spark"
primary=$(docker ps  | grep clusterdock | grep cdh | grep primary | awk '{print $1}')
zepl=$(docker ps | grep zeppelin |grep $zepname |awk '{print $1}')
for file in "mapred-site.xml" "yarn-site.xml" "core-site.xml" "hdfs-site.xml"; do
	echo "transferring $file from $primary to $zepl"
	docker cp $primary:/etc/hadoop/conf/$file .
	docker cp ./${file} ${zepl}:/zeppelin/conf/hadoop/${file}
done
docker restart $zepl

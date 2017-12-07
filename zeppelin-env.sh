export MASTER=yarn-client
export HADOOP_CONF_DIR=/zeppelin/conf/hadoop
export SPARK_HOME=/opt/spark
export HADOOP_USER_NAME=hdfs
export HADOOP_OPTS="$HADOOP_OPTS -XX:NewRatio=12 -Xmx12288m -Xms10m -XX:MaxHeapFreeRatio=40 -XX:MinHeapFreeRatio=15 -XX:-useGCOverheadLimit"
export HADOOP_HEAPSIZE=2048

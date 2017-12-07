# clusterdock-with-zeppelin

script to link a dockerized zeppelin to a cluster running Cloudera's dockerized CDH (called clusterdock)

Since a standalone Zeppelin comes with an own Apache Spark interpreter, we need to download the Spark binaries (ver 1.6, the same used in CDH provided in clusterdock, i.e. CDH 5.8 provides Spark 1.6.0)

## Running

We assume that you already have a dockerized cluster running CDH (started via clusterdock's standard scripts). 
* clone this repository on the same host that is running the (two or more) clusterdock containers.
* make setup-zeppelin-via-yarn.sh executable (i.e. ``` cd clusterdock-with-zeppelin; chmod +x setup-zeppelin-via-yarn.sh```)
* run ./setup-zeppelin-via-yarn.sh
Alternatively this single step after the repository is cloned

```
cd clusterdock-with-zeppelin; cat ./setup-zeppelin-via-yarn.sh | bash
```

If everything goes fine there should be a newly started Zeppelin container (called zepl, if you didn't edit the script)

The only remaining thing to do is to open the Zeppelin interface (go to your-docker-host:8080), click the Top Right menu (where it says "anonymous"), click Interpreter and scroll (all the way down) to the paragraph that says

```spark %spark , %spark.sql , %spark.dep , %spark.pyspark , %spark.r  ```

Click Edit in this paragraph and then fill in *yarn-client* in the box next to 'master' and add in the Dependencies section the following *org.apache.spark:spark-streaming-kafka_2.10:1.6.0*

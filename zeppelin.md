# Kafka + SparkSQL + Spark ML example

## Intro

We will be using some real-time streaming data coming from the RSVP activities of people responding to meetups on meetup.com. The stream is available at http://stream.meetup.com/2/rsvps

Once the containers are linked and (more importantly) running, go to <host_name_or_ip>:8080 (<hostname_or_ip> is the host where the docker containers are running) and create a new notebook with %spark as default interpretor

Before running the code below in the notebook make sure to start a Kafka console producer (from the meetup.com stream) with this command

```
curl -s "http://stream.meetup.com/2/rsvps"  | kafka-console-producer --broker-list node-2.cluster:9092 --topic msg
```

(since we're using clusterdock, the default hostnames are node-1.cluster, node-2.cluster, make sure to list a host where a Kafka Broker is running - as it was defined during Kafka activation)

## Zeppelin Notebook

Start with a following lines (they can go all in a cell) 

```
import org.apache.spark.streaming._
import org.apache.spark.streaming.kafka._
import _root_.kafka.serializer.StringDecoder
import org.apache.spark.sql.SaveMode
import org.apache.spark.sql.Row
```
We're doing nothing more than import some of the classes we'll be using. We needed to prefix the kafka.serializer with ```_root_``` because some kafka classes are in a kafka (no domain) package

Then we'll define some config variables (they can go in a separate cell)
```
val kafkaConf = Map("metadata.broker.list" -> "node-2.cluster:9092")

val topics = Set("msg")
```
You can use the same broker as the one the stream from meetup.com goes to (or, if you configured multiple brokers, any of them will do)

The schema of the JSON files that come from meetup.com is that of a denormalized table, i.e. for each RSVP there are details about the event, group, member and venue. The structure is this 
```
root
 |-- event: struct (nullable = true)
 |    |-- event_id: string (nullable = true)
 |    |-- event_name: string (nullable = true)
 |    |-- event_url: string (nullable = true)
 |    |-- time: long (nullable = true)
 |-- group: struct (nullable = true)
 |    |-- group_city: string (nullable = true)
 |    |-- group_country: string (nullable = true)
 |    |-- group_id: long (nullable = true)
 |    |-- group_lat: double (nullable = true)
 |    |-- group_lon: double (nullable = true)
 |    |-- group_name: string (nullable = true)
 |    |-- group_state: string (nullable = true)
 |    |-- group_topics: array (nullable = true)
 |    |    |-- element: struct (containsNull = true)
 |    |    |    |-- topic_name: string (nullable = true)
 |    |    |    |-- urlkey: string (nullable = true)
 |-- guests: long (nullable = true)
 |-- member: struct (nullable = true)
 |    |-- member_id: long (nullable = true)
 |    |-- member_name: string (nullable = true)
 |    |-- other_services: struct (nullable = true)
 |    |    |-- facebook: struct (nullable = true)
 |    |    |    |-- identifier: string (nullable = true)
 |    |    |-- twitter: struct (nullable = true)
 |    |    |    |-- identifier: string (nullable = true)
 |    |-- photo: string (nullable = true)
 |-- mtime: long (nullable = true)
 |-- response: string (nullable = true)
 |-- rsvp_id: long (nullable = true)
 |-- venue: struct (nullable = true)
 |    |-- lat: double (nullable = true)
 |    |-- lon: double (nullable = true)
 |    |-- venue_id: long (nullable = true)
 |    |-- venue_name: string (nullable = true)
 |-- visibility: string (nullable = true)
```

In order to accomodate this schema we'll staticaly define it using this code (in a new Zeppelin Notebook cell)

```
import org.apache.spark.sql.types._

val event =  (new StructType).add("event_id", StringType).add("event_name",StringType).add("event_url",StringType).add("time",LongType)
val group =  (new StructType).add("group_city",StringType).add("group_country",StringType).add("group_id",LongType).add("group_lat",DoubleType).add("group_lon",DoubleType).add("group_name",StringType).add("group_state",StringType).add("group_topics",ArrayType((new StructType).add("topic_name",StringType).add("urlkey",StringType)))
val member = (new StructType).add("member_id",LongType).add("member_name",StringType).add("other_services",(new StructType).add("facebook",(new StructType).add("identifier",StringType)).add("twitter",(new StructType).add("identifier",StringType))).add("photo",StringType)
val venue = (new StructType).add("lat",DoubleType).add("lon",DoubleType).add("venue_id",LongType).add("venue_name",StringType)
val schema = (new StructType).add("event",event).add("group",group).add("guests",LongType)
.add("member",member).add("mtime",LongType).add("response",StringType).add("rsvp_id",LongType).add("venue",venue).add("visibility",StringType)
```
So far we've only did preparations, let's now actually define the stream that reads from the Kafka topic and saves it to a SparkSQL table 

First we put our hands on a handle of a Spark Streaming Context (with 5 seconds batches)
```
val ssc = StreamingContext.getActiveOrCreate(() => new StreamingContext(sc, Seconds(5)))
```
Then we create a stream using this context, we know that the messages will only contain texts, so String and StringDecoder will do. And since Kafka is providing keyed messages (i.e. key=>value pairs), since we did not specify any key when producing them, all messages will have null as key so we'll just keep the value (hence the ```map(_._2)```)
```
val strm = KafkaUtils.createDirectStream[String, String, StringDecoder,StringDecoder](ssc,kafkaConf,topics).map(_._2)
```
We then create an empty table (from an empty dataframe with the previously defined schema
```
sqlContext.createDataFrame(sc.emptyRDD[Row], schema).write.mode("overwrite").saveAsTable("rsvps")
```
And lastly we read each RDD in stream and save it to the table
```
strm.foreachRDD { rdd =>sqlContext.read.schema(schema).json(rdd).write.mode(SaveMode.Append).saveAsTable("rsvps")}
```
The only thing needed now is to start the stream and that's quite straightforward 
```
ssc.start()
```
Once the stream is started, you can run 'regular' SQL queries on the *rsvps* table (don't forget to prefix cells with %sql) like this 
```
%sql
select * from rsvps order by mtime desc limit 100
```


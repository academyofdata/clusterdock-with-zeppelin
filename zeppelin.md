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

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




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

Now let's do some analytics. We run this directly and not in in SparkSQL (i.e. using %sql) because we needed to refer to the results as dataframes later on. For this extremely simplistic forecast model we'll want to predict the number of RSVPs per hour, so we'll aggregate the data on a daily + hourly base, furthermore since we know that people tend to respond less to meetups during weekends we'll use this as an input variable (in machine learning lingo we'll call this 'feature'). And since the hour is the most important input we'll try to convert each hour in a feature (that is, we'll have columns for each hour) and this is done using the pivot function (see an explanatory post about pivot function here  https://databricks.com/blog/2016/02/09/reshaping-data-with-pivot-in-apache-spark.html)

```
val meetup = sqlContext.sql("""
    select dy,hr,weekend_day,count(rsvp_id) as rsvp_cnt 
    from (
        select 
            from_unixtime(cast(mtime/1000 as bigint), 'yyyy-MM-dd') as dy,
            from_unixtime(cast(mtime/1000 as bigint), 'HH') as hr,
            case when from_unixtime(cast(mtime/1000 as bigint),'EEEE') in ('Saturday','Sunday') then 1 else 0 end as weekend_day,
            rsvp_id
        from  rsvps
        where mtime is not null
    ) subq
    group by dy,hr,weekend_day""")
var meetupData = meetup.groupBy("dy","weekend_day","hr","rsvp_cnt").pivot("hr").count().orderBy("dy")
```

Based on how long the producer stream will run we might end up with events that don't cover every hour (e.g. we might not have rsvps that came during 2am-3am), so we first complete the results with empty columns holding 0 for the hours where we don't have data

```
///add missing columns if the data is somehow "sparse"
(0 to 23).map(x => ("0"+x.toString) takeRight 2).foreach( x => {
    if(meetupData.schema.fields.filter(x == _.name).length == 0)  meetupData = meetupData.withColumn(x, lit(0: Long))
})
//change column order

meetupData = meetupData.select("dy","weekend_day","hr","rsvp_cnt","00", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23")

```

Let's define a helper function

```
def toVector(row:Row):Array[Double] = {
    (Array[Double](1.0,row(1).toString().toDouble, 
                                                 row(4).toString().toDouble,row(5).toString().toDouble, 
                                                 row(6).toString().toDouble,row(7).toString().toDouble,
                                                 row(8).toString().toDouble,row(9).toString().toDouble,
                                                 row(10).toString().toDouble,row(11).toString().toDouble, 
                                                 row(12).toString().toDouble,row(13).toString().toDouble,
                                                 row(14).toString().toDouble,row(15).toString().toDouble,
                                                 row(16).toString().toDouble,row(17).toString().toDouble,
                                                 row(18).toString().toDouble,row(19).toString().toDouble,
                                                 row(20).toString().toDouble,row(21).toString().toDouble, 
                                                 row(22).toString().toDouble,row(23).toString().toDouble,
                                                 row(24).toString().toDouble,row(25).toString().toDouble, 
                                                 row(26).toString().toDouble,row(27).toString().toDouble))
}
```

Now we have all the data prepared as we will needed to apply some basic ML techniques on it. We'll try to apply a supervised learning algorithm so we need to train the model using the data that we have. Since we're trying to forecast the RSVPs per hour, that's the 'label' (hence the reference to row(3)) and the rest of the data for the respective hour are the features that need to be taken into consideration.

```
import org.apache.spark.mllib.regression.RidgeRegressionWithSGD
import org.apache.spark.mllib.linalg.Vectors
import org.apache.spark.mllib.regression.LabeledPoint
val trainingData = meetupData.map { row =>
      LabeledPoint(row(3).toString().toDouble, Vectors.dense(toVector(row)))
}
trainingData.cache()
val model = new RidgeRegressionWithSGD().run(trainingData)
```
We trained the model using the data received let's now see what results do we get if we try to forecast the number of RSVPs for exactly the same date and hours (so that we can see how far we are with the prediction from the model vs actual data)

```
val scores = meetupData.map { row =>
       (row(0),row(2),row(3), model.predict(Vectors.dense(toVector(row))).toInt) 
}
scores.take(40).foreach(println)
```


# Kafka + SparkSQL + Spark ML example

We will be using some real-time streaming data coming from the RSVP activities of people responding to meetups on meetup.com. The stream is available at http://stream.meetup.com/2/rsvps

Once the containers are linked and (more importantly) running, go to <host_name_or_ip>:8080 (<hostname_or_ip> is the host where the docker containers are running) and create a new notebook with %spark as default interpretor

Before running the code below in the notebook make sure to start a kafka console producer (from the meetup.com stream) with this command

```
curl -s "http://stream.meetup.com/2/rsvps"  | kafka-console-producer --broker-list node-2.cluster:9092 --topic msg
```

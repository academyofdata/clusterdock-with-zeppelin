# clusterdock-with-zeppelin

script to link a dockerized zeppelin to a cluster running Cloudera's dockerized CDH (called clusterdock)

Since a standalone Zeppelin comes with an own Apache Spark interpreter, we need to download the Spark binaries (ver 1.6, the same used in CDH provided in clusterdock, i.e. CDH 5.8 provides Spark 1.6.0)

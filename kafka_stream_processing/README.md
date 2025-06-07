# Wikimedia Stream Processing with ksqlDB

This project demonstrates real-time stream processing of Wikimedia RecentChanges events using Apache Kafka and ksqlDB.

1. Install and configure Confluent Kafka on a Switch VM
2. Connect to the Wikimedia stream
3. Define ksqlDB streams and tables for various aggregations
4. Run pull and push queries to analyze Wikipedia edit activity

---

## Table of Contents

* [Prerequisites](#prerequisites)
* [1. Kafka & Confluent Setup](#1-kafka--confluent-setup)
  * [1.1 SSH & Port Forwarding](#11-ssh--port-forwarding)
  * [1.2 Starting Docker Services](#12-starting-docker-services)
  * [1.3 Verifying Services](#13-verifying-services)
  * [1.4 Accessing the Control Center](#14-accessing-the-control-center)
* [2. Tasks](#2-tasks)
  * [Task 1: Creating the ksqlDB Stream](#task-1-creating-the-ksqldb-stream)
  * [Task 2: Domain with Most Changes](#task-2-domain-with-most-changes)
  * [Task 3: Number of Bots](#task-3-number-of-bots)
  * [Task 4: Type of Change](#task-4-type-of-change)
  * [Task 5: Most Frequently Used Words](#task-5-most-frequently-used-words)
* [References](#references)

---

## Prerequisites

* A Switch VM with Docker installed and SSH access
* SSH private key from SWITCHengines
* Basic familiarity with Bash, Docker and ksqlDB

---

## 1. Kafka & Confluent Setup

### 1.1 SSH & Port Forwarding

**Windows (MobaXTerm)**

1. Tools → MobaSSHTunnel → New SSH tunnel
2. Forward local **8088 → remote 8088** and **9021 → 9021**
3. SWITCHengines private key

**Linux/macOS**

```bash
ssh -L 8088:localhost:8088 -L 9021:localhost:9021 \
  -i ~/.ssh/your_private_key \
  your_user@vm_ip
```

To simplify, add to `~/.ssh/config`:

```ssh-config
Host your_host_name
  HostName <vm_ip>
  User ubuntu
  LocalForward 8088 127.0.0.1:8088
  LocalForward 9021 127.0.0.1:9021
  IdentityFile ~/.ssh/your_private_key
```

### 1.2 Starting Docker Services

```bash
sudo su # become root
cd /home/ubuntu/confluent-kafka-deployment/
docker-compose up -d
```

### 1.3 Verifying Services

```bash
docker ps
```

Ensure all containers (broker, zookeeper, schema-registry, control-center, ksqldb-server, connect, etc.) show `Up (healthy)`

### 1.4 Accessing the Control Center

Point your browser to:

* **Control Center UI**: `http://localhost:9021`
* **ksqlDB CLI** (in Docker):

```bash
docker exec -it ksqldb-cli ksql [http://ksqldb-server:8088](http://ksqldb-server:8088)
```

---

## 2. Tasks
### Task 1: Creating the ksqlDB Stream

In the ksqlDB CLI, define the stream over the `wikimedia_recentchange` topic:

```sql
CREATE STREAM WIKIMEDIA_RECENTCHANGES_STREAM (
  meta STRUCT<
    domain VARCHAR,
    dt TIMESTAMP,
    id VARCHAR,
    request_id VARCHAR,
    uri VARCHAR
  >,
  id BIGINT,
  type VARCHAR,
  title VARCHAR,
  comment VARCHAR,
  parsedcomment VARCHAR,
  timestamp BIGINT,
  user VARCHAR,
  bot BOOLEAN,
  server_url VARCHAR,
  server_name VARCHAR,
  server_script_path VARCHAR,
  wiki VARCHAR
) WITH (
  kafka_topic = 'wikimedia_recentchange',
  value_format = 'AVRO',
  key_format   = 'JSON',
  partitions   = 1,
  TIMESTAMP    = 'timestamp'
);

```


### Task 2: Domain with Most Changes

**Create materialized view:**

```sql
CREATE TABLE NUMBER_MESSAGES_DOMAIN_TABLE WITH (kafka_topic='number_messages_domain') AS
SELECT META->DOMAIN, 
    COUNT(*) AS NUMBER_MSG_DOMAIN
    FROM  WIKIMEDIA_RECENTCHANGES_STREAM 
    GROUP BY META->DOMAIN
EMIT CHANGES;
```

**Pull & Push query:**

```sql
SELECT * FROM NUMBER_MESSAGES_DOMAIN_TABLE EMIT CHANGES;
SELECT * FROM NUMBER_MESSAGES_DOMAIN_TABLE;
```

Sample output:

```json
{"DOMAIN":"commons.wikimedia.org","NUMBER_MSG_DOMAIN":6779}
```

---

### Task 3: Number of Bots

#### 3.1 Global Bot Percentage

```sql
CREATE TABLE NUMBER_BOTS_TABLE WITH (kafka_topic='number_of_bots') AS
SELECT
	1,
    Count(*) AS ALL_MESSAGES,
    SUM(CASE WHEN bot=true THEN 1 ELSE 0 END) AS NR_OF_BOT_MESSAGES,
   	ROUND(
      CAST(SUM(CASE WHEN bot=true THEN 1 ELSE 0 END ) AS DOUBLE)
      	/
      COUNT(*),3) AS PERCENT_BOT_MESSAGES
FROM WIKIMEDIA_RECENTCHANGES_STREAM
GROUP BY 1
EMIT CHANGES;
```

```sql
SELECT * FROM NUMBER_BOTS_TABLE EMIT CHANGES;
SELECT * FROM NUMBER_BOTS_TABLE;
```

Sample output:

```json
{"KSQL_COL_0":1,"ALL_MESSAGES":129791,"NR_OF_BOT_MESSAGES":45890,"PERCENT_BOT_MESSAGES":0.354}
```

#### 3.2 Bot Fraction per Domain

```sql
CREATE TABLE NUMBER_BOTS_DOMAIN_TABLE WITH (kafka_topic='number_bots_domain')AS
SELECT
	META->DOMAIN,
    Count(*) AS TOTAL_MESSAGES,
    SUM(CASE WHEN bot=true THEN 1 ELSE 0 END) AS NUMBER_BOT_MESSAGES,
   	ROUND(
      CAST(SUM(CASE WHEN bot=true THEN 1 ELSE 0 END ) AS DOUBLE)
      	/
      COUNT(*),3) AS PERCENT_BOT_MESSAGES
FROM WIKIMEDIA_RECENTCHANGES_STREAM
GROUP BY META->DOMAIN
EMIT CHANGES;
```

```sql
SELECT * FROM NUMBER_BOTS_DOMAIN_TABLE EMIT CHANGES;
SELECT * FROM NUMBER_BOTS_DOMAIN_TABLE;
```

Sample output:

```json
{"DOMAIN":"ru.wikiquote.org","TOTAL_MESSAGES":169,"NUMBER_BOT_MESSAGES":169,"PERCENT_BOT_MESSAGES":1}
{"DOMAIN":"zu.wikipedia.org","TOTAL_MESSAGES":1,"NUMBER_BOT_MESSAGES":0,"PERCENT_BOT_MESSAGES":0}
```

#### 3.3 Tumbling-Window Bot Rate (10s)

```sql
CREATE TABLE NR_BOTS_TUMBL10S_TBL
  WITH (
    kafka_topic  = 'nr_bots_tumbling10s',
    value_format = 'JSON'
  ) AS
SELECT
  'ALL' AS category,
  COUNT(*) AS total_messages,
  SUM(CASE WHEN bot = TRUE THEN 1 ELSE 0 END) AS number_bot_messages,
  ROUND(
    CAST(SUM(CASE WHEN bot = TRUE THEN 1 ELSE 0 END) AS DOUBLE)
    / COUNT(*)
  , 3) AS percent_bot_messages,
  TIMESTAMPTOSTRING(WINDOWSTART, 'yyyy-MM-dd HH:mm:ss','UTC') AS window_start,
  TIMESTAMPTOSTRING(WINDOWEND,   'yyyy-MM-dd HH:mm:ss','UTC') AS window_end,
  TIMESTAMPTOSTRING(MIN(timestamp), 'yyyy-MM-dd HH:mm:ss','UTC') AS ts_min,
  TIMESTAMPTOSTRING(MAX(timestamp), 'yyyy-MM-dd HH:mm:ss','UTC') AS ts_max
FROM WIKIMEDIA_RECENTCHANGES_STREAM
WINDOW TUMBLING ( SIZE 10 SECONDS )
GROUP BY 'ALL'
EMIT CHANGES;
```

```sql
SELECT * FROM NR_BOTS_TUMBL10S_TBL EMIT CHANGES;
SELECT * FROM NR_BOTS_TUMBL10S_TBL;
```

Sample output:

```json
{
  "CATEGORY": "ALL",
  "WINDOWSTART": 1748280000,
  "WINDOWEND": 1748290000,
  "TOTAL_MESSAGES": 1741,
  "NUMBER_BOT_MESSAGES": 711,
  "PERCENT_BOT_MESSAGES": 0.408,
  "WINDOW_START": "1970-01-21 05:38:00",
  "WINDOW_END": "1970-01-21 05:38:10",
  "TS_MIN": "1970-01-21 05:38:05",
  "TS_MAX": "1970-01-21 05:38:05"
}

```

#### 3.4 Windowed Bot Rate by Domain

```sql
CREATE TABLE NR_BOTS_DOMAIN_TUMBL10S_TBL WITH (kafka_topic='nr_bots_domain_tumbl10s') AS
SELECT
       meta->domain,
    Count(*) AS TOTAL_MESSAGES,
    SUM(CASE WHEN bot=true THEN 1 ELSE 0 END) AS NR_BOT_MESSAGES,
    ROUND(
        CAST(SUM(CASE WHEN bot=true THEN 1 ELSE 0 END) AS DOUBLE) /
        COUNT(*), 3) AS PERCENT_BOT_MESSAGES,
    FORMAT_TIMESTAMP(
        FROM_UNIXTIME(WINDOWSTART),'yyyy-MM-dd HH:mm:ss', 'UTC') AS time_start,
    FORMAT_TIMESTAMP(
        FROM_UNIXTIME(WINDOWEND),'yyyy-MM-dd HH:mm:ss', 'UTC') AS time_end
FROM WIKIMEDIA_RECENTCHANGES_STREAM
WINDOW TUMBLING (SIZE 10 SECONDS)
GROUP BY meta->domain
EMIT CHANGES;
```

```sql
SELECT * FROM NR_BOTS_DOMAIN_TUMBL10S_TBL EMIT CHANGES;
SELECT * FROM NR_BOTS_DOMAIN_TUMBL10S_TBL;
```

Sample output:

```json
{
  "DOMAIN": "hu.wikipedia.org",
  "WINDOWSTART": 1748280000,
  "WINDOWEND": 1748290000,
  "TOTAL_MESSAGES": 24,
  "NR_BOT_MESSAGES": 0,
  "PERCENT_BOT_MESSAGES": 0,
  "TIME_START": "1970-01-21 05:38:00",
  "TIME_END": "1970-01-21 05:38:10"
}
```

---

### Task 4: Type of Change

#### 4.1 Change Counts Overall

```sql
CREATE TABLE NR_TYPE_TBL
  WITH (
    kafka_topic  = 'nr_type',
    value_format = 'JSON'
  ) AS
SELECT
  type            AS change_type,
  COUNT(*)        AS type_count
  FROM WIKIMEDIA_RECENTCHANGES_STREAM
GROUP BY type
EMIT CHANGES;
```

```sql
SELECT * FROM NR_TYPE_TBL EMIT CHANGES;
SELECT * FROM NR_TYPE_TBL;
```

Sample output:

```json
{"CHANGE_TYPE":"new","TYPE_COUNT":4532}
```

#### 4.2 Change Counts per Domain

```sql
CREATE TABLE TYPE_DOMAIN_TABLE
  WITH (
    kafka_topic   = 'number_type_domain',
    value_format  = 'JSON'
  ) AS
SELECT
  meta->domain AS domain,
  type AS change_type,
  COUNT(*) AS nr_messages
FROM WIKIMEDIA_RECENTCHANGES_STREAM
GROUP BY
  meta->domain,
  type
EMIT CHANGES;
```

```sql
SELECT * FROM TYPE_DOMAIN_TABLE EMIT CHANGES;
SELECT * FROM TYPE_DOMAIN_TABLE;
```

Sample output:

```json
{
  "DOMAIN": "it.wikivoyage.org",
  "CHANGE_TYPE": "log",
  "NR_MESSAGES": 4
}
```

---

### Task 5: Most Frequently Used Words

1. **Regex-Based Word Extraction**:

```sql
CREATE STREAM WORDS_STREAM AS
SELECT  meta->Domain AS domain,
  EXPLODE(REGEXP_EXTRACT_ALL(LCASE(comment),'\\b(?!\\d+\\b)\\w+\\b')) AS word
FROM WIKIMEDIA_RECENTCHANGES_STREAM;
```

```sql
CREATE TABLE WORD_COUNT_OVERALL AS
SELECT domain, word, COUNT(*) AS observations
FROM WORDS_STREAM
GROUP BY domain, word;
```

```sql
SELECT * FROM WORD_COUNT_OVERALL
WHERE domain='de.wikipedia.org';
```

Sample output:

```json
{"DOMAIN":"de.wikipedia.org","WORD":"","OBSERVATIONS":550}
```

2. **Simple Split-Based Tokenization**:

```sql
CREATE STREAM WORDS__FREQ_OVERALL AS
SELECT SERVER_URL,
  EXPLODE(SPLIT(COMMENT, ' ')) AS word
FROM WIKIMEDIA_RECENTCHANGES_STREAM;
```

```sql
CREATE STREAM GERMAN_WORDS AS
SELECT * FROM WORDS__FREQ_OVERALL
WHERE SERVER_URL = 'https://de.wikipedia.org';
```

```sql
SELECT WORD, 
	Count(*) AS TOTAL_WORDS
FROM  GERMAN_WORDS 
GROUP BY WORD 
EMIT CHANGES;
```

Sample output:

```json
{"WORD":"Kategorie","TOTAL_WORDS":386}
```

---

## References

* **Stream Processing Concepts in ksqlDB for Confluent Platform** https://docs.confluent.io/platform/current/ksqldb/concepts/overview.html
* **Queries in ksqlDB for Confluent Platform** https://docs.confluent.io/platform/current/ksqldb/concepts/queries.html
* **Time and Windows in ksqlDB for Confluent Platform** https://docs.confluent.io/platform/current/ksqldb/concepts/time-and-windows-in-ksqldb-queries.html
* **How Real-Time Materialized Views Work with ksqlDB, Animated** https://www.confluent.io/blog/how-real-time-materialized-views-work-with-ksqldb/
* **Exploring ksqlDB with Twitter Data** https://www.confluent.io/blog/stream-processing-twitter-data-with-ksqldb/



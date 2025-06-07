# Modern Data Engineering Projects

This repository contains two independent data engineering projects, each focusing on a specific aspect of modern data pipelines: real-time stream processing and batch ETL workflows. The goal is to explore end-to-end implementations using industry-standard tools and best practices.

---

## Project Overview

### 📡 `kafka_stream_processing`
**Wikimedia Stream Processing with ksqlDB**

This project demonstrates real-time stream processing using Apache Kafka and ksqlDB, applied to Wikimedia's live RecentChanges feed. It includes:

- Setting up Confluent Kafka on a cloud VM
- Connecting to the Wikimedia event stream
- Defining ksqlDB streams and materialized tables
- Executing push/pull queries for insights such as:
  - Top edited domains
  - Bot activity percentage
  - Change types and frequency
  - Most frequent words in edit comments

The project shows how to build low-latency dashboards and streaming analytics from a live data source.

👉 See [`kafka_stream_processing/`](./kafka_stream_processing/) for full implementation details and SQL queries.

---

### 🛠️ `etl_apache_hop`
**ETL Pipeline for XML Job Postings using Apache Hop**

This batch ETL case study focuses on transforming semi-structured XML job data into structured format for analysis. It covers:

- Extracting and cleaning raw job postings from XML files and metadata tables
- Loading standardized data into an Azure SQL Database
- Applying a 3-layer staging model:
  - **Stage 1**: Raw imports
  - **Stage 2**: Cleaned data
  - **Stage 3**: Enriched data for analytics
- Visualizing results in Power BI:
  - Job posting durations
  - Industry-wise vacancy distribution

Apache Hop was used to build and orchestrate the ETL pipelines in a modular and traceable way.

👉 See [`etl_apache_hop/`](./etl_apache_hop/) for project files and workflow setup.

---

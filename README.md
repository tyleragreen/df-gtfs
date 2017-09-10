# PostgreSQL GTFS Schema

PostgreSQL schema for GTFS feeds from across the world.

The best resource for up-to-date GTFS feeds is [TransitFeeds](www.transitfeeds.com).

## Nothing Overwhelming Here

The differences between the various agencies `schema.sql` files is based on the different optional fields and file in an agency's feed. The columns in a table should match with the header row of a GTFS file.

A potential future enhancement is a pre-processing script which builds a `schema.sql` file for a given GTFS feed based on the presence of optional fields and files. 

## Usage

Use the following template command to load a GTFS feed into a Postgres database:
```
psql --host=<db_host> --port=<port> --username=<db_username> --dbname=<dbname> --file=schema.sql --password
```
You will be prompted to enter the password for the provided db user and then the `schema.sql` script will begin executing on the host. Depending on the size of the `stop_times.txt` file (some are a few million rows), the process may take up to 30 minutes.

The output should look like:
```
DROP TABLE
DROP TABLE
DROP TABLE
DROP TABLE
DROP TABLE
DROP TABLE
DROP TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
```

## Contribute

Feel free to submit a PR to contribute a new schema.

## GTFS Schema Visualized

Image from [chroman](https://github.com/chroman/)'s original [df-gtfs](https://github.com/chroman/df-gtfs) repo.

![Image](http://i.imgur.com/wET9rPp.png)

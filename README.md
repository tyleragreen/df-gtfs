# PostgreSQL GTFS Schema
PostgreSQL schema for GTFS feeds from across the world.

Current GTFS feeds can be found at www.transitfeeds.com.

## Future Work

The GTFS schemas are currently maintained separately per agency due to the presence of optional fields and files. Each agency uses these optional items slightly differently. A future enhancement may be a pre-processing script which produces a schema.sql file for a given GTFS feed based on the presence (or absence) of optional fields and files. 

## Contribute

Feel free to submit a PR to contribute a new schema.

## GTFS Schema Visualized

Image from [chroman](https://github.com/chroman/)'s original [df-gtfs](https://github.com/chroman/df-gtfs) repo.

![Image](http://i.imgur.com/wET9rPp.png)

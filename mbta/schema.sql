DROP TABLE agency;
DROP TABLE feed_info;
DROP TABLE stops;
DROP TABLE routes;
DROP TABLE calendar;
DROP TABLE calendar_dates;
DROP TABLE shapes;
DROP TABLE trips;
DROP TABLE stop_times;
DROP TABLE frequencies;
DROP TABLE transfers;

CREATE TABLE agency
(
  agency_id         text UNIQUE NULL,
  agency_name       text NOT NULL,
  agency_url        text NOT NULL,
  agency_timezone   text NOT NULL,
  agency_lang       text NULL,
  agency_phone      text NULL
);

CREATE TABLE feed_info (
  feed_publisher_name text NOT NULL,
  feed_publisher_url  text NOT NULL,
  feed_lang text NOT NULL,
  feed_start_date numeric(8) NULL,
  feed_end_date numeric(8) NULL,
  feed_version text NULL
);

CREATE TABLE stops
(
  stop_id           text PRIMARY KEY,
  stop_code         text NULL,
  stop_name         text NOT NULL,
  stop_desc         text NULL,
  stop_lat          double precision NOT NULL,
  stop_lon          double precision NOT NULL,
  zone_id           text NULL,
  stop_url          text NULL,
  location_type     boolean NULL,
  parent_station    text NULL,
  wheelchair_boarding text NULL
);

CREATE TABLE routes
(
  route_id          text PRIMARY KEY,
  agency_id         text NULL,
  route_short_name  text NULL,
  route_long_name   text NULL,
  route_desc        text NULL,
  route_type        integer NULL,
  route_url         text NULL,
  route_color       text NULL,
  route_text_color  text NULL,
  route_sort_order  integer NULL
);

CREATE TABLE calendar
(
  service_id        text PRIMARY KEY,
  monday            boolean NOT NULL,
  tuesday           boolean NOT NULL,
  wednesday         boolean NOT NULL,
  thursday          boolean NOT NULL,
  friday            boolean NOT NULL,
  saturday          boolean NOT NULL,
  sunday            boolean NOT NULL,
  start_date        numeric(8) NOT NULL,
  end_date          numeric(8) NOT NULL
);

CREATE TABLE calendar_dates
(
  service_id text NOT NULL,
  date numeric(8) NOT NULL,
  exception_type integer NOT NULL
);

CREATE TABLE shapes
(
  shape_id          text,
  shape_pt_lat      double precision NOT NULL,
  shape_pt_lon      double precision NOT NULL,
  shape_pt_sequence integer NOT NULL,
  shape_dist_traveled text NULL
);

CREATE TABLE trips
(
  route_id          text NOT NULL,
  service_id        text NOT NULL,
  trip_id           text NOT NULL PRIMARY KEY,
  trip_headsign     text NULL,
  trip_short_name   text NULL,
  direction_id      boolean NULL,
  block_id          text NULL,
  shape_id          text NULL,
  wheelchair_accessible text NULL
);

CREATE TABLE stop_times
(
  trip_id           text NOT NULL,
  arrival_time      interval NOT NULL,
  departure_time    interval NOT NULL,
  stop_id           text NOT NULL,
  stop_sequence     integer NOT NULL,
  stop_headsign     text NULL,
  pickup_type       integer NULL CHECK(pickup_type >= 0 and pickup_type <=3),
  drop_off_type     integer NULL CHECK(drop_off_type >= 0 and drop_off_type <=3)
);

CREATE TABLE frequencies
(
  trip_id           text NOT NULL,
  start_time        interval NOT NULL,
  end_time          interval NOT NULL,
  headway_secs      integer NOT NULL
);

CREATE TABLE transfers
(
    from_stop_id  text NOT NULL,
    to_stop_id    text NOT NULL,
    transfer_type   integer NOT NULL,
    min_transfer_time integer
);

\copy agency from './gtfs/agency.txt' with csv header
\copy feed_info from './gtfs/feed_info.txt' with csv header
\copy stops from './gtfs/stops.txt' with csv header
\copy routes from './gtfs/routes.txt' with csv header
\copy calendar from './gtfs/calendar.txt' with csv header
\copy calendar_dates from './gtfs/calendar_dates.txt' with csv header
\copy shapes from './gtfs/shapes.txt' with csv header
\copy trips from './gtfs/trips.txt' with csv header
\copy stop_times from './gtfs/stop_times.txt' with csv header
\copy frequencies from './gtfs/frequencies.txt' with csv header
\copy transfers from './gtfs/transfers.txt' with csv header

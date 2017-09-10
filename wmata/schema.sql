DROP TABLE agency;
DROP TABLE stops;
DROP TABLE routes;
DROP TABLE calendar_dates;
DROP TABLE shapes;
DROP TABLE trips;
DROP TABLE stop_times;

CREATE TABLE agency
(
  agency_id         text UNIQUE NULL,
  agency_name       text NOT NULL,
  agency_url        text NOT NULL,
  agency_timezone   text NOT NULL,
  agency_lang       text NULL,
  agency_phone      text NULL
);

CREATE TABLE stops
(
  stop_id           text PRIMARY KEY,
  stop_code         text NULL,
  stop_name         text NOT NULL,
  stop_desc         text NULL,
  stop_lat          double precision NOT NULL,
  stop_lon          double precision NOT NULL,
  zone_id           text NULL
);

CREATE TABLE routes
(
  route_id          text PRIMARY KEY,
  agency_id         text NULL,
  route_short_name  text NULL,
  route_long_name   text NULL,
  route_type        integer NULL,
  route_url         text NULL,
  route_color       text NULL
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
  direction_id      boolean NULL,
  block_id          text NULL,
  shape_id          text NULL,
  scheduled_trip_id text NULL
);

CREATE TABLE stop_times
(
  trip_id           text NOT NULL,
  arrival_time      interval NOT NULL,
  departure_time    interval NOT NULL,
  stop_id           text NOT NULL,
  stop_sequence     integer NOT NULL,
  pickup_type       integer NULL CHECK(pickup_type >= 0 and pickup_type <=3),
  drop_off_type     integer NULL CHECK(drop_off_type >= 0 and drop_off_type <=3),
  shape_dist_traveled double precision NULL
);

\copy agency from './gtfs/agency.txt' with csv header
\copy stops from './gtfs/stops.txt' with csv header
\copy routes from './gtfs/routes.txt' with csv header
\copy calendar_dates from './gtfs/calendar_dates.txt' with csv header
\copy shapes from './gtfs/shapes.txt' with csv header
\copy trips from './gtfs/trips.txt' with csv header
\copy stop_times from './gtfs/stop_times.txt' with csv header
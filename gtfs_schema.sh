#!/bin/bash

# Script to generate a PostgreSQL schema from a GTFS file.
#
# Usage: ./gtfs_schema.sh input-directory
#
# The GTFS format has mandatory as well as optional files and columns. Also the
# order of columns in the CSV files is not defined. Therefore a PostgreSQL
# schema to import the CSV files directly may look different for each data
# provider, depending on the files and columns they use.
#
# The scripts acts on a directory with the extracted contents of a GTFS file.
# It checks which files are present and prepares one table for each of them.
# Then it checks which columns are present and in which order and generates a
# column defintiion for each of them.
#
# Finally, the contents of the CSV files are imported into the database using
# PostgreSQL's \COPY mode.

usage() {
    echo "$0 -- Generate a SQL schema for a GTFS dataset"
    echo "Usage: $0 [input directory]"
}

# GTFS source directory: First parameter or working directory .
gtfsdir=${1:-.}
gtfsdir=${gtfsdir%/}

# Mapping of each file and column name to a PostgreSQL column defintion
# including the data type and constraints. A strict schema is generated where
# it is easily possible using e.g. check and foreign key constraints. Some
# softer constraints are not so easy to model and are omitted.
#
# Note there may be no whitespace around the =
declare -A COLUMN_DATA_TYPES
COLUMN_DATA_TYPES=(
    [agency.txt/agency_id]='text UNIQUE NULL'
    [agency.txt/agency_name]='text NOT NULL'
    [agency.txt/agency_url]='text NOT NULL'
    [agency.txt/agency_timezone]='text NOT NULL'
    [agency.txt/agency_lang]='text NULL'
    [agency.txt/agency_phone]='text NULL'
    [agency.txt/agency_fare_url]='text NULL'
    [agency.txt/agency_email]='text NULL'

    [stops.txt/stop_id]='text PRIMARY KEY'
    [stops.txt/stop_code]='text NULL'
    [stops.txt/stop_name]='text NULL CHECK (location_type >= 0 AND location_type <= 2 AND stop_name IS NOT NULL OR location_type > 2)'
    [stops.txt/stop_desc]='text NULL'
    [stops.txt/stop_lat]='double precision NULL CHECK (location_type >= 0 AND location_type <= 2 AND stop_name IS NOT NULL OR location_type > 2)'
    [stops.txt/stop_lon]='double precision NULL CHECK (location_type >= 0 AND location_type <= 2 AND stop_name IS NOT NULL OR location_type > 2)'
    [stops.txt/zone_id]='text NULL'
    [stops.txt/stop_url]='text NULL'
    [stops.txt/location_type]='integer NULL CHECK (location_type >= 0 AND location_type <= 4)'
    [stops.txt/parent_station]='text NULL CHECK (location_type IS NULL OR location_type = 0 OR location_type = 1 AND parent_station IS NULL OR location_type >= 2 AND location_type <= 4 AND parent_station IS NOT NULL)'
    [stops.txt/stop_timezone]='text NULL'
    [stops.txt/wheelchair_boarding]='integer NULL CHECK (wheelchair_boarding >= 0 AND wheelchair_boarding <= 2 OR wheelchair_boarding IS NULL)'
    [stops.txt/level_id]='text NULL REFERENCES levels ON DELETE CASCADE ON UPDATE CASCADE'
    [stops.txt/platform_code]='text NULL'
    [stops.txt/vehicle_type]='integer NULL'

    [routes.txt/route_id]='text PRIMARY KEY'
    [routes.txt/agency_id]='text NULL REFERENCES agency(agency_id) ON DELETE CASCADE ON UPDATE CASCADE'
    [routes.txt/route_short_name]='text NULL'
    [routes.txt/route_long_name]='text NULL CHECK (route_short_name IS NOT NULL OR route_long_name IS NOT NULL)'
    [routes.txt/route_desc]='text NULL'
    [routes.txt/route_type]='integer NOT NULL'
    [routes.txt/route_url]='text NULL'
    [routes.txt/route_color]="text NULL CHECK (route_color ~ \$\$[a-fA-F0-9]{6}\$\$ OR route_color = '')"
    [routes.txt/route_text_color]="text NULL CHECK (route_color ~ \$\$[a-fA-F0-9]{6}\$\$ OR route_color = '')"
    [routes.txt/route_sort_order]='integer NULL CHECK (route_sort_order >= 0)'

    [trips.txt/route_id]='text NOT NULL REFERENCES routes ON DELETE CASCADE ON UPDATE CASCADE'
    [trips.txt/service_id]='text NOT NULL'
    [trips.txt/trip_id]='text NOT NULL PRIMARY KEY'
    [trips.txt/trip_headsign]='text NULL'
    [trips.txt/trip_short_name]='text NULL'
    [trips.txt/direction_id]='boolean NULL'
    [trips.txt/block_id]='text NULL'
    [trips.txt/shape_id]='text NULL'
    [trips.txt/wheelchair_accessible]='integer NULL CHECK (wheelchair_accessible >= 0 AND wheelchair_accessible <= 2)'
    [trips.txt/bikes_allowed]='integer NULL CHECK (bikes_allowed >= 0 AND bikes_allowed <= 2)'
    [trips.txt/exceptional]='boolean NULL'

    [stop_times.txt/trip_id]='text NOT NULL REFERENCES trips ON DELETE CASCADE ON UPDATE CASCADE'
    [stop_times.txt/arrival_time]='interval NULL'
    [stop_times.txt/departure_time]='interval NOT NULL'
    [stop_times.txt/stop_id]='text NOT NULL REFERENCES stops ON DELETE CASCADE ON UPDATE CASCADE'
    [stop_times.txt/stop_sequence]='integer NOT NULL CHECK (stop_sequence >= 0)'
    [stop_times.txt/stop_headsign]='text NULL'
    [stop_times.txt/pickup_type]='integer NOT NULL CHECK (pickup_type >= 0 AND pickup_type <= 3)'
    [stop_times.txt/drop_off_type]='integer NOT NULL CHECK (drop_off_type >= 0 AND drop_off_type <= 3)'
    [stop_times.txt/shape_dist_traveled]='double precision NULL CHECK (shape_dist_traveled >= 0.0)'
    [stop_times.txt/timepoint]='boolean NULL'

    [calendar.txt/service_id]='text PRIMARY KEY'
    [calendar.txt/monday]='boolean NOT NULL'
    [calendar.txt/tuesday]='boolean NOT NULL'
    [calendar.txt/wednesday]='boolean NOT NULL'
    [calendar.txt/thursday]='boolean NOT NULL'
    [calendar.txt/friday]='boolean NOT NULL'
    [calendar.txt/saturday]='boolean NOT NULL'
    [calendar.txt/sunday]='boolean NOT NULL'
    [calendar.txt/start_date]='numeric(8) NOT NULL'
    [calendar.txt/end_date]='numeric(8) NOT NULL'

    [calendar_dates.txt/service_id]='text NOT NULL'
    [calendar_dates.txt/date]='numeric(8) NOT NULL'
    [calendar_dates.txt/exception_type]='integer NOT NULL CHECK (exception_type >= 1 AND exception_type <= 2)'

    [fare_attributes.txt/fare_id]='text PRIMARY KEY'
    [fare_attributes.txt/price]='double precision NOT NULL CHECK (price >= 0.0)'
    [fare_attributes.txt/currency_type]='text NOT NULL'
    [fare_attributes.txt/payment_method]='boolean NOT NULL'
    [fare_attributes.txt/transfers]='integer NULL CHECK (transfers >= 0 AND transfers <= 5)'
    [fare_attributes.txt/agency_id]='text NULL REFERENCES agency(agency_id) ON DELETE CASCADE ON UPDATE CASCADE'
    [fare_attributes.txt/transfer_duration]='integer NULL CHECK (transfer_duration >= 0)'

    [fare_rules.txt/fare_id]='text NOT NULL REFERENCES fare_attributes ON DELETE CASCADE ON UPDATE CASCADE'
    [fare_rules.txt/route_id]='text NULL REFERENCES routes ON DELETE CASCADE ON UPDATE CASCADE'
    [fare_rules.txt/origin_id]='text NULL'
    [fare_rules.txt/destination_id]='text NULL'
    [fare_rules.txt/contains_id]='text NULL'

    [shapes.txt/shape_id]='text NOT NULL'
    [shapes.txt/shape_pt_lat]='double precision NOT NULL'
    [shapes.txt/shape_pt_lon]='double precision NOT NULL'
    [shapes.txt/shape_pt_sequence]='integer NOT NULL CHECK (shape_pt_sequence >= 0)'
    [shapes.txt/shape_dist_traveled]='double precision NULL CHECK (shape_dist_traveled >= 0.0)'

    [frequencies.txt/trip_id]='text NOT NULL REFERENCES trips ON DELETE CASCADE ON UPDATE CASCADE'
    [frequencies.txt/start_time]='interval NOT NULL'
    [frequencies.txt/end_time]='interval NOT NULL'
    [frequencies.txt/headway_secs]='integer NOT NULL CHECK (headway_secs >= 0)'
    [frequencies.txt/exact_times]='boolean NULL'

    [transfers.txt/from_stop_id]='text NOT NULL REFERENCES stops(stop_id) ON DELETE CASCADE ON UPDATE CASCADE'
    [transfers.txt/to_stop_id]='text NOT NULL REFERENCES stops(stop_id) ON DELETE CASCADE ON UPDATE CASCADE'
    [transfers.txt/transfer_type]='integer NOT NULL CHECK (transfer_type >= 0 AND transfer_type <= 3)'
    [transfers.txt/min_transfer_time]='integer NULL CHECK (min_transfer_time >= 0)'
    [transfers.txt/from_route_id]='text NULL'
    [transfers.txt/to_route_id]='text NULL'
    [transfers.txt/from_trip_id]='text NULL'
    [transfers.txt/to_trip_id]='text NULL'

    [pathways.txt/pathway_id]='text PRIMARY KEY'
    [pathways.txt/from_stop_id]='text NOT NULL REFERENCES stops(stop_id) ON DELETE CASCADE ON UPDATE CASCADE'
    [pathways.txt/to_stop_id]='text NOT NULL REFERENCES stops(stop_id) ON DELETE CASCADE ON UPDATE CASCADE'
    [pathways.txt/pathway_mode]='integer NOT NULL CHECK (pathway_mode >= 1 AND pathway_mode <= 7)'
    [pathways.txt/is_bidirectional]='boolean NOT NULL'
    [pathways.txt/length]='double precision NULL CHECK (length >= 0.0)'
    [pathways.txt/traversal_time]='integer NULL CHECK (traversal_time >= 0)'
    [pathways.txt/stair_count]='integer NULL'
    [pathways.txt/max_slope]='double precision NULL'
    [pathways.txt/min_width]='double precision NULL CHECK (min_width >= 0.0)'
    [pathways.txt/signposted_as]='text NULL'
    [pathways.txt/reversed_signposted_as]='text NULL'

    [levels.txt/level_id]='text PRIMARY KEY'
    [levels.txt/level_index]='double precision NOT NULL'
    [levels.txt/level_name]='text NULL'

    [feed_info.txt/feed_publisher_name]='text NOT NULL'
    [feed_info.txt/feed_publisher_url]='text NOT NULL'
    [feed_info.txt/feed_lang]='text NOT NULL'
    [feed_info.txt/feed_start_date]='numeric(8) NULL'
    [feed_info.txt/feed_end_date]='numeric(8) NULL'
    [feed_info.txt/feed_version]='text NULL'
    [feed_info.txt/feed_contact_email]='text NULL'
    [feed_info.txt/feed_contact_url]='text NULL'
    [feed_info.txt/feed_lang]='text NULL'

    [translations.txt/table_name]='text NOT NULL'
    [translations.txt/field_name]='text NOT NULL'
    [translations.txt/language]='text NOT NULL'
    [translations.txt/translation]='text NOT NULL'
    [translations.txt/record_id]='text NULL'
    [translations.txt/record_sub_id]='text NUll'
    [translations.txt/field_value]='text NULL'
)

MANDATORY_FILES="
    agency.txt
    stops.txt
    routes.txt
    trips.txt
    stop_times.txt
"
OPTIONAL_FILES="
    calendar.txt
    calendar_dates.txt
    fare_attributes.txt
    fare_rules.txt
    shapes.txt
    frequencies.txt
    transfers.txt
    pathways.txt
    levels.txt
    feed_info.txt
    translations.txt
"

declare -a MANDATORY_COLUMNS
MANDATORY_COLUMNS=(
    agency.txt/agency_name
    agency.txt/agency_url
    agency.txt/agency_timezone
    stops.txt/stop_id
    routes.txt/route_id
    routes.txt/route_type
    trips.txt/route_id
    trips.txt/service_id
    trips.txt/trip_id
    stop_times.txt/trip_id
    stop_times.txt/stop_id
    stop_times.txt/stop_sequence
    calendar.txt/service_id
    calendar.txt/monday
    calendar.txt/tuesday
    calendar.txt/wednesday
    calendar.txt/thursday
    calendar.txt/friday
    calendar.txt/saturday
    calendar.txt/sunday
    calendar.txt/start_date
    calendar.txt/end_date
    calendar_dates.txt/service_id
    calendar_dates.txt/date
    calendar_dates.txt/exception_type
    fare_attributes.txt/fare_id
    fare_attributes.txt/price
    fare_attributes.txt/currency_type
    fare_attributes.txt/payment_method
    fare_attributes.txt/transfers
    fare_rules.txt/fare_id
    shapes.txt/shape_id
    shapes.txt/shape_pt_lat
    shapes.txt/shape_pt_lon
    shapes.txt/shape_pt_sequence
    frequencies.txt/trip_id
    frequencies.txt/start_time
    frequencies.txt/end_time
    frequencies.txt/headway_secs
    transfers.txt/from_stop_id
    transfers.txt/to_stop_id
    transfers.txt/transfer_type
    pathways.txt/pathway_id
    pathways.txt/from_stop_id
    pathways.txt/to_stop_id
    pathways.txt/pathway_mode
    pathways.txt/is_bidirectional
    levels.txt/level_id
    levels.txt/level_index
    feed_info.txt/feed_publisher_name
    feed_info.txt/feed_publisher_url
    feed_info.txt/feed_lang
)

# On errors, the script doesn't exit right away, but tried to continue. Error
# codes are accumulated in $exit_code and used as overall exit code in the end.
exit_code=0
EXIT_NO_FILES=1
EXIT_MANDATORY_FILES_MISSING=2
EXIT_MANDATORY_COLUMN_MISSING=4
EXIT_UNKNOWN_COLUMN=8


# Extract column headers from a CSV file
column_headers() {
    # May fail to strip all quotes if someone puts a column with a comma in the
    # name into the file. The GTFS standard only uses lowercase characters and
    # underscore, though, so well-formed files should work.
    LANG=C LC_ALL=C sed 's/^\xef\xbb\xbf//; s/\r//g; s/"//g; s/,/\n/g; q' "$@"
}

# Check if mandatory files are present.
found_files=0
missing_mandatory_files=""

for filename in $MANDATORY_FILES; do
    inputfile="$gtfsdir/$filename"
    if [ -r "$inputfile" ]; then
        let found_files++
    else
        missing_mandatory_files="$missing_mandatory_files $inputfile"
    fi
done

if [ $found_files -eq 0 ]; then
    usage
    exit $EXIT_NO_FILES
fi

if [ -n "$missing_mandatory_files" ]; then
    >&2 echo "One or more mandatory files missing: $missing_mandatory_files"
    let exit_code+=$EXIT_MANDATORY_FILES_MISSING
fi

declare -A columns_found

for filename in $MANDATORY_FILES $OPTIONAL_FILES; do
    inputfile="$gtfsdir/$filename"
    if [ -r "$inputfile" ]; then
        for header in $(column_headers "$inputfile"); do
            columns_found[$filename/$header]=1
        done
    fi
done

# Verify that all mandatory columns are present. Optional files can have
# mandatory columns. That means if the file is present, then its mandatory
# columns must be present as well.
first=true
for file_and_column in ${MANDATORY_COLUMNS[*]}; do
    file=${file_and_column%%/*}
    column=${file_and_column#*/}
    if [ -r "$gtfsdir/$file" -a -z "${columns_found[$file_and_column]}" ]; then
        if [ -n "$first" ]; then
            first=
            >&2 echo "Missing mandatory column:"
            let exit_code+=$EXIT_MANDATORY_COLUMN_MISSING
        fi
        >&2 echo -e "\tFile: $file,\tcolumn: $column"
    fi
done

# Actual schema generation. For each file generate a table. Then for each
# column in the file generate a column.
first=true
for filename in $MANDATORY_FILES $OPTIONAL_FILES; do
    inputfile="$gtfsdir/$filename"
    tablename=$(basename $filename .txt)
    if [ -r "$inputfile" ]; then
        echo "DROP TABLE IF EXISTS $tablename CASCADE;"
        echo "CREATE TABLE $tablename"
        echo -n "("
        separator=
        for header in $(column_headers "$inputfile"); do
            file_and_column="$filename/$header"
            if [ -z "${COLUMN_DATA_TYPES[$file_and_column]}" ]; then
                # No data type defined for this column
                if [ -n "$first" ]; then
                    first=
                    >&2 echo "Unknown column:"
                    let exit_code+=$EXIT_UNKNOWN_COLUMN
                fi
                >&2 echo -e "\tFile: $filename,\tcolumn $header"
                # Generate a default column of type text to handle local
                # extensions. Also otherwise the \COPY command would fail
                datatype="text NULL"
            else
                datatype="${COLUMN_DATA_TYPES[$file_and_column]}"
            fi
            echo $separator
            separator=,
            printf "  %-22s %s" "$header" "$datatype"
        done
        echo
        echo ");"
        echo
    fi
done

for filename in $MANDATORY_FILES $OPTIONAL_FILES; do
    inputfile="$gtfsdir/$filename"
    tablename=$(basename $filename .txt)
    if [ -r "$inputfile" ]; then
        echo "\\COPY $tablename FROM '$inputfile' (FORMAT CSV, HEADER)"
    fi
done

exit $exit_code

# vim: set tabstop=4 shiftwidth=4 expandtab:

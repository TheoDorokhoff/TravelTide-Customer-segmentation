-- Start of the query where we create a Common Table Expression (CTE) to gather various customer behavior metrics.
WITH sessions_hotels_flights AS (
    SELECT DISTINCT
        s.user_id, -- User ID
        COUNT(s.trip_id) :: FLOAT AS num_of_trips, -- Counting number of trips per user
        SUM(CASE WHEN s.cancellation = TRUE THEN 1 ELSE 0 END) :: FLOAT / COUNT(*) AS cancellation_proportion, -- Calculating cancellation proportion
        MAX(haversine_distance(u.home_airport_lat, u.home_airport_lon, f.destination_airport_lat, f.destination_airport_lon)) :: FLOAT AS max_distance, -- Calculating maximum travel distance by Haversine distance function
        SUM(CASE WHEN s.flight_booked = TRUE THEN 1 ELSE 0 END) :: FLOAT AS total_booked_flights, -- sum up of total booked flights
        SUM(CASE WHEN s.hotel_booked = TRUE THEN 1 ELSE 0 END) :: FLOAT AS total_booked_hotels, -- sum up of total booked hotels
        SUM(CASE WHEN s.flight_discount = TRUE THEN 1 ELSE 0 END) :: FLOAT / COUNT(*) AS discount_flight_proportion, -- Calculating flight discount proportion
        SUM(CASE WHEN s.hotel_discount = TRUE THEN 1 ELSE 0 END) :: FLOAT / COUNT(*) AS discount_hotel_proportion, -- Calculating hotel discount proportion
        AVG(
            (CAST(s.page_clicks AS FLOAT) -
            (SELECT MIN(CAST(s.page_clicks AS FLOAT)) FROM sessions s)) /
            ((SELECT MAX(CAST(s.page_clicks AS FLOAT)) FROM sessions s) - (SELECT MIN(CAST(s.page_clicks AS FLOAT)) FROM sessions s))
        ) AS avg_clicks, -- deriving average clicks on user level+MinMax scaling
        AVG(s.session_start - s.session_end) AS mean_session_time, -- calculating the mean session duration
        SUM(
            (h.hotel_per_room_usd - (SELECT MIN(h.hotel_per_room_usd) FROM hotels h)) /
            ((SELECT MAX(h.hotel_per_room_usd) FROM hotels h) - (SELECT MIN(h.hotel_per_room_usd) FROM hotels h))
        ) AS total_prediscount_spent_hotel, -- Calculating total pre-discount spending on hotels+MinMax scaling
        AVG(s.hotel_discount_amount) AS avg_hotel_discount, -- deriving average hotel discount
        SUM(
            (f.base_fare_usd - (SELECT MIN(f.base_fare_usd) FROM flights f)) /
            ((SELECT MAX(f.base_fare_usd) FROM flights f) - (SELECT MIN(f.base_fare_usd) FROM flights f))
        ) AS total_prediscount_spent_flight, -- Calculating total pre-discount spending on flights+MinMax scaling
        AVG(s.flight_discount_amount) AS avg_flight_discount, -- deriving average flight discount
        AVG(
            (CAST(f.checked_bags AS FLOAT) -
            (SELECT MIN(CAST(f.checked_bags AS FLOAT)) FROM flights f)) /
            ((SELECT MAX(CAST(f.checked_bags AS FLOAT)) FROM flights f) - (SELECT MIN(CAST(f.checked_bags AS FLOAT)) FROM flights f))
        ) AS avg_luggage_pieces, -- deriving average luggage pieces per flight
        SUM(s.flight_discount_amount * f.base_fare_usd) / SUM(haversine_distance(u.home_airport_lat, u.home_airport_lon, f.destination_airport_lat, f.destination_airport_lon)) :: FLOAT AS ADS_per_km, -- calculating Average Dollars Saved per kilometer
        AVG(
            (CAST(h.rooms AS FLOAT) -
            (SELECT MIN(CAST(h.rooms AS FLOAT)) FROM hotels h)) /
            ((SELECT MAX(CAST(h.rooms AS FLOAT)) FROM hotels h) - (SELECT MIN(CAST(h.rooms AS FLOAT)) FROM hotels h))
        ) AS avg_rooms_booked, -- deriving average rooms booked per hotel stay+MinMax scaling
        AVG(
            (CAST(h.nights AS FLOAT) -
            (SELECT MIN(CAST(h.nights AS FLOAT)) FROM hotels h)) /
            ((SELECT MAX(CAST(h.nights AS FLOAT)) FROM hotels h) - (SELECT MIN(CAST(h.nights AS FLOAT)) FROM hotels h))
        ) AS avg_nights -- deriving average nights per hotel stay+MinMax scaling
    FROM
        sessions s
    LEFT JOIN hotels h ON h.trip_id = s.trip_id -- left joins on trip_id
    LEFT JOIN flights f ON f.trip_id = s.trip_id -- left joins on trip_id
    LEFT JOIN users u ON u.user_id = s.user_id -- left joins on user_id
    WHERE
        s.session_start >= '2023-01-04' -- filters for session after '2023-01-04'
    GROUP BY 1
    HAVING COUNT(s.session_id) > 7 -- filters for users with more then 7 sessions
    ORDER BY 1
),

-- The next CTE implement IQR method to remove outliers from various metrics.
shf_cleaned_scaled AS (
    SELECT
        user_id,
        total_booked_flights,
        total_booked_hotels,
        discount_flight_proportion,
        discount_hotel_proportion,
        mean_session_time,
        cancellation_proportion,
        CASE
            WHEN shf.num_of_trips >= q.trips_Q1 - 1.5 * (q.trips_Q3 - q.trips_Q1) AND shf.num_of_trips <= q.trips_Q3 + 1.5 * (q.trips_Q3 - q.trips_Q1)
            THEN shf.num_of_trips
            ELSE NULL
        END AS num_of_trips_per_user,
        CASE
            WHEN shf.max_distance >= q.distance_Q1 - 1.5 * (q.distance_Q3 - q.distance_Q1) AND shf.max_distance <= q.distance_Q3 + 1.5 * (q.distance_Q3 - q.distance_Q1)
            THEN shf.max_distance
            ELSE NULL
        END AS max_distance_per_user,
        CASE
            WHEN shf.ADS_per_km >= q.ads_Q1 - 1.5 * (q.ads_Q3 - q.ads_Q1) AND shf.ADS_per_km <= q.ads_Q3 + 1.5 * (q.ads_Q3 - q.ads_Q1)
            THEN shf.ADS_per_km
            ELSE NULL
        END AS ADS_per_km_user,
        CASE
            WHEN shf.avg_luggage_pieces >= q.luggage_Q1 - 1.5 * (q.luggage_Q3 - q.luggage_Q1) AND shf.avg_luggage_pieces <= q.luggage_Q3 + 1.5 * (q.luggage_Q3 - q.luggage_Q1)
            THEN shf.avg_luggage_pieces
            ELSE NULL
        END AS avg_luggage_per_user,
        CASE
            WHEN shf.avg_clicks >= q.clicks_Q1 - 1.5 * (q.clicks_Q3 - q.clicks_Q1) AND shf.avg_clicks <= q.clicks_Q3 + 1.5 * (q.clicks_Q3 - q.clicks_Q1)
            THEN shf.avg_clicks
            ELSE NULL
        END AS avg_clicks_per_user,
        CASE
            WHEN shf.total_prediscount_spent_hotel >= q.hotel_Q1 - 1.5 * (q.hotel_Q3 - q.hotel_Q1) AND shf.total_prediscount_spent_hotel <= q.hotel_Q3 + 1.5 * (q.hotel_Q3 - q.hotel_Q1)
            THEN shf.total_prediscount_spent_hotel
            ELSE NULL
        END AS total_hotels_spent,
        CASE
            WHEN shf.avg_hotel_discount >= q.hotel_discount_Q1 - 1.5 * (q.hotel_discount_Q3 - q.hotel_discount_Q1) AND shf.avg_hotel_discount <= q.hotel_discount_Q3 + 1.5 * (q.hotel_discount_Q3 - q.hotel_discount_Q1)
            THEN shf.avg_hotel_discount
            ELSE NULL
        END AS avg_discount_hotel,
        CASE
            WHEN shf.total_prediscount_spent_flight >= q.flight_Q1 - 1.5 * (q.flight_Q3 - q.flight_Q1) AND shf.total_prediscount_spent_flight <= q.flight_Q3 + 1.5 * (q.flight_Q3 - q.flight_Q1)
            THEN shf.total_prediscount_spent_flight
            ELSE NULL
        END AS total_flights_spent,
        CASE
            WHEN shf.avg_flight_discount >= q.flight_discount_Q1 - 1.5 * (q.flight_discount_Q3 - q.flight_discount_Q1) AND shf.avg_flight_discount <= q.flight_discount_Q3 + 1.5 * (q.flight_discount_Q3 - q.flight_discount_Q1)
            THEN shf.avg_flight_discount
            ELSE NULL
        END AS avg_discount_flight,
        CASE
            WHEN shf.avg_rooms_booked >= q.rooms_Q1 - 1.5 * (q.rooms_Q3 - q.rooms_Q1) AND shf.avg_rooms_booked <= q.rooms_Q3 + 1.5 * (q.rooms_Q3 - q.rooms_Q1)
            THEN shf.avg_rooms_booked
            ELSE NULL
        END AS avg_rooms_booked_per_user,
        CASE
            WHEN shf.avg_nights >= q.nights_Q1 - 1.5 * (q.nights_Q3 - q.nights_Q1) AND shf.avg_nights <= q.nights_Q3 + 1.5 * (q.nights_Q3 - q.nights_Q1)
            THEN shf.avg_nights
            ELSE NULL
        END AS avg_nights_per_user
    FROM sessions_hotels_flights shf
    CROSS JOIN (
        SELECT
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_prediscount_spent_hotel) AS hotel_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_prediscount_spent_hotel) AS hotel_Q3,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY avg_hotel_discount) AS hotel_discount_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_hotel_discount) AS hotel_discount_Q3,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_prediscount_spent_flight) AS flight_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_prediscount_spent_flight) AS flight_Q3,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY avg_flight_discount) AS flight_discount_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_flight_discount) AS flight_discount_Q3,
  			PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY avg_clicks) AS clicks_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_clicks) AS clicks_Q3,
  			PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY avg_luggage_pieces) AS luggage_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_luggage_pieces) AS luggage_Q3,
  			PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ADS_per_km) AS ads_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ADS_per_km) AS ads_Q3,
  			PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY avg_rooms_booked) AS rooms_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_rooms_booked) AS rooms_Q3,
  			PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY avg_nights) AS nights_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_nights) AS nights_Q3,
  			PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY max_distance) AS distance_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY max_distance) AS distance_Q3,
  			PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY num_of_trips) AS trips_Q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY num_of_trips) AS trips_Q3
        FROM sessions_hotels_flights
    ) AS q
),
-- The next CTE calculates indexes and assign ranks for each segment on customer level
Final_table AS (
    SELECT
        user_id,
        avg_luggage_per_user,
        free_checkedbag_rank,
        long_crowdy_index,
        free_meal_rank,
        scaled_max_distance,
        RANK() OVER (ORDER BY scaled_max_distance DESC) AS free_hotel_night_rank, -- ranking customers by max distance traveled
        (scaled_num_trips + cancellation_proportion) AS free_cancel_index, -- sum up cancellation proportion with number of trips to derive index for free cancellation perk
        RANK() OVER (ORDER BY (scaled_num_trips + cancellation_proportion) DESC) AS free_cancel_rank, --ranking customers by bargain index
        bargain_hunter_index, 
        RANK() OVER (ORDER BY bargain_hunter_index DESC) AS exclusive_discount_rank --ranking customers by bargain index
    FROM (
        SELECT
            user_id,
            avg_luggage_per_user,
            RANK() OVER (ORDER BY avg_luggage_per_user DESC) AS free_checkedbag_rank, --ranking customers by average checked bags amount
            long_crowdy_index,
            RANK() OVER (ORDER BY long_crowdy_index DESC) AS free_meal_rank, --ranking customers by index for a free meal perk (avg(number of booked rooms)+avg(booked nights))
            CASE
                WHEN max_distance_per_user = 0 THEN 0
                ELSE (max_distance_per_user - (SELECT MIN(max_distance_per_user) FROM shf_cleaned_scaled)) /
                    ((SELECT MAX(max_distance_per_user) FROM shf_cleaned_scaled) - (SELECT MIN(max_distance_per_user) FROM shf_cleaned_scaled))
            END AS scaled_max_distance, --MinMax scaling for max distance traveled metric
            CASE
                WHEN num_of_trips_per_user = 0 THEN 0
                ELSE (num_of_trips_per_user - (SELECT MIN(num_of_trips_per_user) FROM shf_cleaned_scaled)) /
                    ((SELECT MAX(num_of_trips_per_user) FROM shf_cleaned_scaled) - (SELECT MIN(num_of_trips_per_user) FROM shf_cleaned_scaled))
            END AS scaled_num_trips, --MinMax scaling for number of trips per user
            cancellation_proportion,
            COALESCE(
                (avg_discount_flight + discount_flight_proportion + COALESCE(ADS_scaled, 0)), 0
            ) AS bargain_hunter_index -- sum up scaled average flight discount with proportion of discounted flights and Average Dollars Saved as a bargain index for a "exclusive discounts" perk
        FROM (
            SELECT
                user_id,
                ROUND(avg_discount_flight, 4) AS avg_discount_flight,
                ROUND(avg_discount_hotel, 4) AS avg_discount_hotel,
                discount_flight_proportion,
                discount_hotel_proportion,
                mean_session_time,
                CASE
                    WHEN ADS_per_km_user = 0 THEN 0
                    ELSE (ADS_per_km_user - (SELECT MIN(ADS_per_km_user) FROM shf_cleaned_scaled)) /
                        ((SELECT MAX(ADS_per_km_user) FROM shf_cleaned_scaled) - (SELECT MIN(ADS_per_km_user) FROM shf_cleaned_scaled))
                END AS ADS_scaled, -- MinMax scaling for ADS
                COALESCE(avg_luggage_per_user, 0) AS avg_luggage_per_user, --replacing NULL values with 0
                COALESCE(avg_rooms_booked_per_user, 0) + COALESCE(avg_nights_per_user, 0) AS long_crowdy_index, -- sum up scaled average number of  rooms booked with average number of nights per user as an index for a "free meal" perk
                COALESCE(max_distance_per_user, 0) AS max_distance_per_user, --replacing NULL values with 0
                num_of_trips_per_user,
                cancellation_proportion
            FROM shf_cleaned_scaled
            ORDER BY 9 DESC
        ) t1
        ORDER BY 8 DESC
    ) t2
    ORDER BY 1
)

-- This part assigns customers to different segments based on minimum ranking.
SELECT
    user_id,
    CASE
        WHEN free_checkedbag_rank <= free_meal_rank AND free_checkedbag_rank <= free_hotel_night_rank AND free_checkedbag_rank <= free_cancel_rank AND free_checkedbag_rank <= exclusive_discount_rank THEN 'free_checkedbag'
        WHEN free_meal_rank <= free_checkedbag_rank AND free_meal_rank <= free_hotel_night_rank AND free_meal_rank <= free_cancel_rank AND free_meal_rank <= exclusive_discount_rank THEN 'free_meal'
        WHEN free_hotel_night_rank <= free_checkedbag_rank AND free_hotel_night_rank <= free_meal_rank AND free_hotel_night_rank <= free_cancel_rank AND free_hotel_night_rank <= exclusive_discount_rank THEN 'free_hotel_night_with_flight'
        WHEN free_cancel_rank <= free_checkedbag_rank AND free_cancel_rank <= free_meal_rank AND free_cancel_rank <= free_hotel_night_rank AND free_cancel_rank <= exclusive_discount_rank THEN 'free_cancellation'
        ELSE 'exclusive_discounts'
    END AS segment_perk_assigned
FROM Final_table
ORDER BY 1;










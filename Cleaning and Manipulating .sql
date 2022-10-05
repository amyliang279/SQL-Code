-- string manipulation

SELECT Initcap(title), description, release_year
FROM film
WHERE to_tsvector(description) @@ to_tsquery('Teacher');  

SELECT split_part(address, ' ', 2) AS street_name, count(*)
FROM address
GROUP BY street_name
ORDER BY count DESC;

SELECT rating, string_agg(title, ', ') AS films
FROM film
GROUP BY rating;
  
SELECT rental_duration, count(title) AS n_films, round(avg(length),0) AS avg_length, round(avg(rental_rate),2) AS avg_rate, string_agg(title, ', ') AS films
FROM film 
GROUP BY rental_duration  
ORDER BY rental_duration

SELECT upper(concat(first_name, ' ', LAST_name)) AS FULL_name
FROM staff;

SELECT initcap(first_name || ' ' || last_name || ' ' || '<' || email || '>')
FROM customer;

SELECT substring(email FROM 0 FOR position('@' IN email))
FROM customer;

SELECT substring(email FROM POSITION('@' IN email)+1 FOR length(email))
FROM customer;


SELECT address, city, postal_code
FROM address a
INNER JOIN city c 
USING (city_id)
WHERE postal_code IS NOT NULL;

SELECT address || ', ' || city || ', ' || postal_code AS full_address
FROM address a
INNER JOIN city c 
ON a.city_id = c.city_id 
WHERE postal_code IS NOT NULL;

SELECT * FROM payment;


-- Arithmetic/Calculations Practice **EDA**
SELECT cust.full_name AS full_name, round(avg(pay.amount),2) AS avg_spending
FROM payment AS pay
INNER JOIN customer AS cust 
USING (customer_id)
GROUP BY cust.full_name 
ORDER BY avg_spending desc;

SELECT trunc(length, -1) AS duration, count(*)
FROM film
GROUP BY duration 
ORDER BY duration;

-- Subqueries:
-- See the amount of revenue produced by each movie:

SELECT rpif.title, sum(rpif.amount) AS income_generated
FROM 
	(SELECT f.title, p.amount 
	FROM rental r 
	LEFT JOIN payment p 
	ON r.rental_id = p.rental_id 
	LEFT JOIN inventory i 
	ON r.inventory_id = i.inventory_id 
	LEFT JOIN film f 
	ON f.film_id = i.film_id) AS rpif 
GROUP BY rpif.title
ORDER BY income_generated DESC;


-- Nested queries: 

SELECT title
FROM film 
GROUP BY title
HAVING avg(rental_rate) >
	(SELECT avg(rental_rate)
	FROM film)

-- Top 15 actor/actress that brings in the most amount of revenue from rentals
	-- CTE setup:
WITH joins AS (
		SELECT DISTINCT f.title, fa.actor_id, p.amount
		FROM rental r
		LEFT JOIN payment p 
		ON r.rental_id = p.rental_id 
		LEFT JOIN inventory i 
		ON r.inventory_id = i.inventory_id 
		LEFT JOIN film f 
		ON f.film_id = i.film_id 
		LEFT JOIN film_actor fa 
		ON f.film_id = fa.film_id
		LEFT JOIN actor a 
		ON fa.actor_id = a.actor_id),
		
	name AS (
		SELECT DISTINCT fa.actor_id, (a.first_name || ' ' || a.last_name) AS Full_name
		FROM actor a
		LEFT JOIN film_actor fa 
		ON a.actor_id = fa.actor_id)
		
	-- Query:
SELECT name.full_name AS actor_name, sum(joins.amount) AS revenue
FROM joins 
LEFT JOIN name 
ON joins.actor_id = name.actor_id
GROUP BY name.full_name
ORDER BY revenue DESC
LIMIT 15;

-- Binning: 

WITH bins AS (
	SELECT generate_series(40, 170, 10) AS lower, 
			generate_series(50, 180, 10) AS upper),
		
	duration AS (
	SELECT length 
	FROM film)
		
SELECT lower, upper, count(bins)
FROM bins 
JOIN film 
ON length >= lower AND length < upper 
GROUP BY lower, upper
ORDER BY lower;


WITH bins AS (

SELECT generate_series('2007-01-01', '2007-04-01', '1 month'::interval) AS lower,
		generate_series('2007-02-01', '2007-05-01', '1 month'::INTERVAL) AS upper)

SELECT lower, upper, count(payment_date)
FROM payment
LEFT JOIN bins 
ON payment_date >= lower AND payment_date < upper
GROUP BY lower, upper
ORDER BY lower;

-- Temp Tables
-- Method #1
CREATE TEMP TABLE temp_table AS 

SELECT first_name, last_name
FROM actor;

SELECT * FROM temp_table;

-- Method #2-+
SELECT first_name, last_name
INTO TEMP TABLE temp_table2
FROM actor;

SELECT * FROM temp_table2

INSERT INTO temp_table2
SELECT actor_id
FROM actor;

DROP TABLE temp_table2;

DROP TABLE IF EXISTS temp_table;
CREATE TEMP TABLE temp_table AS

-- Insert SELECT query... -- 


-- Date/Time practice 

SELECT '2018-09-10'::date + '1 year 5 days 1 hour'::INTERVAL;


SELECT now() + '1 year 2 months 3 days'::INTERVAL;


SELECT DISTINCT date_part('month', payment_date)
FROM payment;

SELECT DISTINCT extract(dow FROM payment_date)
FROM payment;

SELECT date_part('MONTH', payment_date) AS month, sum(amount)
FROM payment
GROUP BY MONTH
ORDER BY month;


SELECT date_trunc('MONTH', payment_date) AS month, sum(amount) AS total_revenue
FROM payment
GROUP BY MONTH
ORDER BY month;

SELECT DISTINCT EXTRACT(day FROM payment_date) AS day
FROM payment
ORDER BY day;

SELECT rental_date, rental_date + INTERVAL '7 day' AS due_date
FROM rental;

SELECT cast(payment_date AS date) AS updated_date
FROM payment;

SELECT CAST(DATE_TRUNC('DAY', payment_date) AS DATE) AS DATE
FROM payment;

SELECT DISTINCT date_trunc('month', payment_date) AS month
FROM payment;

SELECT DISTINCT date_part('MONTH', cast(payment_date AS date))
FROM payment;


/* OLAP (Group by Cube/Rollup/Grouping sets) - analyze data via pivot tables
	- Cube - aggregates both variables
	- Rollup - aggregates only 1st variable
	- Grouping sets - performs a union of all queries in the group by statement into 1 pivot table 
		- each parentheses (with varying column names inside) represent one level of aggregation 
		- () empty parentheses = total aggregation
		- equivalent to GROUP BY CUBE (if included all versions of possibiilities) 
		- allows for the most flexibility in what you want to see in results
*/

-- CUBE: Average rental rate by film category and rating
SELECT c.name, f.rating, avg(f.rental_rate) AS avg_rental_rate
FROM film f 
LEFT JOIN film_category fc 
ON f.film_id = fc.film_id 
LEFT JOIN category c 
ON fc.category_id = c.category_id 
GROUP BY CUBE(c.name, f.rating);

-- ROLLUP: 
SELECT c.name, f.rating, avg(f.rental_rate) AS avg_rental_rate
FROM film f 
LEFT JOIN film_category fc 
ON f.film_id = fc.film_id 
LEFT JOIN category c 
ON fc.category_id = c.category_id 
GROUP BY ROLLUP(c.name, f.rating);

-- Grouping sets: (same as the GROUP BY CUBE function)
SELECT c.name, f.rating, avg(f.rental_rate) AS avg_rental_rate
FROM film f 
LEFT JOIN film_category fc 
ON f.film_id = fc.film_id 
LEFT JOIN category c 
ON fc.category_id = c.category_id 
GROUP BY GROUPING SETS ((c.name, f.rating), (c.name), (f.rating), ());

-- Exploring database/tables 

SELECT * FROM pg_catalog.pg_tables;

SELECT * FROM information_schema.COLUMNS
WHERE table_schema = 'public';

	-- can save a table as a VIEW with the following syntax and can view results later 
CREATE VIEW table_structure AS 
	SELECT table_name, string_agg(column_name, ', ') AS COLUMNS
	FROM information_schema.COLUMNS 
	WHERE TABLE_schema = 'public'
	GROUP BY TABLE_name;

SELECT * FROM table_structure;

/* Table vs View 
	- Table - data is stored (static)
		- data can be modified directly
	- View - query is stored (dynamic)
		- underlying data must be modified in original tables
*/

	-- Table:
DROP TABLE IF EXISTS family_films;
CREATE TABLE family_films AS 
	SELECT c.name, string_agg(f.title, ', ') AS films
	FROM film f
	JOIN film_category fc 
	ON f.film_id = fc.film_id 
	JOIN category c 
	ON fc.category_id = c.category_id 
	WHERE f.rating = 'G'
	GROUP BY c.name;

SELECT * FROM family_films;

	-- View: 
CREATE VIEW family_films AS 
	SELECT c.name, string_agg(f.title, ', ') AS films
	FROM film f
	JOIN film_category fc 
	ON f.film_id = fc.film_id 
	JOIN category c 
	ON fc.category_id = c.category_id 
	WHERE f.rating = 'G'
	GROUP BY c.name;

SELECT * FROM family_films;

-- Measuring business KPI's **EDA**

SELECT count(DISTINCT customer_id)  -- 599 customers in database
FROM customer;

	-- Initial customer rental registration by month 

WITH reg_dates AS (
	SELECT customer_id, min(rental_date)::date AS reg_date
	FROM rental 
	GROUP BY customer_id)

SELECT date_trunc('month', reg_date)::date AS first_rental_month, 
	count(DISTINCT customer_id)
FROM reg_dates 
GROUP BY first_rental_month
ORDER BY first_rental_month;

	-- Monthly active users (MAU) and rolling total by month
WITH mau AS (
	SELECT date_trunc('month', rental_date) :: date AS rental_month,
		count(DISTINCT customer_id) AS mau
	FROM rental 
	GROUP BY date_trunc('month', rental_date)
	ORDER BY rental_month)

SELECT rental_month, 
	mau, 
	lag(mau) OVER (ORDER BY rental_month) AS previous_mau, 
	sum(mau) OVER (ORDER BY rental_month) AS mau_rt
FROM mau 
ORDER BY rental_month;

	-- include growth/change rate of mau's by month: 

WITH mau AS (
		SELECT date_trunc('month', rental_date) :: date AS rental_month,
			count(DISTINCT customer_id) AS mau
		FROM rental 
		GROUP BY date_trunc('month', rental_date)
		ORDER BY rental_month),
	lagged_mau AS (
		SELECT rental_month, 
			mau, 
			lag(mau) OVER (ORDER BY rental_month) AS previous_mau
		FROM mau 
		ORDER BY rental_month)
			
SELECT rental_month, 
	mau, 
	round((mau - previous_mau) :: NUMERIC / previous_mau, 2) AS change
FROM lagged_mau 
ORDER BY rental_month;
 
	-- Retention Rate: 

WITH user_monthly_activity AS (

SELECT date_trunc('month', rental_date)::date AS rental_month, 
	customer_id
FROM rental )

SELECT previous.rental_month, 
	round( count(DISTINCT CURRENT.customer_id) :: NUMERIC / 
		GREATEST(count(DISTINCT previous.customer_id),1), 2) AS retention_rate
FROM user_monthly_activity AS previous
LEFT JOIN user_monthly_activity AS CURRENT 
ON previous.customer_id = CURRENT.customer_id
AND previous.rental_month = (CURRENT.rental_month - INTERVAL '1 month')
GROUP BY previous.rental_month 
ORDER BY previous.rental_month;

	-- ARPU (average revenue per user):

WITH kpi AS (
	SELECT date_trunc('month', payment_date)::date AS payment_month,
		sum(amount) AS revenue,
		count(DISTINCT customer_id) AS users 
	FROM payment 
	GROUP BY payment_month)

SELECT payment_month,
	round(revenue::NUMERIC / GREATEST(users, 1), 2) AS arpu 
FROM kpi 
ORDER BY payment_month;

	-- average rentals per user

WITH kpi AS (
	SELECT count(DISTINCT customer_id) AS users,
		count(DISTINCT rental_id) AS rentals
	FROM rental)
	
SELECT round ( rentals :: NUMERIC / GREATEST(users, 1), 2) AS arpu
FROM kpi;

-- Bucketing:
	-- Movie types:
SELECT CASE 
	WHEN replacement_cost < 10 THEN 'Cheap movie'
	WHEN replacement_cost < 20 THEN 'Medium Cost movie'
	ELSE 'Expensive movie' END AS movie_type,
	count(DISTINCT film_id) AS n_films
FROM film
GROUP BY movie_type

	-- Type of users

WITH user_revenues AS (
	SELECT customer_id, sum(amount) AS revenue
	FROM payment 
	GROUP BY customer_id)

SELECT CASE 
	WHEN revenue < 100 THEN 'low-revenue user'
	WHEN revenue < 150 THEN 'mid-revenue user'
	ELSE 'high-revenue user'
		END AS revenue_group, count(DISTINCT customer_id) AS user_type
FROM user_revenues
GROUP BY revenue_group
ORDER BY revenue_group;

	-- Revenue quartiles: 
WITH user_revenues AS (
		SELECT customer_id, sum(amount) AS revenue
		FROM payment 
		GROUP BY customer_id),
	quartiles AS (
		SELECT round( percentile_cont(0.25) WITHIN GROUP (ORDER BY revenue) :: numeric, 2) AS revenue_p25,
			round( percentile_cont(0.5) WITHIN GROUP (ORDER BY revenue) :: numeric, 2) AS revenue_p50,
			round( percentile_cont(0.75) WITHIN GROUP (ORDER BY revenue) :: numeric, 2) AS revenue_p75,
			round(avg(revenue) :: NUMERIC, 2) AS avg_revenue
		FROM user_revenues)

		-- customers in the interquartile range (1st + 3rd quartiles):
SELECT count(DISTINCT customer_id) AS users 
FROM user_revenues 
CROSS JOIN quartiles 
WHERE revenue :: NUMERIC >= 94.79
AND revenue :: NUMERIC <= 128.71;



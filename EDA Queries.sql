/*
Data exploration for Pagila database

Skills used: Joins, CTE's, Windows Functions, Aggregate Functions, Converting Data Types, Subqueries
*/

-- Total # of film rentals

SELECT count(*) FROM rental;

-- Number of customers in database

SELECT count(DISTINCT customer_id)  
FROM customer;

-- Shortest/longest/average film length by category

SELECT cat.name, min(film.length) AS min_len, max(film.length) AS max_len, round(avg(film.length),2) AS avg_length
FROM film AS film
INNER JOIN film_category AS fc 
USING (film_id)
INNER JOIN category AS cat
USING (category_id)
GROUP BY cat.name
ORDER BY avg_length;

-- Median film length grouped by rating

SELECT title, percentile_disc(0.5) WITHIN GROUP (ORDER BY length) OVER (PARTITION BY rating) AS median
FROM film;

-- # of films in each category

SELECT cat.name, count(film.film_id) AS total_film
FROM film AS film 
INNER JOIN film_category AS fc 
USING (film_id)
INNER JOIN category AS cat 
USING (category_id)
GROUP BY cat.name 
ORDER BY total_film DESC;

-- Number of rentals and gross revenue by category 

SELECT cat.name AS genre, count(rent.rental_id) AS rental_num, sum(pay.amount) AS gross_revenue
FROM rental AS rent
LEFT JOIN inventory AS inv
USING (inventory_id)
LEFT JOIN film AS film 
USING (film_id)
LEFT JOIN film_category AS fc 
USING (film_id)
LEFT JOIN category AS cat 
USING (category_id)
LEFT JOIN payment AS pay 
USING (rental_id)
GROUP BY cat.name
ORDER BY rental_num DESC;

-- Number of rentals by rating

SELECT film.rating, count(rent.rental_id) AS rental_num
FROM film AS film 
INNER JOIN inventory AS inv 
USING (film_id)
INNER JOIN rental AS rent 
USING (inventory_id)
GROUP BY film.rating
ORDER BY rental_num DESC;

-- Top 5 films rented of all time and their gross revenue

SELECT film.title, EXTRACT(YEAR from rent.rental_date) AS rental_year, count(inv.film_id) AS rental_num, sum(pay.amount) AS gross_revenue
FROM film AS film 
INNER JOIN inventory AS inv 
USING (film_id)
INNER JOIN rental AS rent 
USING (inventory_id)
LEFT JOIN payment AS pay 
USING (rental_id)
GROUP BY film.title, EXTRACT(YEAR from rent.rental_date)
ORDER BY rental_num DESC 
LIMIT 5;

-- Top 5 Movies that generated the most revenue 

SELECT film.title, sum(pay.amount) AS gross_revenue
FROM film AS film 
INNER JOIN inventory AS inv 
USING (film_id)
INNER JOIN rental AS rent 
USING (inventory_id)
LEFT JOIN payment AS pay 
USING (rental_id)
GROUP BY film.title
ORDER BY gross_revenue DESC 
LIMIT 5;

-- Actor with the most films

SELECT full_Name, count(fa.film_id) AS Num_films 
FROM film_actor AS fa
LEFT JOIN actor AS act
USING (actor_id)
LEFT JOIN film AS film
USING (film_id)
GROUP BY full_name
ORDER BY num_films DESC
LIMIT 1;

-- Top 10 customers and their average/total spending

SELECT cust.full_name AS full_name, round(avg(pay.amount),2) AS avg_spending, round(sum(pay.amount),2) AS total_spending
FROM payment AS pay
INNER JOIN customer AS cust 
USING (customer_id)
GROUP BY cust.full_name 
ORDER BY total_spending DESC
LIMIT 10;

-- Total payment amount collected in 2007 by month 

SELECT 
	CASE
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 1 THEN 'Jan'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 2 THEN 'Feb'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 3 THEN 'Mar'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 4 THEN 'Apr'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 5 THEN 'May'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 6 THEN 'Jun'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 7 THEN 'Jul'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 8 THEN 'Aug'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 9 THEN 'Sep'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 10 THEN 'Oct'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 11 THEN 'Nov'
		WHEN EXTRACT(MONTH FROM payment.date_paid) = 12 THEN 'Dec'
	END AS PaymentMonth, sum(amount) AS total_amount
FROM payment
GROUP BY paymentmonth
ORDER BY total_amount DESC;

-- Distribution of films by duration length bins

SELECT trunc(length, -1) AS duration_bins, count(*)
FROM film
GROUP BY duration_bins
ORDER BY duration_bins;


-- Total revenue by country - Top 10

SELECT co.country, count(pay.payment_id) AS num_payments, sum(pay.amount) AS total_payment
FROM payment AS pay
LEFT JOIN customer AS cust 
USING (customer_id)
LEFT JOIN address AS Addr 
USING (address_id)
LEFT JOIN city AS ci 
USING (city_id)
LEFT JOIN country AS co 
USING (country_id)
GROUP BY co.country 
ORDER BY num_payments DESC, total_payment DESC 
LIMIT 10;

-- Top 10 most profitable movies by revenue:

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
ORDER BY income_generated DESC
LIMIT 10;

-- Top 15 actor/actress that brings in the most amount of revenue

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
		
SELECT name.full_name AS actor_name, sum(joins.amount) AS revenue
FROM joins 
LEFT JOIN name 
ON joins.actor_id = name.actor_id
GROUP BY name.full_name
ORDER BY revenue DESC
LIMIT 15;

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

-- Growth/change rate of mau's by month

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


-- Average rentals per user

WITH kpi AS (
	SELECT count(DISTINCT customer_id) AS users,
		count(DISTINCT rental_id) AS rentals
	FROM rental)
	
SELECT round ( rentals :: NUMERIC / GREATEST(users, 1), 2) AS arpu
FROM kpi;

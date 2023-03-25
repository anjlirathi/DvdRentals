--Marketing Analysis| Sending Email templates to end users

-- create a joint table 

Drop Table If Exists Joint_Dataset;
Create Temp Table Joint_Dataset AS
Select 
  rental.customer_id,
 -- rental.inventory_id,
 rental.rental_date,
  inventory.film_id,
  film.title,
 -- film_category.category_id,
  category.name As category_name
From dvd_rentals.rental
Left Join dvd_rentals.inventory
ON rental.inventory_id = inventory.inventory_id
Left Join dvd_rentals.film
ON inventory.film_id = film.film_id
Left Join dvd_rentals.film_category
On film.film_id = film_category.film_id
Left Join dvd_rentals.category
On film_category.category_id = category.category_id
;
Select * from Joint_Dataset
limit 15;

-- create calculated feilds

-- Rental counts per customer per category

Drop Table if Exists category_rental_count;
Create Temp Table category_rental_count AS
Select
  customer_id,
  category_name,
  count(*) AS rental_count,
  Max(rental_date) AS latest_rental_date
From Joint_Dataset
Group by 
 customer_id,
 Category_name
order by 
  rental_count desc, latest_rental_date desc
;

Select * from category_rental_count
where customer_id = 1;
--limit 10;

-- Total rental Counts

Drop Table If Exists customer_total_rental_count;
Create Temp Table customer_total_rental_count As
Select 
  customer_id,
  Sum(rental_count) As total_rental_count
From category_rental_count
--where customer_id in (1,2,3)
Group by 
  customer_id;
  
Select * from customer_total_rental_count
order by customer_id
limit 20;

--Average rental count per category

Drop Table IF Exists average_category_rental_count;
Create Temp Table average_category_rental_count AS
Select 
  category_name,
  avg(rental_count) As avg_rental_count
From category_rental_count
Group by 
  category_name;
  
Select * from average_category_rental_count
Order by category_name
;

-- Round the average value to floor

Drop Table IF Exists average_category_rental_count;
Create Temp Table average_category_rental_count AS
Select 
  category_name,
  Floor(avg(rental_count)) As avg_rental_count
From category_rental_count
Group by 
  category_name;
  
Select * from average_category_rental_count
Order by category_name
;

-- or Best way to get floor values use Update command

Update average_category_rental_count
Set 
avg_rental_count = Floor(avg_rental_count)
Returning * ;

--Percentile| Customer_A lies in Top X% in film category_Z

Select 
  customer_id,
  category_name,
  rental_count,
  Percent_Rank() Over(
      Partition By customer_id
      Order By rental_count Desc
  ) As percentile
From category_rental_count
Order By customer_id, 
    rental_count Desc
    limit 20 ;

-- Use ceiling 

Drop Table If Exists customer_category_percentile;
CREATE TEMP TABLE customer_category_percentile AS
Select 
  customer_id,
  category_name,
  --rental_count,
  Ceiling(
  100 * Percent_Rank() Over(
      Partition By customer_id
      Order By rental_count Desc
  ) 
  )As percentile
From category_rental_count;

--

Select * FROM  customer_category_percentile
Where customer_id =1
Order By customer_id, 
        percentile  ;
   -- limit 20 ;



-- Use ceiling | Updated -18/3/2023

Drop Table If Exists customer_category_percentile;
CREATE TEMP TABLE customer_category_percentile AS
Select 
  customer_id,
  category_name,
  --rental_count,
  Ceiling(
  100 * Percent_Rank() Over(
      Partition By category_name
      Order By rental_count Desc
  ) 
  )As percentile
From category_rental_count;

--

Select * FROM  customer_category_percentile
Where customer_id =1
Order By customer_id, 
        percentile
    limit 20 ;
    
    
    

-- Calling all tables

Select * from category_rental_count
Where customer_id = 1
Order by rental_count;

Select * from customer_total_rental_count
limit 5;

Select * from average_category_rental_count
LIMIT 5;

Select * from customer_category_percentile
order by customer_id,percentile
Limit 5;

-- Joining all calculated tables

DROP TABLE IF EXISTS customer_category_joint_dataset;
CREATE TEMP TABLE customer_category_joint_dataset AS
SELECT 
  t1.customer_id,
  t1.category_name,
  t1.rental_count,
  t2.total_rental_count,
  t3.avg_rental_count,
  t4.percentile
FROM category_rental_count AS t1
Inner Join customer_total_rental_count AS t2
ON t1.customer_id = t2.customer_id
Inner Join average_category_rental_count AS t3
On t1.category_name =t3.category_name
Inner Join customer_category_percentile AS t4
On t1.customer_id = t4.customer_id
AND t1.category_name =t4.category_name
;
--inspection
SELECT * FROM customer_category_joint_dataset
Where customer_id =1
Order by percentile
LIMIT 10;

-- Adding Calculated feilds
-- Average Comparison and Category Percentage

DROP TABLE IF EXISTS customer_category_joint_table;
CREATE TEMP TABLE customer_category_joint_table AS
SELECT 
    t1.customer_id,
    t1.category_name,
    t1.rental_count,
    t1.latest_rental_date,
    t2.total_rental_count,
    t3.avg_rental_count,
    t4.percentile,
    t1.rental_count-t3.avg_rental_count AS average_comparison,
    ROUND(100 * t1.rental_count/t2.total_rental_count) AS category_percentage
FROM category_rental_count AS t1
INNER JOIN customer_total_rental_count AS t2
ON t1.customer_id = t2.customer_id
INNER JOIN average_category_rental_count AS t3
ON t1.category_name = t3.category_name
INNER JOIN customer_category_percentile AS t4
ON t1.customer_id = t4.customer_id
AND t1.category_name = t4.category_name
;

SELECT * 
FROM customer_category_joint_table
WHERE customer_id = 1
ORDER BY percentile
LIMIT 15;

--Ordering and Filtering rows With Row_Number

DROP TABLE IF EXISTS top_categories_information;

CREATE TEMP TABLE  top_categories_information AS (
WITH ordered_customer_category_joint_table AS (
  SELECT 
      customer_id,
      category_name,
      rental_count,
      average_comparison,
      percentile,
      category_percentage,
      ROW_NUMBER () over(
          PARTITION BY customer_id
          ORDER BY rental_count desc, latest_rental_date desc
        ) AS category_ranking
  FROM customer_category_joint_table
)
SELECT * 
FROM ordered_customer_category_joint_table
WHERE category_ranking <=2
);

--
SELECT * 
FROM top_categories_information
WHERE customer_id IN (1,2,3)
ORDER BY customer_id,category_ranking
;

/* PEAR
Problem
Exploration
Analysis
Report

Problem - providing customer insights to the marketing team 
Exploration - */

-- how many foreign keys only exist in the left table and not in the right?

SELECT
  COUNT(DISTINCT rental.inventory_id)
FROM dvd_rentals.rental
WHERE NOT EXISTS (
  SELECT inventory_id
  FROM dvd_rentals.inventory
  WHERE rental.inventory_id = inventory.inventory_id
);
-- how many foreign keys only exist in the right table and not in the left?
-- note the table reference changes
SELECT
  COUNT(DISTINCT inventory.inventory_id)
FROM dvd_rentals.inventory
WHERE NOT EXISTS (
  SELECT inventory_id
  FROM dvd_rentals.rental
  WHERE rental.inventory_id = inventory.inventory_id
);
-- Investigate film ID 
SELECT *
FROM dvd_rentals.inventory
WHERE NOT EXISTS (
  SELECT inventory_id
  FROM dvd_rentals.rental
  WHERE rental.inventory_id = inventory.inventory_id
);

--- check the duplicacy or overlappig of foreign key col values

Select 
 -- customer_id,
  COUNT (DISTINCT inventory_id) 
FROM dvd_rentals.rental
WHERE NOT EXISTS (
  SELECT inventory_id
  FROM dvd_rentals.inventory
  WHERE rental.inventory_id = inventory.inventory_id
)
;

SELECT 
  COUNT (DISTINCT inventory.inventory_id)
FROM dvd_rentals.inventory
WHERE NOT EXISTS (
  SELECT 1
  FROM dvd_rentals.rental
  WHERE inventory.inventory_id = rental.inventory_id
);

--Inspect the FILM ID which is not yet rented :

SELECT * 
FROM dvd_rentals.inventory
WHERE NOT EXISTS (
  SELECT 1
  FROM dvd_rentals.rental
  WHERE inventory.inventory_id = rental.inventory_id
);

-- Let's inspect whether the left and inner join have any differences in their row counts:

DROP TABLE IF EXISTS left_join_table;
CREATE TEMP TABLE left_join_table AS 
SELECT 
  rental.customer_id,
  rental.inventory_id,
  inventory.film_id
FROM dvd_rentals.rental
LEFT JOIN dvd_rentals.inventory
ON rental.inventory_id = inventory.inventory_id
;

DROP TABLE IF EXISTS inner_join_table;
CREATE TEMP TABLE inner_join_table AS
SELECT 
  rental.customer_id,
  rental.inventory_id,
  inventory.film_id
FROM dvd_rentals.rental
INNER JOIN dvd_rentals.inventory
ON rental.inventory_id = inventory.inventory_id
;
--OUTPUT 
(
SELECT 
  'left join' AS join_type,
  COUNT(*) AS record_count,
  COUNT(DISTINCT inventory_id) AS unique_key_values
FROM left_join_table
)
UNION
(
SELECT 
  'inner join' AS join_type,
  COUNT(*) AS record_count,
  COUNT(DISTINCT inventory_id) AS unique_key_values
FROM inner_join_table
)
;

/*it indicates that both the join have same results

Relationships : 1-1, 1-Many, Many-Many

Let's inspect the relationship bewtween FilmID and actor columns within Film actor table:
Hypothesis:
H1 : 1 Actor could work in Many Films
H2: 1 Film could have Many Actors
Let's analyze the hunch of the point: */

-- H1:
WITH actor_film_count AS (
SELECT 
  actor_id,
  count(DISTINCT film_id) AS film_count
FROM dvd_rentals.film_actor
GROUP BY actor_id
)
SELECT 
  film_count,
  COUNT(*) AS total_actors
FROM actor_film_count
GROUP BY film_count
ORDER BY film_count DESC;

--H2:

WITH film_actor_count AS(
SELECT 
  film_id,
  COUNT(DISTINCT actor_id) AS actor_count
FROM dvd_rentals.film_actor
GROUP BY film_id
)
SELECT 
  actor_count,
  COUNT(*) AS total_films
FROM film_actor_count
GROUP BY actor_count
ORDER BY actor_count DESC;

-- Hence Our hypothesis about relationship within data was correct

/* Analysis :
Solution Plan:
1: creating complete joint dataset
*/

DROP TABLE IF EXISTS complete_joint_dataset;
CREATE TEMP TABLE complete_joint_dataset AS 
SELECT 
  rental.customer_id,
  rental.rental_date,
  inventory.film_id,
  film.title,
  category.name AS category_name
FROM dvd_rentals.rental
INNER JOIN dvd_rentals.inventory
ON rental.inventory_id = inventory.inventory_id
INNER JOIN dvd_rentals.film
ON inventory.film_id = film.film_id
INNER JOIN dvd_rentals.film_category
ON film.film_id = film_category.film_id
INNER JOIN dvd_rentals.category 
ON film_category.category_id = category.category_id
;
SELECT * 
FROM complete_joint_dataset
LIMIT 10;

-- 2: Category Counts

DROP TABLE IF EXISTS category_counts;
CREATE TEMP TABLE category_counts AS
SELECT 
  customer_id,
  category_name,
  COUNT (*) AS rental_count,
  MAX(rental_date) AS latest_rental_date
FROM complete_joint_dataset
GROUP BY customer_id, category_name
;

SELECT * 
FROM category_counts
WHERE customer_id =1
ORDER BY 
  rental_count DESC,
  latest_rental_date DESC
LIMIT 10;

-- 3: Total Counts

DROP TABLE IF EXISTS total_counts;
CREATE TEMP TABLE total_counts AS
SELECT 
  customer_id,
  SUM(rental_count) AS total_count
FROM category_counts
GROUP BY customer_id;

SELECT *
FROM total_counts
--ORDER BY customer_id, total_count
LIMIT 10;

--4: 
--4: Top categories

DROP TABLE IF EXISTS top_categories;
CREATE TEMP TABLE top_categories AS
WITH ranked_cte AS (
  SELECT 
    customer_id,
    category_name,
    rental_count,
    DENSE_RANK() OVER (
      PARTITION BY customer_id
      ORDER BY 
        rental_count DESC,
        latest_rental_date DESC,
        category_name
    ) AS category_rank
  FROM category_counts
)
SELECT * 
FROM ranked_cte
WHERE category_rank <= 2;

--Output

SELECT * FROM top_categories
LIMIT 10;

--5: Average Category Count

DROP TABLE IF EXISTS average_category_count;
CREATE TEMP TABLE average_category_count AS
SELECT 
  category_name,
  FLOOR(AVG(rental_count)) AS category_avg
FROM category_counts
GROUP BY category_name
--ORDER BY category_name
;

-- Output

SELECT *
FROM average_category_count
ORDER BY 
  category_avg DESC,
  Category_name;
--LIMIT 10; 

--6: Top Category Percentile

DROP TABLE IF EXISTS top_category_percentile;
CREATE TEMP TABLE top_category_percentile AS 
WITH calculated_cte AS (
    SELECT 
      top_categories. customer_id,
      top_categories.category_name AS top_category_name,
      top_categories.rental_count,
      top_categories.category_rank,
      category_counts.category_name,
      PERCENT_RANK() OVER(
        PARTITION BY category_counts.category_name
        ORDER BY category_counts.rental_count DESC
      ) AS raw_percentile
    FROM category_counts
    LEFT JOIN top_categories
    ON category_counts.customer_id = top_categories.customer_id
)
SELECT 
  customer_id,
  category_name,
  rental_count,
  category_rank,
  CASE 
  WHEN  ROUND(100*raw_percentile) =0 THEN 1
  ELSE  ROUND(100*raw_percentile)
  END AS percentile
FROM calculated_cte
WHERE category_rank =1 
AND top_category_name = category_name
;

--Output

SELECT * 
FROM top_category_percentile
ORDER BY customer_id;

--7: First Category Insights

DROP TABLE IF EXISTS first_category_insights;
CREATE TEMP TABLE first_category_insights AS
SELECT 
  base.customer_id,
  base.category_name,
  base.rental_count,
  base.rental_count - average.category_avg AS average_comparison,
  base.percentile
FROM top_category_percentile AS base
LEFT JOIN average_category_count AS average
ON base.category_name = average.category_name;

--Output

SELECT * 
FROM first_category_insights
--ORDER BY customer_id
LIMIT 20;


--8: Second Category Insights

DROP TABLE IF EXISTS second_category_insights;
CREATE TEMP TABLE second_category_insights AS
SELECT 
  top_categories.customer_id,
  top_categories.category_name,
  top_categories.rental_count,
  ROUND(100 * top_categories.rental_count::NUMERIC/total_counts.total_count) AS percentage
FROM top_categories
LEFT JOIN total_counts
ON top_categories.customer_id = total_counts.customer_id
WHERE category_rank =2;

--Output

SELECT * 
FROM second_category_insights
LIMIT 10;


-- Category Recommendations

--Film counts

DROP TABLE IF EXISTS film_counts;
CREATE TEMP TABLE film_counts AS
SELECT DISTINCT
  film_id,
  title,
  category_name,
  COUNT(*) OVER(
    PARTITION BY film_id
  ) AS rental_count
FROM complete_joint_dataset;

--Output
SELECT * 
FROM film_counts
ORDER BY rental_count DESC
LIMIT 15;


-- Category film exclusion

DROP TABLE IF EXISTS category_film_exclusion;
CREATE TEMP TABLE category_film_exclusion AS
SELECT DISTINCT
  customer_id,
  film_id
FROM complete_joint_dataset;
--Output
SELECT * 
FROM category_film_exclusion
LIMIT 10;

--Category Recommendations

DROP TABLE IF EXISTS category_recommendations;
CREATE TEMP TABLE category_recommendations AS
WITH ranked_films_cte AS(
SELECT 
  top_categories.customer_id,
  top_categories.category_name,
  top_categories.category_rank,
  film_counts.film_id,
  film_counts.title,
  film_counts.rental_count,
  DENSE_RANK() OVER(
    PARTITION BY 
      top_categories.customer_id, 
      top_categories.category_rank
    ORDER BY 
      film_counts.rental_count DESC,
      film_counts.title 
  ) AS reco_rank
FROM top_categories
INNER JOIN film_counts
ON top_categories.category_name = film_counts.category_name
WHERE NOT EXISTS (
  SELECT 1
  FROM category_film_exclusion
  WHERE 
    category_film_exclusion.customer_id = top_categories.customer_id
    AND
    category_film_exclusion.film_id = film_counts.film_id
 )
)
SELECT * 
FROM ranked_films_cte
WHERE reco_rank <= 3;

--Output
SELECT * FROM category_recommendations
WHERE customer_id =1
ORDER BY 
  category_rank, reco_rank;

  --ACTOR Insights

  --Actor Joint Datset

DROP TABLE IF EXISTS actor_joint_dataset;
CREATE TEMP TABLE actor_joint_dataset AS
SELECT 
  rental.customer_id,
  rental.rental_id,
  rental.rental_date,
  film.film_id,
  film.title,
  actor.actor_id,
  actor.first_name,
  actor.last_name
FROM dvd_rentals.rental
INNER JOIN dvd_rentals.inventory
ON rental.inventory_id = inventory.inventory_id
INNER JOIN dvd_rentals.film
ON inventory.film_id = film.film_id
INNER JOIN dvd_rentals.film_actor
ON film.film_id = film_actor.film_id
INNER JOIN dvd_rentals.actor
ON film_actor.actor_id= actor.actor_id;

  --Output
  SELECT * 
  FROM actor_joint_dataset
  LIMIT 10;


----Top Actor counts

DROP TABLE IF EXISTS top_actor_counts;
CREATE TEMP TABLE top_actor_counts AS
WITH actor_counts AS (
  SELECT
    customer_id,
    actor_id,
    first_name,
    last_name,
    COUNT(*) AS rental_count,
    -- we also generate the latest_rental_date just like our category insight
    MAX(rental_date) AS latest_rental_date
  FROM actor_joint_dataset
  GROUP BY
    customer_id,
    actor_id,
    first_name,
    last_name
),
ranked_actor_counts AS (
  SELECT
    actor_counts.*,
    DENSE_RANK() OVER (
      PARTITION BY customer_id
      ORDER BY
        rental_count DESC,
        latest_rental_date DESC,
        -- just in case we have any further ties, we'll throw in the names too!
        first_name,
        last_name
    ) AS actor_rank
  FROM actor_counts
)
SELECT
  customer_id,
  actor_id,
  first_name,
  last_name,
  rental_count
FROM ranked_actor_counts
WHERE actor_rank = 1;

--Output
SELECT * FROM top_actor_counts;

--Actor Film Recommendations

-- Actor Film Counts

DROP TABLE IF EXISTS actor_film_counts;
CREATE TEMP TABLE actor_film_counts AS
WITH film_counts AS(
  SELECT 
      film_id,
      COUNT(DISTINCT rental_id) AS rental_count
  FROM actor_joint_dataset
  GROUP BY film_id
)
SELECT 
  actor_joint_dataset.film_id,
  actor_joint_dataset.actor_id,
  actor_joint_dataset.title,
 -- actor_joint_dataset.first_name,
 -- actor_joint_dataset.last_name,
  film_counts.rental_count
FROM actor_joint_dataset
LEFT JOIN film_counts
ON actor_joint_dataset.film_id = film_counts.film_id;

--Output

SELECT * FROM actor_film_counts
LIMIT 10;

/*--checking with previous window function method 

SELECT DISTINCT
  film_id,
  actor_id,
  Count(*) OVER (
  PARTITION BY film_id
  ) AS rental_count
FROM actor_joint_dataset
WHERE film_id =80;

--results from both the methods are varying since actor_id and film_id have mamy to mamy relationship*/

-- Actor Film Exclusion

DROP TABLE IF EXISTS actor_film_exclusion;
CREATE TEMP TABLE actor_film_exclusion AS
(
SELECT 
  customer_id,
  film_id
FROM complete_joint_dataset
)
UNION
(
SELECT
  customer_id,
  film_id
FROM category_recommendations
);
--Output
SELECT * 
FROM actor_film_exclusion
LIMIT 15;

/*--tweak the table with actor joint dataset

DROP TABLE IF EXISTS actor_film_exclusion_a;
CREATE TEMP TABLE actor_film_exclusion_a AS
(
SELECT 
  customer_id,
  film_id
FROM actor_joint_dataset
)
UNION
(
SELECT
  customer_id,
  film_id
FROM category_recommendations
);

SELECT * 
FROM actor_film_exclusion_a
LIMIT 15;

Results from both the query are same ???*/

-- Actor Recommendations

DROP TABLE IF EXISTS actor_recommendation;
CREATE TEMP TABLE actor_recommendation AS
WITH ranked_actor_film AS (
SELECT
  top_actor_counts.customer_id,
  top_actor_counts.first_name,
  top_actor_counts.last_name,
  top_actor_counts.rental_count,
  actor_film_counts.title,
  actor_film_counts.film_id,
  actor_film_counts.actor_id,
  DENSE_RANK() OVER (
    PARTITION BY 
      top_actor_counts.customer_id
    ORDER BY
      actor_film_counts.rental_count DESC,
      actor_film_counts.title
  ) AS reco_rank
FROM top_actor_counts
INNER JOIN actor_film_counts
ON top_actor_counts.actor_id = actor_film_counts.actor_id
WHERE NOT EXISTS (
  SELECT 1
  FROM actor_film_exclusion
  WHERE
   actor_film_exclusion.customer_id = top_actor_counts.customer_id AND
   actor_film_exclusion.film_id = actor_film_counts.film_id
) 
)
SELECT * FROM ranked_actor_film
WHERE reco_rank <= 3;

--Output
SELECT * FROM actor_recommendation
--WHERE reco_rank = 2
ORDER BY customer_id, reco_rank
LIMIT 15;



--Final Script

DROP TABLE IF EXISTS final_data_asset;
CREATE TEMP TABLE final_data_asset AS
WITH first_category AS (
  SELECT
    customer_id,
    category_name,
    CONCAT(
      'You''ve watched ', rental_count, ' ', category_name,
      ' films, that''s ', average_comparison,
      ' more than the DVD Rental Co average and puts you in the top ',
      percentile, '% of ', category_name, ' gurus!'
    ) AS insight
  FROM first_category_insights
),
second_category AS (
  SELECT
    customer_id,
    category_name,
    CONCAT(
      'You''ve watched ', rental_count, ' ', category_name,
      ' films making up ', percentage,
      '% of your entire viewing history!'
    ) AS insight
  FROM second_category_insights
),
top_actor AS (
  SELECT
    customer_id,
    -- use INITCAP to transform names into Title case
    CONCAT(INITCAP(first_name), ' ', INITCAP(last_name)) AS actor_name,
    CONCAT(
      'You''ve watched ', rental_count, ' films featuring ',
      INITCAP(first_name), ' ', INITCAP(last_name),
      '! Here are some other films ', INITCAP(first_name),
      ' stars in that might interest you!'
    ) AS insight
  FROM top_actor_counts
),
adjusted_title_case_category_recommendations AS (
  SELECT
    customer_id,
    INITCAP(title) AS title,
    category_rank,
    reco_rank
  FROM category_recommendations
),
wide_category_recommendations AS (
  SELECT
    customer_id,
    MAX(CASE WHEN category_rank = 1  AND reco_rank = 1
      THEN title END) AS cat_1_reco_1,
    MAX(CASE WHEN category_rank = 1  AND reco_rank = 2
      THEN title END) AS cat_1_reco_2,
    MAX(CASE WHEN category_rank = 1  AND reco_rank = 3
      THEN title END) AS cat_1_reco_3,
    MAX(CASE WHEN category_rank = 2  AND reco_rank = 1
      THEN title END) AS cat_2_reco_1,
    MAX(CASE WHEN category_rank = 2  AND reco_rank = 2
      THEN title END) AS cat_2_reco_2,
    MAX(CASE WHEN category_rank = 2  AND reco_rank = 3
      THEN title END) AS cat_2_reco_3
  FROM adjusted_title_case_category_recommendations
  GROUP BY customer_id
),
adjusted_title_case_actor_recommendations AS (
  SELECT
    customer_id,
    INITCAP(title) AS title,
    reco_rank
  FROM actor_recommendation
),
wide_actor_recommendations AS (
  SELECT
    customer_id,
    MAX(CASE WHEN reco_rank = 1 THEN title END) AS actor_reco_1,
    MAX(CASE WHEN reco_rank = 2 THEN title END) AS actor_reco_2,
    MAX(CASE WHEN reco_rank = 3 THEN title END) AS actor_reco_3
  FROM adjusted_title_case_actor_recommendations
  GROUP BY customer_id
),
final_output AS (
  SELECT
    t1.customer_id,
    t1.category_name AS cat_1,
    t4.cat_1_reco_1,
    t4.cat_1_reco_2,
    t4.cat_1_reco_3,
    t2.category_name AS cat_2,
    t4.cat_2_reco_1,
    t4.cat_2_reco_2,
    t4.cat_2_reco_3,
    t3.actor_name AS actor,
    t5.actor_reco_1,
    t5.actor_reco_2,
    t5.actor_reco_3,
    t1.insight AS insight_cat_1,
    t2.insight AS insight_cat_2,
    t3.insight AS insight_actor
FROM first_category AS t1
INNER JOIN second_category AS t2
  ON t1.customer_id = t2.customer_id
INNER JOIN top_actor t3
  ON t1.customer_id = t3.customer_id
INNER JOIN wide_category_recommendations AS t4
  ON t1.customer_id = t4.customer_id
INNER JOIN wide_actor_recommendations AS t5
  ON t1.customer_id = t5.customer_id
)
SELECT * FROM final_output;


-- Output

SELECT * 
FROM final_data_asset
LIMIT 10;


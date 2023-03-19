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


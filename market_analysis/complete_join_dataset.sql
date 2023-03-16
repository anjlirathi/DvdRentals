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

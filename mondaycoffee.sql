-- MondayCoffee Analysis

-- Q1 What is the estimated number of coffee consumers in each city, assuming that 25% of the total population consumes coffee?
-- to calculate 25% population multiply population by 0.25 -> population * 0.25

select city_name, round((population*0.25)/1000000,2) as coffee_consumers_by_city , city_rank from city order by coffee_consumers_by_city desc;


-- Q2 How much revenue did coffee sales generate across all cities in Q4 2023?

select sum(total) as total_revenue from sales
where
extract(year FROM sale_date)=2023 and extract( quarter FROM sale_date) = 4;


-- Revenue from coffee sales in top 05 cities during Q4 2023

select ci.city_name, sum(total) as total_revenue from sales as s
join customers as c on c.customer_id = s.customer_id
join city as ci on
ci.city_id = c.city_id
where
extract(year from sale_date) = 2023 and extract(quarter from sale_date)=4
group by ci.city_name order by total_revenue desc limit 5;


-- Q3 What is the total number of units sold for each coffee product?
-- Here we perform Left join fucntion since I want all data from porducts table having product_id left join on sales table porduct_id column to know
-- how much units have been sold for each coffee product

select p.product_name as coffee_product, count(s.sale_id) as total_units_sold from sales as s
left join products as p on
p.product_id=s.product_id
group by coffee_product order by total_units_sold desc;  -- limit 10 can also be applied to view top 10 products with max quantity of products sold


-- Q4 What is the average sales amount per customer in each city?
-- Average implies Total/No of distinct input

select ci.city_name, sum(s.total) as total_revenue,count(c.customer_id) as no_of_orders_placed_customer ,count(distinct c.customer_id) as total_customers,
round((sum(s.total)/count(distinct c.customer_id)),2) as avg_sales_per_customer from sales as s
join customers as c on c.customer_id = s.customer_id
join city as ci on
ci.city_id = c.city_id
group by ci.city_name order by total_revenue desc;


-- Q5 Provide a list of cities along with their populations and estimated coffee consumers.
-- I want to return city name, total customers (distinct customer - population), estimated coffee consumers 
-- from Q1 we know 25% consume coffee already

WITH city_table as 
(
	SELECT 
		city_name,
		ROUND((population * 0.25)/1000000, 2) as coffee_consumers
	FROM city
),
customers_table
AS
(
	SELECT 
		ci.city_name,
		COUNT(DISTINCT c.customer_id) as unique_cx
	FROM sales as s
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1
)
SELECT 
	customers_table.city_name,
	city_table.coffee_consumers as coffee_consumer_in_millions,
	customers_table.unique_cx
FROM city_table
JOIN 
customers_table
ON city_table.city_name = customers_table.city_name;

-- Q6 Identify the top 3 products by sales volume for every city.
-- We shall use DENSE RANK() function here since it ensures that the ranking is continuos even in case of a tie and ranks do not skip.
-- While in case of RANK() if there is a tie then the ranking skips 

select * from
( select ci.city_name, p.product_name, count(s.sale_id) as total_units_sold,
dense_rank() over(partition by ci.city_name order by count(s.sale_id) desc) as city_ranking
from sales as s
join products as p on
s.product_id = p.product_id 
join customers as c on 
c.customer_id = s.customer_id
join city as ci on
ci.city_id = c.city_id
group by ci.city_name, p.product_name
order by ci.city_name, count(s.sale_id) desc ) as sales_by_vol
where city_ranking <= 3;

-- Q7 How many unique customers are there in each city who have purchased coffee products and not merchandise?

select ci.city_name, COUNT(DISTINCT c.customer_id) as unique_customer
from city as ci
left join
customers as c
on c.city_id = ci.city_id
join sales as s
on s.customer_id = c.customer_id
where 
	s.product_id in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14)
group by ci.city_name;

-- Q8 Find each city and their average sale per customer and avg rent per customer

with city_table
as
(
	select 
		ci.city_name,
		sum(s.total) as total_revenue,
		count(distinct s.customer_id) as total_cx,
		round(sum(s.total)/count(distinct s.customer_id),2) as avg_sale_pr_cx
		
	from sales as s
	join customers as c
	on s.customer_id = c.customer_id
	join city as ci
	on ci.city_id = c.city_id
	group by ci.city_name
	order by SUM(s.total) desc
),
city_rent
as
(select 
	city_name, 
	estimated_rent
from city
)
select 
	cr.city_name,
	cr.estimated_rent,
	ct.total_cx,
	ct.avg_sale_pr_cx,
	round(cr.estimated_rent/ct.total_cx, 2) as avg_rent_per_cx
from city_rent as cr
join city_table as ct
on cr.city_name = ct.city_name
order by 4 desc;

-- Here if we do order by 4: we are comparing with average sales per customer which implies that Pune, Chennai, Bangalore and Jaipur
-- are top 04 cities where average sales per customer is maximum so to open an outlet here would be profitable
-- If we do order by 5 : implies that we are looking for cities where average rent per customer is less, this implies that a place 
-- where average rent is less opening an outlet will be profitable because the rent of the outlet will be less - places like
-- Nagpur, Indoor, Pune, Jaipur, Kanpur have average rent lesser
-- We next compare wrt total customer by city : any place where customers are more, average sale per customer is more and average rent is less
-- the place will outperform
-- In case of Jaipur total customer is more, avg_sale_per_cx is above 10000 and rent is low - so the outlet will outperform than those
-- with higher rent , low customer and lower sales


-- Q9 Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly) by each city

with monthly_sales 
as 
	(select ci.city_name,
	extract(month from sale_date) as month,
	extract(year from sale_date) as year,
	sum(s.total) as total_sales
	from sales as s join customers as c on
	s.customer_id = c.customer_id
	join city as ci on
	ci.city_id=c.city_id
	group by 1,2,3
	order by 1,3,2 
),
growth_ratio 
as
	( select city_name, month, year, total_sales as current_month_sale, 
	lag(total_sales,1) over(partition by city_name order by year, month) as last_month_sale
	from monthly_sales
)
select city_name, month, year, current_month_sale, last_month_sale,
round((current_month_sale-last_month_sale)/last_month_sale*100,2) as mom_growth_rate
from growth_ratio
where
last_month_sale is not null;


-- Q10 Identify the top three cities with the highest sales and return their city name, total sales, total rent, 
-- total customers, and estimated coffee consumers

with city_table
as
(
	select 
		ci.city_name,
		sum(s.total) as total_revenue,
		count(distinct s.customer_id) as total_cx,
		round(sum(s.total)/count(distinct s.customer_id),2) as avg_sale_per_customer
		
	from sales as s
	join customers as c
	on s.customer_id = c.customer_id
	join city as ci
	on ci.city_id = c.city_id
	group by ci.city_name
	order by SUM(s.total) desc
),
city_rent
as
(select 
	city_name, 
	estimated_rent,
    round((population * 0.25)/1000000, 3) as estimated_coffee_consumer_in_millions
from city
)
select 
	cr.city_name,
    ct.total_revenue as total_sales,
	cr.estimated_rent as total_rent,
	ct.total_cx as total_customers,
    cr.estimated_coffee_consumer_in_millions,
	ct.avg_sale_per_customer,
	round(cr.estimated_rent/ct.total_cx, 2) as avg_rent_per_customer
from city_rent as cr
join city_table as ct
on cr.city_name = ct.city_name
order by 2 desc;












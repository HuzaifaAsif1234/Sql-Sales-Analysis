

-- Change over time Analysis

select 
year(order_date) as Order_year, 
month(order_date) as Order_month,
SUM(sales_amount) as Total_sales,
count(distinct customer_key) as total_customers,
sum(quantity) as quantity
from gold.fact_sales
where order_date is not null
GROUP BY year(order_date), month(order_date)
order by year(order_date), month(order_date);


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


-- Cumulative Data Analysis


with t as (
select 
-- year(order_date) as Order_year, 
-- month(order_date) as Order_month,
DATEFROMPARTS(YEAR(order_date), 1, 1) as orders_date,
SUM(sales_amount) as Total_sales
from gold.fact_sales
where order_date is not null
group by year(order_date)
)
select
orders_date,
Total_sales,
SUM(Total_sales) over(partition by orders_date order by orders_date) as running_total
from t


-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------


-- performance analysis
with yearly_product_sales as (
select
year(s.order_date) as order_year,
p.product_name,
sum(s.sales_amount) as total_sales
from gold.fact_sales s
join gold.dim_products p 
on s.product_key = p.product_key
where order_date is not null
group by year(s.order_date), p.product_name
)
select order_year, 
product_name, 
total_sales,
avg(total_sales) over(partition by product_name) as avg_sales,
total_sales - avg(total_sales) over(partition by product_name) as diff_avg,
case when total_sales - avg(total_sales) over(partition by product_name) >0 then 'Increase'
     when total_sales - avg(total_sales) over(partition by product_name) < 0 then 'Decrease'
	 else 'No Progress'
end avg_change,
lag(total_sales) over(partition by product_name order by order_year) as py_sales,
total_sales - lag(total_sales) over(partition by product_name order by order_year) as diff_py,
case when total_sales - lag(total_sales) over(partition by product_name order by order_year)>0 then 'Good'
  when total_sales - lag(total_sales) over(partition by product_name order by order_year) <0 then 'Bad'
  else 'No Progress'
end py_change

from yearly_product_sales
order by product_name, order_year;

with all_ct_sales as (
select f.category, sum(s.sales_amount) as total_sales
from gold.fact_sales s
join gold.dim_products f on s.product_key = f.product_key
group by (f.category)
)
select category, total_sales, sum(total_sales) over() overall_sales,
concat(round((cast(total_sales as float)/ sum(total_sales) over())*100,2),'%') as perc_total
from all_ct_sales
order by perc_total desc


-- Data Segmentation


with sales_det as(
select c.customer_key as customer_num,
sum(f.sales_amount) as total_spending,
min(f.order_date) as first_order,
max(f.order_date) as last_order,
datediff(month, min(f.order_date), max(f.order_date)) as lifespan
from gold.fact_sales f
join gold.dim_customers c 
on f.customer_key = c.customer_key
group by c.customer_key)

select customer_status, count(customer_num ) as Total_customers
from 
    (
	select customer_num, total_spending, lifespan,
	case 
		when total_spending > 5000 and lifespan >=12 then 'VIP'
		when total_spending <= 5000 and lifespan >=12 then 'Regular'
		else 'New'
	end customer_status
	from sales_det
     ) t
group by customer_status
order by Total_customers desc

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Customer Report
create view base_report as 
with base_query as (
	select 
	s.order_number,
	s.product_key,
	s.order_date,
	s.sales_amount,
	s.quantity,
	f.customer_key,
	f.customer_number,
	Concat(f.first_name, ' ', f.last_name) as full_name,
	datediff(year, f.birthdate, getdate()) as age
	from gold.fact_sales s
	join gold.dim_customers f
	on f.customer_key = s.customer_key
	where order_date is not null
     ),
	 customer_aggregation as (
select 
customer_key,
customer_number,
full_name,
age,
count(distinct order_number) as no_of_orders,
count(distinct product_key) as product_keys,
max(order_date) as last_order_date,
datediff(month, min(order_date), max(order_date)) as lifespan,
sum(quantity) as Total_quantities,
sum(sales_amount) as total_sales
from base_query
group by 
	customer_key,
    customer_number,
	full_name,
	age

	)
select
customer_key,
customer_number,
full_name,
age,
datediff(month, last_order_date, getdate()) as recency,
case 
	when age<20 then 'Under 20'
	when age between 20 and 30 then '20-29'
	when age between 30 and 40 then '30-39'
	when age between 40 and 50 then '40-49'
	else 'over 50'
	end as age_range,
case 
	when total_sales=0 then 0
	else total_sales/ no_of_orders
end as avg_order_value,

no_of_orders,
product_keys,

case 
	when total_sales > 5000 and lifespan >=12 then 'VIP'
	when total_sales <= 5000 and lifespan >=12 then 'Regular'
	else 'New'
end as customer_status,

case 
	when lifespan =0 then total_sales
	else total_sales/lifespan 
end as avg_monthly_spend,

lifespan,
total_sales
from customer_aggregation
































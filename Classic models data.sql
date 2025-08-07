/*Sales overview by product */
select t1.orderdate, t1.orderNumber, quantityOrdered,priceeach,productName ,productline, buyprice, city,country
from orders t1
inner join orderdetails t2
on t1.ordernumber=t2.ordernumber
inner join products t3
on t2.productCode= t3.productCode
inner join customers t4
on t1.customerNumber =t4.customerNumber
where year(orderdate) = 2004 
;

/*Products purchased together */
with prod_sales as
(
select orderNumber, t1.productcode, productline
from orderdetails t1
inner join products t2
on t1.productcode=t2.productCode
)
select distinct t1.ordernumber, t1.productline as product_one , t2.productline as product_two
from prod_sales t1
left join prod_sales t2
on t1.ordernumber=t2.ordernumber and t1.productline <> t2.productline
;
/* Customers SAles Value by Credit Limit*/
with sales as
(
select t1.ordernumber, t1.customerNumber, productcode, quantityOrdered, priceeach*quantityOrdered as sales_value,
creditlimit
from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.ordernumber
inner join customers t3
on t1.customerNumber = t3.customerNumber
)
select ordernumber, customernumber,
case when creditlimit < 75000 then 'a:Less than $75k'
when creditlimit between 75000 and 100000 then 'b:$75k - $100k'
when creditlimit between 100000 and 150000 then 'c:$100k - $150k'
when creditlimit > 150000 then 'd:over $150k'
else 'other'
end as creditlimit_group,
 sum(sales_value) as sales_value
from sales
group by ordernumber, customernumber,creditlimit_group
;

/* Sales Value change from previous order */

with main_cte as
(
select ordernumber,orderdate,customernumber, sum(sales_value) as sales_value
from 
(select t1.orderNumber, orderdate,customerNumber, productCode, quantityOrdered * priceEach as sales_value
from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.orderNumber ) main
group by ordernumber,orderdate,customernumber
) ,
sales_query as 
(
select t1.*, customerName, row_number() over (partition by customerName order by orderdate) as purchase_number,
lag(sales_value) over (partition by customerName order by orderdate) as prev_sales_value
from main_cte t1
inner join customers t2
on t1.customernumber = t2.customernumber
)
select *, sales_value - prev_sales_value as purchase_value_change
from sales_query
where prev_sales_value is not null
;

/* Office Sales by Customer Country */

with main_cte as
(
select t1.orderNumber, t2.quantityOrdered, t2.productCode, t2.priceEach,
quantityOrdered * priceEach as sales_value,
t3.city as customer_city, 
t3.country as customer_country ,
t4.productLine,t6.city as office_city,
t6.country as office_country

from orders t1
inner join orderdetails t2
on t1.orderNumber = t2.orderNumber
inner join customers t3
on t1.customerNumber= t3.customerNumber
inner join products t4
on t2.productCode=t4.productCode
inner join employees t5
on t3.salesRepEmployeeNumber=t5.EmployeeNumber
inner join offices t6
on t5.officeCode = t6.officeCode
)

select 
ordernumber,
customer_city,
customer_country,
productline,
office_city,
office_country,
sum(sales_value) as sales_value
from main_cte
group by
ordernumber,
customer_city,
customer_country,
productline,
office_city,
office_country
;

/* Customers Affected by late shipping */

select *,
date_add(shippeddate, interval 3 day) as latest_arival,
case when date_add(shippeddate, interval 3 day) > requiredDate then 1 else 0 end as late_flag
from orders
where
(case when date_add(shippeddate, interval 3 day) > requiredDate then 1 else 0 end) = 1
;

/* Customers who go over credit limit*/
with cte_sales as
(
select orderdate,
t1.customerNumber, t1.orderNumber,
customerName,productcode,creditLimit,
quantityOrdered*priceEach as sales_value
from orders t1
inner join orderdetails t2
on t1.ordernumber = t2.orderNumber
inner join customers t3
on t1.customerNumber = t3.customerNumber
) ,
running_total_sales_cte as
(
select *, lead(orderdate) over (partition by customernumber order by orderdate) as next_order_date
from
(
select orderdate,ordernumber,
customernumber,customername,creditlimit,
sum(sales_value) as sales_value
from cte_sales
group by
orderdate,ordernumber,
customernumber,customername,creditlimit
)subquery
)
,

payments_cte as
(select *
from payments),

main_cte as
(
select *,
sum(sales_value) over(partition by t1.customernumber order by orderdate) as running_total_sales,
sum(amount) over(partition by t1.customerNumber order by orderDate) as running_total_payments
from running_total_sales_cte t1
left join payments_cte t2
on t1.customernumber=t2.customernumber and t2.paymentdate between t1.orderdate and case when t1.next_order_date is null then current_date else next_order_date end
)

select *, running_total_sales - running_total_payments as money_owned, 
creditlimit -(running_total_sales - running_total_payments) as diffrenceproductlines
from main_cte
;


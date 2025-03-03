-- Part II: SQL Queries
-- Closed-ended questions
-- Note - all queries assume tables have been cleaned according to the attached python notebook code and are filtered down.
-- I ended up answering all 6 questions for completeness. 
-- All SQL syntax is Snowflake SQL.


-- 1. What are the top 5 brands by receipts scanned among users 21 and over?
-- Assumption: 21 years and over means as of right now the user is 21 or older. 
-- 			   Not that they were >=21 at the time of the purchase or scan
with base_set as (
	select * from transactions a
	left join products b on a.barcode=b.barcode
	left join users c on a.user_id=c.id
	where datediff(year, c.birth_date, current_date()) >= 21)
select distinct brand, count(distinct receipt_id) as n_receipts
from base_set
group by brand
order by count(distinct receipt_id) desc limit 5

-- The top 5 brands are: Dove, Nerds Candy, Coca-Cola, Great Value, and Hershey's.


-- 2. What are the top 5 brands by sales among users that have had their account for at least six months?
with base_set as (
	select * from transactions a
	left join products b on a.barcode=b.barcode
	left join users c on a.user_id=c.id
	where datediff(month, c.created_date, current_date() >= 6))
select distinct brand, sum(final_sale) as total_sale
from base_set
group by brand
order by sum(final_sale) desc limit 5

-- The top 5 brands are: CVS, Trident, Dove, Coors Light, Quaker.


-- 3. What is the percentage of sales in the Heath & Wellness category by generation?
with base_set as (
	select a.*, b.*, c.*, datediff(year, c.birth_date, current_date()) as age from transactions a
	left join products b on a.barcode=b.barcode
	left join users c on a.user_id=c.id
	where b.category_1 = 'Health & Wellness'),
base_set2 as (
	select a.*, (case when a.age < 25 then 'Gen Z'
				              when a.age >= 25 and a.age < 40 then 'Millenial'
				              when a.age >= 40 and a.age < 55 then 'Gen X'
				              when a.age >= 55 then 'Boomer'
          end) as generation from base_set a) 
select distinct generation, sum(final_sale) as total_sale, sum(final_sale) / (select sum(final_sale) from base_set2) as pct_sale
from base_set2
group by generation

-- 52% of the sales were from Boomers, 29% from Gen X, and 19% from Millenials. 


-- Open-ended questions
-- 1. Who are Fetch's power users?
-- Assumptions: power users are defined by the top portion of users by total sales and receipts. 
-- I've decided this because total receipts shows how often they scan with the app.
-- Total sales may be a proxy for how many points they have earned through the app. 
-- You could also look for outliers for all of the other columns (total # categories, brands, age of account, etc)
-- but I think these two are most important.

with base_set as (
	select * from transactions a
	left join products b on a.barcode=b.barcode
	left join users c on a.user_id=c.id)
select distinct user_id, sum(final_sale) as total_sales, count(distinct receipt_id) as total_receipts 
from base_set
group by user_id
order by sum(final_sale) desc


-- The top 5 users by total sales are:
-- 630789e1101ae272a4852287 with $925.64
-- 63af23db9f3fc9c7546fdbec with $476.34
-- 650874eafe41d365c2ee11d2 with $267.29
-- 645add3bffe0d7e043ef1b63 with $227.93
-- 637257e75fdbb03aa198a310 with $194.14

-- The top 5 users by total receipts are:
-- 64e62de5ca929250373e6cf5 with 10
-- 62925c1be942f00613f7365e with 10
-- 64063c8880552327897186a5 with 9
-- 604278958fe03212b47e657b with 7
-- 609af341659cf474018831fb with 7

-- 2. Which is the leading brand in the Dips & Salsa category?
-- Assumption: a leading brand is one that dominates it's market, so that translates to the one with the highest sales and quantity sold. 

with base_set as (
	select * from transactions a
	left join products b on a.barcode=b.barcode
	left join users c on a.user_id=c.id
	where b.category_2 = 'Dips & Salsa')
select distinct brand, sum(final_sale) as total_sale, sum(final_quantity) as total_quantity, count(distinct receipt_id) as total_receipts from base_set
order by sum(total_sales)

-- Tostitos is the leading brand in this category with >$250 in sales, 60 units sold, and 36 receipts


-- 3. At what percent has Fetch grown year over year?
-- Assumption: Growth is measured by number and percent change in users, receipts scanned, products included, and final sales in dollars. 

with base_set as (
	select a.*, b.*, c.*, datediff(year, c.created_date, current_date()) as account_age from transactions a
	left join products b on a.barcode=b.barcode
	left join users c on a.user_id=c.id),
base_set2 as (
	select distinct account_age, count(distinct user_id) as n_users, count(distinct receipt_id) as n_receipts, count(distinct barcode) as n_products, sum(final_sale) as total_sale
	from base_set
	where account_age is not null
	group by account_age
	order by account_age),
base_set3 as (
select a.*, 
		lag(a.n_users) over (order by a.account_age) as prev_yr_users, 
		((a.n_users - lag(n_users) over (order by a.account_age)) / nullif(lag(a.n_users) over (order by a.account_age), 0)) * 100 as perc_change_users,

		lag(a.n_receipts) over (order by a.account_age) as prev_yr_receipts, 
		((a.n_receipts - lag(a.n_receipts) over (order by a.account_age)) / nullif(lag(a.n_receipts) over (order by a.account_age), 0)) * 100 as perc_change_receipts,

		lag(a.n_products) over (order by a.account_age) as prev_yr_prods, 
		((a.n_products - lag(a.n_products) over (order by a.account_age)) / nullif(lag(a.n_products) over (order by a.account_age), 0)) * 100 as perc_change_prods,

		lag(a.total_sale) over (order by a.account_age) as prev_yr_sale, 
		((a.total_sale - lag(a.total_sale) over (order by a.account_age)) / nullif(lag(a.total_sale) over (order by a.account_age), 0)) * 100 as perc_change_sales
from base_set2 a)
select avg(perc_change_users), avg(perc_change_receipts), avg(perc_change_prods), avg(perc_change_sales) 
from base_set3
where account_age is not null and prev_yr_users is not null

-- Fetch has on average grown YoY 76% in terms of users, 67% in terms of receipts scanned, 67% in terms of unique products scanned, and 80% in total sale amount.

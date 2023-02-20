-- question 1: How to create an overview of tables, with the name, number of attributes and number of rows of each table
-- first step: create a row of a name, number of attributes and number of rows of an individual table
SELECT  name AS table_name,
                   (
				      SELECT COUNT(*)
					    FROM PRAGMA_TABLE_INFO('customers')
					)     AS number_of_attributes,
					(
					  SELECT COUNT(*)
					    FROM customers
					 )    AS number_of_rows
   FROM sqlite_schema
  WHERE type = 'table' AND name ='customers'

-- second step: By using UNION ALL, combine the first row with another row with information of another table, including the duplicates.

UNION ALL
 
 SELECT  name AS table_name,
                   (
				      SELECT COUNT(*)
					    FROM PRAGMA_TABLE_INFO('products')
					)     AS number_of_attributes,
					(
					   SELECT COUNT(*)
					     FROM products
					 )     AS number_of_rows
  FROM sqlite_schema
 WHERE type = 'table' AND name ='products'

UNION ALL
 
 SELECT  name AS table_name,
                   (
				      SELECT COUNT(*)
					    FROM PRAGMA_TABLE_INFO('productlines')
					)     AS number_of_attributes,
					(
					   SELECT COUNT(*)
					        FROM productlines
					 )        AS number_of_rows
    FROM sqlite_schema
   WHERE type = 'table' AND name ='productlines'

UNION ALL
 
 SELECT name AS table_name,
                   (
				      SELECT COUNT(*)
					    FROM PRAGMA_TABLE_INFO('orders')
					)     AS number_of_attributes,
					(
					   SELECT COUNT(*)
					    FROM orders
					 )    AS number_of_rows
   FROM sqlite_schema
  WHERE type = 'table' AND name ='orders'

UNION ALL

 SELECT name AS table_name,
                   (
				      SELECT COUNT(*)
					    FROM PRAGMA_TABLE_INFO('orderdetails')
					)     AS number_of_attributes,
					(
					   SELECT COUNT(*)
					     FROM orderdetails
					 )     AS number_of_rows
   FROM sqlite_schema
  WHERE type = 'table' AND name ='orderdetails'

UNION ALL

 SELECT name AS table_name,
                   (
				      SELECT COUNT(*)
					    FROM PRAGMA_TABLE_INFO('payments')
					)     AS number_of_attributes,
					(
					   SELECT COUNT(*)
					     FROM payments
					 )     AS number_of_rows
   FROM sqlite_schema
  WHERE type = 'table' AND name ='payments'

UNION ALL 
 
 SELECT name AS table_name,
                   (
				      SELECT COUNT(*)
					    FROM PRAGMA_TABLE_INFO('employees')
					)     AS number_of_attributes,
					(
					   SELECT COUNT(*)
					     FROM employees
					 )     AS number_of_rows
   FROM sqlite_schema
  WHERE type = 'table' AND name ='employees'

UNION ALL

  SELECT name AS table_name,
                   (
				      SELECT COUNT(*)
					    FROM PRAGMA_TABLE_INFO('offices')
					)     AS number_of_attributes,
					(
					   SELECT COUNT(*)
					     FROM offices
					 )     AS number_of_rows
   FROM sqlite_schema
  WHERE type = 'table' AND name ='offices'

--2. Which products should we order more of or less of? 

-- To answer this question, we need to look at low stock (i.e. product in demand) and product performance, so that we can optimize the supply and the user experience by preventing the best-selling products from going out of stock. 


-- first step: Find the low stock products, which equals to the quantity of the sum of each product ordered divided by the quantity of product in stock.
-- We can consider the ten highest rates. These will be the top ten products that are almost or totally out-of-stock.

SELECT productCode, ROUND(SUM(quantityOrdered * 1.0)/(SELECT quantityInStock
                                                        FROM products
													   WHERE products.productCode = orderdetails.productCode),2) AS low_stock
FROM orderdetails
GROUP BY productCode
ORDER BY low_stock DESC
LIMIT 10; 

-- second step: Find the product performance, which equals to the sum of sales of each product. I run the following query to calculate the product performance of top 10 products.

  SELECT productCode,  ROUND(SUM(quantityOrdered * priceEach * 1.0), 2) AS product_performance
    FROM orderdetails 
GROUP BY productCode
ORDER BY product_performance DESC
LIMIT 10; 

-- third step: Find the products which we should order more, by looking at products with high performance which are almost out of stock. To achieve this, we combine the previous queries using a Common Table Expression (CTE) to display priority products for restocking using the IN operator.

WITH low_stock AS (
                   SELECT productCode, 
				     ROUND((SUM(quantityOrdered*1.0)) / (SELECT quantityInStock
                                                           FROM products
					                                      WHERE products.productCode = orderdetails.productCode), 2) AS low_stock_rate
                      FROM orderdetails
                  GROUP BY productCode
                  ORDER BY low_stock_rate DESC
                     LIMIT 10
				   )

  SELECT p.productName, p.productLine, o.productCode,  ROUND(SUM(o.quantityOrdered * o.priceEach * 1.0), 2) AS product_performance
    FROM orderdetails o
    JOIN products p
      ON o.productCode = p.productCode
   WHERE o.productCode IN (SELECT productCode
                             FROM low_stock)
GROUP BY o.productCode
ORDER BY product_performance DESC
   LIMIT 10; 

-- 3. How should we match marketing and Communication Strategies to Customer Behavior? 

-- This involves categorizing customers: finding the VIP (very important person) customers and those who are less engaged.

--VIP customers bring in the most profit for the store. Less-engaged customers bring in less profit.

-- For example, we could organize some events to drive loyalty for the VIPs and launch a campaign for the less engaged.

-- Step 1: calculate how much profit each customer generates

  SELECT o.customerNumber, SUM(od.quantityOrdered * 1.0 * (od.priceEach - p.buyPrice)) AS profit
    FROM orders o
    JOIN orderdetails od
      ON o.orderNumber = od.orderNumber
    JOIN products p
      ON od.productCode = p.productCode
GROUP BY o.customerNumber; 

-- second step: Find the top 5 VIP customers by using the previous query as a CTE

WITH profit_table AS (
                        SELECT o.customerNumber, SUM(od.quantityOrdered * 1.0 * (od.priceEach - p.buyPrice)) AS profit
                          FROM orders o
                          JOIN orderdetails od
                            ON o.orderNumber = od.orderNumber
                          JOIN products p
                            ON od.productCode = p.productCode
                      GROUP BY o.customerNumber
					  )
								 
       SELECT contactLastName, contactFirstName, city, country, (SELECT profit
                                                                   FROM profit_table
																  WHERE customers.customerNumber = profit_table.customerNumber) AS profit_amt
	     FROM customers
     ORDER BY profit_amt DESC
        LIMIT 5; 

-- third step: Find the top 5 least-engaged customers 
WITH profit_table AS (
                        SELECT o.customerNumber, SUM(od.quantityOrdered * 1.0 * (od.priceEach - p.buyPrice)) AS profit
                          FROM orders o
                          JOIN orderdetails od
                            ON o.orderNumber = od.orderNumber
                          JOIN products p
                            ON od.productCode = p.productCode
                      GROUP BY o.customerNumber
					  )
								 
       SELECT contactLastName, contactFirstName, city, country, (SELECT profit
                                                                   FROM profit_table
																  WHERE customers.customerNumber = profit_table.customerNumber) AS profit_amt
	     FROM customers
	    WHERE profit_amt IS NOT NULL	 
     ORDER BY profit_amt 
        LIMIT 5; 

-- Question 4: How much can we spend on acquiring new customers?

-- To answer this question, we need to know the average amount of money a customer generates during their lifetime with our store, which is Customer Lifetime Value (LTV). 
-- We can then use this to predict our future profit and decide how much we can spend on marketing.

WITH profit_table AS (
                        SELECT o.customerNumber, SUM(od.quantityOrdered * 1.0 * (od.priceEach - p.buyPrice)) AS profit
                          FROM orders o
                          JOIN orderdetails od
                            ON o.orderNumber = od.orderNumber
                          JOIN products p
                            ON od.productCode = p.productCode
                      GROUP BY o.customerNumber
					                       )
								 
         SELECT  SUM(profit) / COUNT(customerNumber) AS LTV
		    FROM profit_table; 
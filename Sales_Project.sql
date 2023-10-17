--- INSPECTING DATA
----------------------------------------------------------------
SELECT * 
FROM [dbo].[sales_data_sample]

--- CHECKING UNIQUE VALUES
----------------------------------------------------------------
SELECT DISTINCT status FROM sales_data_sample--- Nice one to plot
SELECT DISTINCT year_id FROM sales_data_sample
SELECT DISTINCT PRODUCTLINE FROM sales_data_sample --- Nice to plot
SELECT DISTINCT COUNTRY FROM sales_data_sample --- Nice to plot
SELECT DISTINCT DEALSIZE FROM sales_data_sample --- Nice to plot
SELECT DISTINCT TERRITORY FROM sales_data_sample --- Nice to plot

--- ANALYSIS
-----------------------------------------------------------------
--- Let's start by grouping sales by productline
--- Which product sales the most?
-----------------------------------------------------------------

SELECT productline, SUM(SALES) AS Revenue
FROM sales_data_sample
GROUP by PRODUCTLINE
ORDER by 2 DESC

--- Which year sales the most?
-----------------------------------------------------------------
SELECT year_id, SUM(sales) Revenue
FROM sales_data_sample
GROUP BY year_id 
ORDER BY Revenue DESC 

--- Lowest Sales for 2005. Let's check the month of sales in 2005?
------------------------------------------------------------------
SELECT DISTINCT month_id 
FROM sales_data_sample
WHERE year_id = 2005
ORDER BY month_id --- they operated only in first 5 months of the year. Full year operation for 2003 and 2004.

--- Which dealsize sales the most?
------------------------------------------------------------------
SELECT dealsize, SUM(sales) Revenue
FROM sales_data_sample
GROUP by dealsize 
ORDER by 2 

--- What was the best months for sales in a specitfic year? How much was earned that months?
------------------------------------------------------------------
SELECT month_id, SUM(sales) Revenue, COUNT(ordernumber) Frequency
FROM sales_data_sample
WHERE YEAR_ID = 2004 -- change year to see the rest
GROUP by MONTH_ID
ORDER BY 2 DESC 

--- November 2004 seems to be the best month. 
--- What product was the best seller?
------------------------------------------------------------------
SELECT year_id, month_id, productline, SUM(Sales) Revenue, COUNT(ordernumber) Frequency
FROM sales_data_sample
WHERE year_id = 2004 AND month_id = 11 
GROUP BY year_id, month_id, PRODUCTLINE
ORDER BY 4 DESC -- best seller from product line is classic cars

--- Who is our best customers? (this could be the best answer with RFM)
------------------------------------------------------------------
--- Data Points used in RFM Analysis: 
--- Recency - last order date, Frequency - count of total orders, Monetary value - total spend

DROP TABLE IF EXISTS #rfm
;WITH rfm AS
(
	SELECT 
	CUSTOMERNAME, 
	SUM(SALES) MonetaryValue,
	AVG(SALES) AvgMonetaryValue,
	COUNT(ORDERNUMBER) Frequency,
	MAX(CAST(ORDERDATE AS DATE)) LastOrderDate,
	(SELECT MAX(CAST(ORDERDATE AS DATE)) FROM sales_data_sample) MaxOrderDate, 
	DATEDIFF(DD, MAX(CAST(ORDERDATE AS DATE)), (SELECT MAX(CAST(ORDERDATE AS DATE)) FROM sales_data_sample)) Recency
FROM sales_data_sample
GROUP BY CUSTOMERNAME
),
rfm_calc AS 
(
	SELECT R.*,
		NTILE(4) OVER(ORDER BY Recency DESC) RFM_Recency,
		NTILE(4) OVER(ORDER BY Frequency) RFM_Frequency,
		NTILE(4) OVER(ORDER BY MonetaryValue) RFM_Monetary
	FROM rfm R
)
SELECT 
	C.*, RFM_Recency + RFM_Frequency + RFM_Monetary AS rfm_cell, 
	CAST(C.RFM_Recency AS VARCHAR) + CAST(C.RFM_Frequency AS VARCHAR) + CAST(C.RFM_Monetary AS VARCHAR) rmf_cell_string
	INTO #rfm
FROM rfm_calc C

--- Let's see our temp table #rfm
------------------------------------------------------------------

SELECT *
FROM #rfm
ORDER BY MonetaryValue DESC

--- Let's create segments
------------------------------------------------------------------

SELECT
    CUSTOMERNAME,
    CAST(MonetaryValue AS DECIMAL(10, 2)) AS MonetaryValue,
    RFM_Recency,
    RFM_Frequency,
    RFM_Monetary,
    CASE
        WHEN rfm_cell >= 9 THEN 'High Value Customer'
        WHEN rfm_cell >= 6 THEN 'Good customer'
        WHEN rfm_cell >= 4 THEN 'Slipping away Customer'
        WHEN rfm_cell < 4 THEN 'New Customer'
    END AS rfm_segment
FROM #rfm
ORDER BY MonetaryValue

--- What products are most often sold together?
--- Which 2 or 3 products are often sold together?
------------------------------------------------------------------
-- SELECT * FROM sales_data_sample WHERE ORDERNUMBER = 10411; -- ordernumber is not unique, orderlinenumber is unique


SELECT Ordernumber, STUFF(
	(
	SELECT ',' + PRODUCTCODE -- all productcode which are listed are in 19 orders. productcode is not unique that why we have 38. 
	FROM sales_data_sample p
	WHERE ORDERNUMBER IN 
		(

		SELECT ordernumber -- we have 19 orders when only 2 items were ordered and 13 for 3
		FROM (
			SELECT ordernumber, COUNT(*) rn --- we select all the orders which were shipped
			FROM sales_data_sample
			WHERE STATUS = 'shipped'
			GROUP BY ORDERNUMBER
		) m
		WHERE rn = 2 
		)
		for xml PATH ('') -- ',' + and for xml path ('') we creathe XML path
		)
		, 1, 1, '') -- we removed first comma to convert from xml to string
FROM sales_data_sample s

-- We do the JOINT to select Ordernumber with only 2 Orderlistnumber

SELECT DISTINCT Ordernumber, STUFF(
	(
	SELECT ',' + PRODUCTCODE  
	FROM sales_data_sample p
	WHERE ORDERNUMBER IN 
		(

		SELECT ordernumber 
		FROM (
			SELECT ordernumber, COUNT(*) rn 
			FROM sales_data_sample
			WHERE STATUS = 'shipped'
			GROUP BY ORDERNUMBER
		) m
		WHERE rn = 2
		)
		AND p.ORDERNUMBER = s.ORDERNUMBER -- Joint
		for xml PATH ('') 
		)
		, 1, 1, '') ProductCodes
FROM sales_data_sample s
ORDER BY 2 DESC 
-- the same orders 11 and 12, 15 and 16, those can be combine together whiles you run marketing campaign
-- when rn = 3, 12 and 13
select *from walmartsales;
-- Step 1: Temporarily change the column to VARCHAR
ALTER TABLE walmartsales 
CHANGE COLUMN `date` sale_date VARCHAR(20);

-- Step 2: Update the data to a valid DATE format
UPDATE walmartsales 
SET sale_date = STR_TO_DATE(sale_date, '%d-%m-%Y');

-- Step 3: Convert the column back to DATE
ALTER TABLE walmartsales 
MODIFY COLUMN sale_date DATE;



-- que 1)
with monthlysales as(
SELECT branch,
    EXTRACT(MONTH FROM sale_date) AS SaleMonth ,
    round(sum(total),2)AS total_sales
FROM walmartsales
GROUP BY branch ,EXTRACT(MONTH FROM sale_date) 
ORDER BY SaleMonth),
SalesGrowth AS (
    SELECT Branch, SaleMonth, total_sales,  
        LAG(total_sales, 1, 0) OVER (PARTITION BY Branch ORDER BY SaleMonth) AS PreviousMonthSales,
        CASE
            WHEN LAG(total_sales, 1, 0) OVER (PARTITION BY Branch ORDER BY SaleMonth) IS NULL OR LAG(total_sales, 1, 0) OVER (PARTITION BY Branch ORDER BY SaleMonth) = 0 THEN 0
            ELSE (total_sales - LAG(total_sales, 1, 0) OVER (PARTITION BY Branch ORDER BY SaleMonth)) / LAG(total_sales, 1, 0) OVER (PARTITION BY Branch ORDER BY SaleMonth) * 100
        END AS GrowthRate
    FROM
        MonthlySales),
FinalResult AS (
    SELECT Branch,
        AVG(GrowthRate) AS AverageGrowthRate
    FROM SalesGrowth
    GROUP BY Branch)
SELECT
    Branch, ROUND(AverageGrowthRate, 2) AS RoundedAverageGrowthRate
FROM FinalResult
ORDER BY RoundedAverageGrowthRate DESC;


   
    
-- que 2 

WITH ProfitData AS (
    SELECT branch ,
        `Product line`, 
        round(SUM(`gross income`),2) AS total_profit
    FROM walmartsales
    GROUP BY  `Product line`,branch),
RankedProfit AS (
    SELECT *,
           RANK() OVER (PARTITION BY Branch ORDER BY total_profit DESC) AS ranks
    FROM ProfitData) 
SELECT branch , `Product line`, total_profit, 
    CASE 
        WHEN total_profit >= 1000 THEN 'High'
        WHEN total_profit >= 500 THEN 'Medium'
        ELSE 'Low'
    END AS profit_margin_group
FROM RankedProfit
WHERE ranks = 1;
 
 -- que 3 
 
 WITH CustomerSpending AS (
    SELECT
        `Customer ID`,
        round(sum(Total)) AS TotalSpending
    FROM
        walmartsales
    GROUP BY
        `Customer ID`
),
SpendingPercentiles AS (
    SELECT
        TotalSpending,
        PERCENT_RANK() OVER (ORDER BY TotalSpending) AS SpendingRank
    FROM CustomerSpending )
SELECT
    cs.`Customer ID`,
    cs.TotalSpending,
    CASE
        WHEN sp.SpendingRank >= 0.75 THEN 'High Spender'
        WHEN sp.SpendingRank >= 0.25 AND sp.SpendingRank < 0.75 THEN 'Medium Spender'
        ELSE 'Low Spender'
    END AS SpendingSegment
FROM CustomerSpending cs
JOIN
    SpendingPercentiles sp ON cs.TotalSpending = sp.TotalSpending
ORDER BY
    cs.TotalSpending DESC;
    
    -- que 4) 
    WITH ProductLineStats AS (
    SELECT
        `Product line`,
        AVG(Total) AS AvgSales,
        STDDEV_SAMP(Total) AS StdDevSales
    FROM
        walmartsales
    GROUP BY
        `Product line`
)
SELECT
    ws.`Invoice ID`,
    ws.`Product line`,
    ws.Total,
    pls.AvgSales,
    pls.StdDevSales,
    CASE
        WHEN ws.Total > (pls.AvgSales + (3 * pls.StdDevSales)) THEN 'High Anomaly'
        WHEN ws.Total < (pls.AvgSales - (3 * pls.StdDevSales)) THEN 'Low Anomaly'
        ELSE 'Normal'
    END AS AnomalyStatus
FROM
    walmartsales ws
JOIN
    ProductLineStats pls ON ws.`Product line` = pls.`Product line`
WHERE
    CASE
        WHEN ws.Total > (pls.AvgSales + (3 * pls.StdDevSales)) THEN 'Anomaly'
        WHEN ws.Total < (pls.AvgSales - (3 * pls.StdDevSales)) THEN 'Anomaly'
        ELSE 'Normal'
    END <> 'Normal';
    
-- que 5)
WITH PaymentCounts AS (
    SELECT
        City,
        Payment,
        COUNT(*) AS PaymentCount,
        ROW_NUMBER() OVER (PARTITION BY City ORDER BY COUNT(*) DESC) AS rn
    FROM
        walmartsales
    GROUP BY
        City,
        Payment
)
SELECT
    City,
    Payment AS MostPopularPaymentMethod
FROM
    PaymentCounts
WHERE
    rn = 1;
    
    -- 6)
    select extract(month from sale_date) as salemonthly , gender, ROUND(SUM(Total), 2) AS totalSales
    from walmartsales 
    group by extract(month from sale_date)   ,gender
    ORDER BY
    SaleMonthly,
    Gender; 
    
-- 7)
WITH ProductLineFrequencyByType AS (
    SELECT
        `Customer type`,
        `Product line`,
        COUNT(*) AS PurchaseFrequency,
        ROW_NUMBER() OVER (PARTITION BY `Customer type` ORDER BY COUNT(*) DESC) AS rn
    FROM
        walmartsales
    GROUP BY
        `Customer type`,
        `Product line`
)
SELECT
    `Customer type`,
    `Product line` AS MostFrequentProductLine,
    PurchaseFrequency
FROM
    ProductLineFrequencyByType
WHERE
    rn = 1;  
    
    -- 8)
    WITH CustomerPurchases AS (
    SELECT
        `Customer ID`,
        sale_date,
        ROW_NUMBER() OVER (PARTITION BY `Customer ID` ORDER BY sale_date) as PurchaseNumber,
        LAG(sale_date, 1, NULL) OVER (PARTITION BY `Customer ID` ORDER BY sale_date) as PreviousPurchaseDate
    FROM
        walmartsales
),
RepeatPurchaseDates AS (
    SELECT
        `Customer ID`,
        sale_date,
        DATEDIFF(sale_date, PreviousPurchaseDate) AS DaysSinceLastPurchase
    FROM
        CustomerPurchases
    WHERE PurchaseNumber > 1
)
SELECT DISTINCT `Customer ID`
FROM RepeatPurchaseDates
WHERE DaysSinceLastPurchase <= 30;
    
    -- 9)
    SELECT
    `Customer ID`,
    round(SUM(Total),2)AS TotalRevenue
FROM
    walmartsales
GROUP BY
    `Customer ID`
ORDER BY
    TotalRevenue DESC
LIMIT 5; 

-- 10)
SELECT
    WEEKDAY(Date) AS DayIndex,
    SUM(Total) AS TotalSales
FROM
    walmartsales
GROUP BY
    DayIndex
ORDER BY
    TotalSales DESC
LIMIT 1;
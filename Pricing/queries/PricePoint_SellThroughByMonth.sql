DECLARE @StartDate DATE = '1/1/2014'
DECLARE @EndDate DATE = '2/1/2020'


SELECT 
	DATEADD(MONTH, DATEDIFF(MONTH, 0, spi.DateInStock), 0) [BusinessMonthPriced],
	ROUND(spi.Price, 0) [rounded_Price],
	AVG(ssh.RegisterPrice) [avg_SellPrice],
	AVG(CAST(DATEDIFF(HOUR, spi.DateInStock, ssh.EndDate) AS FLOAT) / 24) [avg_DaysToSell],
	COUNT(ssh.SipsItemCode) [count_SoldItems],
	COUNT(spi.ItemCode) [count_PricedItems],
	CAST(COUNT(ssh.SipsItemCode) AS FLOAT) /
		CAST(COUNT(spi.ItemCode) AS FLOAT) [pct_SellThrough]
FROM ReportsData..SipsProductInventory spi
	INNER JOIN ReportsData..StoreLocationMaster slm
		ON spi.LocationNo = slm.LocationNo
		AND slm.StoreStatus = 'O'
		AND slm.OpenDate <= DATEADD(YEAR, -2, @StartDate)
	LEFT OUTER JOIN ReportsData..SipsSalesHistory ssh
		ON spi.ItemCode = ssh.SipsItemCode
		AND ssh.IsReturn = 'N'
WHERE 
	spi.DateInStock >= @StartDate
	AND spi.DateInStock < @EndDate
	AND spi.Price <= 20.0
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, spi.DateInStock), 0), ROLLUP(ROUND(spi.Price, 0))
ORDER BY BusinessMonthPriced, rounded_Price

--SELECT
--	DATEADD(YEAR, DATEDIFF(YEAR, 0, spi.DateInStock), 0) [BusinessYearPriced],
--	ROUND(spi.Price, 0) [rounded_Price],
--	COUNT(spi.ItemCode) [count_PricedItems]
--INTO #PricedByYear
--FROM ReportsData..SipsProductInventory spi
--	INNER JOIN ReportsData..StoreLocationMaster slm
--		ON spi.LocationNo = slm.LocationNo
--		AND slm.StoreStatus = 'O'
--		AND slm.OpenDate <= DATEADD(YEAR, -2, @StartDate)
--GROUP BY DATEADD(YEAR, DATEDIFF(YEAR, 0, spi.DateInStock), 0), ROUND(spi.Price, 0) 


----Break out days to sell by price point into histogram
--SELECT 
--	DATEADD(YEAR, DATEDIFF(YEAR, 0, spi.DateInStock), 0) [BusinessYearPriced],
--	ROUND(spi.Price, 0) [rounded_Price],
--	ROUND((CAST(DATEDIFF(HOUR, spi.DateInStock, ssh.EndDate) AS FLOAT) / 24), 0) [DaysToSell],
--	pby.count_PricedItems,
--	COUNT(ssh.SipsItemCode) [count_SoldItems],
--	CAST(COUNT(ssh.SipsItemCode) AS FLOAT) / NULLIF(CAST(pby.count_PricedItems AS FLOAT), 0) [pct_SellThrough]
--INTO #PriceSellThrough
--FROM ReportsData..SipsProductInventory spi
--	INNER JOIN ReportsData..StoreLocationMaster slm
--		ON spi.LocationNo = slm.LocationNo
--		AND slm.StoreStatus = 'O'
--		AND slm.OpenDate <= DATEADD(YEAR, -2, @StartDate)
--	LEFT OUTER JOIN ReportsData..SipsSalesHistory ssh
--		ON spi.ItemCode = ssh.SipsItemCode
--		AND ssh.IsReturn = 'N'
--	INNER JOIN #PricedByYear pby
--		ON DATEADD(YEAR, DATEDIFF(YEAR, 0, spi.DateInStock), 0) = pby.BusinessYearPriced
--		AND ROUND(spi.Price, 0) = pby.rounded_Price
--WHERE 
--		(DATEDIFF(HOUR, spi.DateInStock, ssh.EndDate) / 24) <= 180
--	AND spi.DateInStock >= @StartDate
--	AND spi.DateInStock < @EndDate
--	AND spi.Price <= 20.0
--	AND  ssh.EndDate >= spi.DateInStock
--GROUP BY 
--	DATEADD(YEAR, DATEDIFF(YEAR, 0, spi.DateInStock), 0),
--	ROUND(spi.Price, 0),
--	ROUND((CAST(DATEDIFF(HOUR, spi.DateInStock, ssh.EndDate) AS FLOAT) / 24), 0),
--	pby.count_PricedItems

--SELECT 
--	pst.rounded_Price,
--	pst.BusinessYearPriced,
--	pst.pct_SellThrough,
--	pst.DaysToSell,
--	pst.count_SoldItems,
--	pst.count_PricedItems
--	--SUM(pst.DaysToSell) OVER (PARTITION BY pst.rounded_Price, pst.BusinessYearPriced ORDER BY pst.BusinessYearPriced)
--FROM #PriceSellThrough pst
--ORDER BY BusinessYearPriced, rounded_Price, DaysToSell

--DROP TABLE #PricedByYear

DECLARE @StartDate DATE = '1/1/2013'
DECLARE @EndDate DATE = '1/1/2019'


SELECT 
	DATEADD(MONTH, DATEDIFF(MONTH, 0, spi.DateInStock), 0) [BusinessMonthPriced],
	CASE 
		WHEN spi.Price <= 0.125 * t.listPrice
			THEN ('0.25Half')
		WHEN spi.Price <= 0.25 * t.listPrice
			THEN ('0.50Half')
		WHEN spi.Price <= 0.375 * t.listPrice
			THEN ('0.75Half')
		WHEN spi.Price <= 0.55 * t.listPrice
			THEN ('1.00Half') 
		WHEN spi.Price > 0.55 * t.listPrice
			THEN ('OverHalf')
		END [PctOfHalfPrice],
	AVG(ssh.RegisterPrice) [avg_SellPrice],
	AVG(CAST(DATEDIFF(HOUR, spi.DateInStock, ssh.EndDate) AS FLOAT) / 24) [avg_DaysToSell],
	COUNT_BIG(ssh.SipsItemCode) [count_SoldItems],
	COUNT_BIG(spi.ItemCode) [count_PricedItems],
	CAST(COUNT_BIG(ssh.SipsItemCode) AS FLOAT) /
		CAST(COUNT_BIG(spi.ItemCode) AS FLOAT) [pct_SellThrough]
FROM ReportsData..SipsProductInventory spi
	INNER JOIN ReportsData..StoreLocationMaster slm
		ON spi.LocationNo = slm.LocationNo
		AND slm.StoreStatus = 'O'
		AND slm.OpenDate <= DATEADD(YEAR, -2, @StartDate)
	INNER JOIN ReportsData..SipsProductMaster spm
		ON spi.SipsID = spm.SipsID
	INNER JOIN Catalog..titles t
		 ON spm.CatalogId = t.catalogId
		 AND t.listPrice > 0.01
	LEFT OUTER JOIN ReportsData..SipsSalesHistory ssh
		ON spi.ItemCode = ssh.SipsItemCode
		AND ssh.IsReturn = 'N'
WHERE 
	spi.DateInStock >= @StartDate
	AND spi.DateInStock < @EndDate
	AND spi.Price <= 20.0
GROUP BY	
	DATEADD(MONTH, DATEDIFF(MONTH, 0, spi.DateInStock), 0),
	CASE 
		WHEN spi.Price <= 0.125 * t.listPrice
			THEN ('0.25Half')
		WHEN spi.Price <= 0.25 * t.listPrice
			THEN ('0.50Half')
		WHEN spi.Price <= 0.375 * t.listPrice
			THEN ('0.75Half')
		WHEN spi.Price <= 0.55 * t.listPrice
			THEN ('1.00Half') 
		WHEN spi.Price > 0.55 * t.listPrice
			THEN ('OverHalf')
		END
ORDER BY BusinessMonthPriced, PctOfHalfPrice

--SELECT
--	DATEADD(YEAR, DATEDIFF(YEAR, 0, spi.DateInStock), 0) [BusinessYearPriced],
--	ROUND(spi.Price, 0) [rounded_Price],
--	COUNT_BIG(spi.ItemCode) [count_PricedItems]
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
--	COUNT_BIG(ssh.SipsItemCode) [count_SoldItems],
--	CAST(COUNT_BIG(ssh.SipsItemCode) AS FLOAT) / NULLIF(CAST(pby.count_PricedItems AS FLOAT), 0) [pct_SellThrough]
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
--ORDER BY BusinessYearPriced, rounded_Price, DaysToSell


--DROP TABLE #PricedByYear
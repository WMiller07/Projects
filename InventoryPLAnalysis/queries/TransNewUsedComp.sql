DECLARE @StartDate DATE = '1/1/2013'
DECLARE @EndDate DATE = '8/1/2019'

--Get all item extended amounts from HPB_Sales for 2018 and 2019 with product types
SELECT
	slm.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0) [BusinessMonth],
	shh.SalesXactionID,
	SUM(sih.Quantity) [ItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
			THEN sih.Quantity
			END) [NewItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
			THEN sih.Quantity
			END) [UsedItemCount],
	SUM(sih.ExtendedAmt) [Sales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
		THEN sih.ExtendedAmt
		END) [NewItemSales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
		THEN sih.ExtendedAmt
		END) [UsedItemSales]
INTO #NewUsedSales
FROM HPB_SALES..SHH2019 shh
	INNER JOIN HPB_SALES..SIH2019 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.OpenDate < '1/1/2010'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih.ItemCode, 1) <> 0							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON sih.ItemCode = bi.ItemCode	
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'							
	AND shh.EndDate < @EndDate
GROUP BY slm.LocationNo, shh.SalesXactionID, DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0)
UNION ALL
SELECT
	slm.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0) [BusinessMonth],
	shh.SalesXactionID,
	SUM(sih.Quantity) [ItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
			THEN sih.Quantity
			END) [NewItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
			THEN sih.Quantity
			END) [UsedItemCount],
	SUM(sih.ExtendedAmt) [Sales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
		THEN sih.ExtendedAmt
		END) [NewItemSales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
		THEN sih.ExtendedAmt
		END) [UsedItemSales]
FROM HPB_SALES..SHH2018 shh
	INNER JOIN HPB_SALES..SIH2018 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.OpenDate < '1/1/2010'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih.ItemCode, 1) <> 0							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON sih.ItemCode = bi.ItemCode	
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'								
	AND shh.EndDate >= @StartDate
GROUP BY slm.LocationNo, shh.SalesXactionID, DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0)
UNION ALL
SELECT
	slm.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0) [BusinessMonth],
	shh.SalesXactionID,
	SUM(sih.Quantity) [ItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
			THEN sih.Quantity
			END) [NewItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
			THEN sih.Quantity
			END) [UsedItemCount],
	SUM(sih.ExtendedAmt) [Sales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
		THEN sih.ExtendedAmt
		END) [NewItemSales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
		THEN sih.ExtendedAmt
		END) [UsedItemSales]
FROM HPB_SALES..SHH2017 shh
	INNER JOIN HPB_SALES..SIH2017 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.OpenDate < '1/1/2010'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih.ItemCode, 1) <> 0							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON sih.ItemCode = bi.ItemCode	
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'								
	AND shh.EndDate >= @StartDate
GROUP BY slm.LocationNo, shh.SalesXactionID, DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0)
UNION ALL
SELECT
slm.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0) [BusinessMonth],
	shh.SalesXactionID,
	SUM(sih.Quantity) [ItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
			THEN sih.Quantity
			END) [NewItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
			THEN sih.Quantity
			END) [UsedItemCount],
	SUM(sih.ExtendedAmt) [Sales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
		THEN sih.ExtendedAmt
		END) [NewItemSales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
		THEN sih.ExtendedAmt
		END) [UsedItemSales]
FROM HPB_SALES..SHH2016 shh
	INNER JOIN HPB_SALES..SIH2016 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.OpenDate < '1/1/2010'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih.ItemCode, 1) <> 0							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON sih.ItemCode = bi.ItemCode	
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'								
	AND shh.EndDate >= @StartDate
GROUP BY slm.LocationNo, shh.SalesXactionID, DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0)
UNION ALL
SELECT
slm.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0) [BusinessMonth],
	shh.SalesXactionID,
	SUM(sih.Quantity) [ItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
			THEN sih.Quantity
			END) [NewItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
			THEN sih.Quantity
			END) [UsedItemCount],
	SUM(sih.ExtendedAmt) [Sales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
		THEN sih.ExtendedAmt
		END) [NewItemSales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
		THEN sih.ExtendedAmt
		END) [UsedItemSales]
FROM HPB_SALES..SHH2015 shh
	INNER JOIN HPB_SALES..SIH2015 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.OpenDate < '1/1/2010'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih.ItemCode, 1) <> 0							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON sih.ItemCode = bi.ItemCode	
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'								
	AND shh.EndDate >= @StartDate
GROUP BY slm.LocationNo, shh.SalesXactionID, DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0)
UNION ALL
SELECT
slm.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0) [BusinessMonth],
	shh.SalesXactionID,
	SUM(sih.Quantity) [ItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
			THEN sih.Quantity
			END) [NewItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
			THEN sih.Quantity
			END) [UsedItemCount],
	SUM(sih.ExtendedAmt) [Sales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
		THEN sih.ExtendedAmt
		END) [NewItemSales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
		THEN sih.ExtendedAmt
		END) [UsedItemSales]
FROM HPB_SALES..SHH2014 shh
	INNER JOIN HPB_SALES..SIH2014 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.OpenDate < '1/1/2010'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih.ItemCode, 1) <> 0							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON sih.ItemCode = bi.ItemCode	
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'								
	AND shh.EndDate >= @StartDate
GROUP BY slm.LocationNo, shh.SalesXactionID, DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0)
UNION ALL
SELECT
slm.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0) [BusinessMonth],
	shh.SalesXactionID,
	SUM(sih.Quantity) [ItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
			THEN sih.Quantity
			END) [NewItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
			THEN sih.Quantity
			END) [UsedItemCount],
	SUM(sih.ExtendedAmt) [Sales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
		THEN sih.ExtendedAmt
		END) [NewItemSales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
		THEN sih.ExtendedAmt
		END) [UsedItemSales]
FROM HPB_SALES..SHH2013 shh
	INNER JOIN HPB_SALES..SIH2013 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.OpenDate < '1/1/2010'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih.ItemCode, 1) <> 0							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON sih.ItemCode = bi.ItemCode	
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'								
	AND shh.EndDate >= @StartDate
GROUP BY slm.LocationNo, shh.SalesXactionID, DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0)
UNION ALL
SELECT
slm.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0) [BusinessMonth],
	shh.SalesXactionID,
	SUM(sih.Quantity) [ItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
			THEN sih.Quantity
			END) [NewItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
			THEN sih.Quantity
			END) [UsedItemCount],
	SUM(sih.ExtendedAmt) [Sales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
		THEN sih.ExtendedAmt
		END) [NewItemSales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
		THEN sih.ExtendedAmt
		END) [UsedItemSales]
FROM HPB_SALES..SHH2012 shh
	INNER JOIN HPB_SALES..SIH2012 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.OpenDate < '1/1/2010'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih.ItemCode, 1) <> 0							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON sih.ItemCode = bi.ItemCode	
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'								
	AND shh.EndDate >= @StartDate
GROUP BY slm.LocationNo, shh.SalesXactionID, DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0)
UNION ALL
SELECT
slm.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0) [BusinessMonth],
	shh.SalesXactionID,
	SUM(sih.Quantity) [ItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
			THEN sih.Quantity
			END) [NewItemCount],
	SUM(CASE
			WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
			THEN sih.Quantity
			END) [UsedItemCount],
	SUM(sih.ExtendedAmt) [Sales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NULL
		THEN sih.ExtendedAmt
		END) [NewItemSales],
	SUM(CASE
		WHEN ISNULL(spi.ItemCode, bi.ItemCode) IS NOT NULL
		THEN sih.ExtendedAmt
		END) [UsedItemSales]
FROM HPB_SALES..SHH2011 shh
	INNER JOIN HPB_SALES..SIH2011 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.OpenDate < '1/1/2010'
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih.ItemCode, 1) <> 0							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON sih.ItemCode = bi.ItemCode	
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'								
	AND shh.EndDate >= @StartDate
GROUP BY slm.LocationNo, shh.SalesXactionID, DATEADD(MONTH, DATEDIFF(MONTH, 0, shh.EndDate), 0)

SELECT 
	s.BusinessMonth,
	SUM(s.count_Transactions) [count_Transactions]
INTO #TransactionCount
FROM (
	SELECT 
		nus.BusinessMonth,
		nus.LocationNo,
		COUNT(DISTINCT nus.SalesXactionID) AS [count_Transactions]
	FROM #NewUsedSales nus
	GROUP BY nus.BusinessMonth, nus.LocationNo) s
GROUP BY s.BusinessMonth



SELECT
	nus.BusinessMonth,
	CAST(nus.LocationNo AS VARCHAR) + CAST(nus.SalesXactionID AS VARCHAR) [SalesXactionID],
	SUM(nus.ItemCount) [count_Items],
	SUM(nus.NewItemCount) [count_NewItems],
	SUM(nus.UsedItemCount) [count_UsedItems],
	SUM(nus.Sales) [total_Sales],
	SUM(nus.NewItemSales) [total_NewSales],
	SUM(nus.UsedItemSales) [total_UsedSales]
INTO #PerTransaction 
FROM #NewUsedSales nus
GROUP BY nus.BusinessMonth, nus.LocationNo, nus.SalesXactionID
ORDER BY nus.BusinessMonth



SELECT
	nus.BusinessMonth,
	CAST(SUM(nus.NewItemCount) AS FLOAT)/
		CAST(SUM(nus.ItemCount) AS FLOAT)  [pct_NewItems],
	CAST(SUM(nus.UsedItemCount) AS FLOAT)/
		CAST(SUM(nus.ItemCount) AS FLOAT) [pct_UsedItems],
	CAST(SUM(nus.NewItemSales) AS FLOAT)/
		CAST(SUM(nus.Sales) AS FLOAT) [pct_NewSales],
	CAST(SUM(nus.UsedItemSales) AS FLOAT)/
		CAST(SUM(nus.Sales) AS FLOAT) [pct_UsedSales]
INTO #NewUsedComp
FROM #NewUsedSales nus
GROUP BY nus.BusinessMonth
ORDER BY nus.BusinessMonth

SELECT 
	pt.BusinessMonth,
	tc.count_Transactions,
	SUM(pt.count_Items) [count_TotalItems],
	SUM(pt.count_UsedItems) [count_UsedItems],
	SUM(pt.count_NewItems) [count_NewItems],
	SUM(pt.total_Sales) [total_Sales],
	SUM(pt.total_UsedSales) [count_UsedSales],
	SUM(pt.total_NewSales) [count_NewSales],
	CAST(COUNT(
		CASE 
		WHEN ISNULL(pt.count_UsedItems, 0) = (ISNULL(pt.count_NewItems, 0) + ISNULL(pt.count_UsedItems, 0)) 
		THEN pt.SalesXactionID
		END) AS FLOAT) [count_Used100Pct],
		CAST(COUNT(
		CASE 
		WHEN (CAST(ISNULL(pt.count_UsedItems, 0) AS FLOAT) / 
				CAST(NULLIF((ISNULL(pt.count_NewItems, 0) + ISNULL(pt.count_UsedItems, 0)), 0) AS FLOAT)) >= 0.75
		THEN pt.SalesXactionID
		END) AS FLOAT) [count_UsedOver75Pct],
		CAST(COUNT(
		CASE 
		WHEN (CAST(ISNULL(pt.count_UsedItems, 0) AS FLOAT) / 
				CAST(NULLIF((ISNULL(pt.count_NewItems, 0) + ISNULL(pt.count_UsedItems, 0)), 0) AS FLOAT)) >= 0.5
		THEN pt.SalesXactionID
		END) AS FLOAT) [count_UsedOver50Pct],
	CAST(COUNT(
		CASE 
		WHEN (CAST(ISNULL(pt.count_NewItems, 0) AS FLOAT) / 
				CAST(NULLIF((ISNULL(pt.count_NewItems, 0) + ISNULL(pt.count_UsedItems, 0)), 0) AS FLOAT)) > 0.5
		THEN pt.SalesXactionID
		END) AS FLOAT) [count_NewOver50Pct],
	CAST(COUNT(
		CASE 
		WHEN (CAST(ISNULL(pt.count_NewItems, 0) AS FLOAT) / 
				CAST(NULLIF((ISNULL(pt.count_NewItems, 0) + ISNULL(pt.count_UsedItems, 0)), 0) AS FLOAT)) >= 0.75
		THEN pt.SalesXactionID
		END) AS FLOAT)  [count_NewOver75Pct],
	CAST(COUNT(
		CASE 
		WHEN ISNULL(pt.count_NewItems, 0) = (ISNULL(pt.count_NewItems, 0) + ISNULL(pt.count_UsedItems, 0)) 
		THEN pt.SalesXactionID
		END) AS FLOAT) [count_New100Pct]
FROM #PerTransaction pt
	INNER JOIN #NewUsedComp nuc
		ON pt.BusinessMonth = nuc.BusinessMonth
	INNER JOIN #TransactionCount tc
		ON pt.BusinessMonth = tc.BusinessMonth

WHERE pt.BusinessMonth >= '1/1/2013'
GROUP BY pt.BusinessMonth, tc.count_Transactions
ORDER BY pt.BusinessMonth


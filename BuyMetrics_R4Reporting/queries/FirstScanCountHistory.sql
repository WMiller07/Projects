SELECT 
	t.catalogId,
	spi.ItemCode,
	spi.LocationNo [Location_Priced],
	spi.DateInStock,
	spi.ProductType,
	sbj.[Subject],
	COALESCE(sis16.ScannedOn, sis17.ScannedOn, sish.ScannedOn, sis.ScannedOn) [first_ScanDate]
INTO #ScanHist
FROM MathLab..SipsItemKeys_test sik
	INNER JOIN ReportsData..SipsProductInventory spi
		ON sik.SipsItemCode = spi.ItemCode
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON spi.LocationNo = slm.LocationNo
		AND slm.StoreType = 'S'
		AND slm.StoreStatus = 'O'
		AND slm.OpenDate <= '1/1/2018'
	INNER JOIN Catalog..titles t
		ON sik.CatalogId = t.catalogId
	LEFT OUTER JOIN archShelfScan..ShelfItemScanHistory_2016 sis16
		ON sik.first_ShelfItemScanID = sis16.ShelfItemScanID
	LEFT OUTER JOIN archShelfScan..ShelfItemScanHistory_2017 sis17
		ON sik.first_ShelfItemScanID = sis17.ShelfItemScanID
	LEFT OUTER JOIN ReportsData..ShelfItemScanHistory sish
		ON sik.first_ShelfItemScanID = sish.ShelfItemScanID
	LEFT OUTER JOIN ReportsData..ShelfItemScan sis
		ON sik.first_ShelfItemScanID = sis.ShelfItemScanID
	LEFT OUTER JOIN ReportsData..ShelfScan ss
		ON sik.first_ShelfScanID = ss.ShelfScanID
	LEFT OUTER JOIN ReportsData..ShelfScanHistory ssh
		ON sik.first_ShelfScanID = ssh.ShelfScanID
	LEFT OUTER JOIN ReportsData..Shelf s
		ON ISNULL(ss.ShelfID, ssh.ShelfID) = s.ShelfID
	LEFT OUTER JOIN ReportsData..SubjectSummary sbj
		ON s.SubjectKey = sbj.SubjectKey
--WHERE COALESCE(sis16.ScannedOn, sis17.ScannedOn, sish.ScannedOn, sis.ScannedOn) >= '1/1/2018'




SELECT
	DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.first_ScanDate), 0) [BusinessMonth],
	CASE
		WHEN GROUPING(Location_Priced) = 1
		THEN 'All Locations'
		ELSE Location_Priced
		END [LocationNo],
	CASE 
		WHEN GROUPING(ProductType) = 1
		THEN 'All'
		ELSE ProductType
		END [ProductType],
	--CASE 
	--	WHEN GROUPING([Subject]) = 1
	--	THEN 'All'
	--	ELSE [Subject]
	--	END [ShelfSubject],
	COUNT(sh.ItemCode) [count_FirstScans],
	AVG(COUNT(sh.ItemCode)) OVER (PARTITION BY Location_Priced, ProductType 
		ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.first_ScanDate), 0) ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [12moAvg_CountFirstScans],
	COUNT(sh.ItemCode) -
		AVG(COUNT(sh.ItemCode)) OVER (PARTITION BY Location_Priced, ProductType 
			ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.first_ScanDate), 0) ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [Diff12moAvg_CountFirstScans]
INTO #CountFirstScans
FROM #ScanHist sh
WHERE sh.[Subject] NOT IN ('Backroom', 'Unprocessed Buys')
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, first_ScanDate), 0), Location_Priced, ProductType WITH CUBE
HAVING DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.first_ScanDate), 0) IS NOT NULL

SELECT 
	BusinessMonth,
	LocationNo,
	ProductType,
	--ShelfSubject,
	count_FirstScans,
	[12moAvg_CountFirstScans],
	[Diff12moAvg_CountFirstScans],
	CAST([Diff12moAvg_CountFirstScans] AS FLOAT) / 
		CAST([12moAvg_CountFirstScans] AS FLOAT) [pct_DiffFromAvg]
FROM #CountFirstScans
WHERE BusinessMonth >= '1/1/2019'
AND BusinessMonth < '8/1/2019'
ORDER BY LocationNo, ProductType, BusinessMonth

--SELECT
--	DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.first_ScanDate), 0) [BusinessMonth],
--	Location_Priced,
--	ProductType,
--	COUNT(DISTINCT sh.catalogId) [count_FirstScans],
--	AVG(COUNT(DISTINCT sh.catalogId)) OVER (PARTITION BY Location_Priced, ProductType 
--		ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.first_ScanDate), 0) ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [12moAvg_CountFirstScans],
--	COUNT(DISTINCT sh.catalogId) -
--		AVG(COUNT(DISTINCT sh.catalogId)) OVER (PARTITION BY Location_Priced, ProductType 
--			ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.first_ScanDate), 0) ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [Diff12moAvg_CountFirstScans]
--FROM #ScanHist sh
----WHERE ProductType IN ('UN', 'PB', 'CDU', 'DVD')
--GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, first_ScanDate), 0), Location_Priced, ProductType WITH CUBE
--ORDER BY Location_Priced, ProductType, BusinessMonth

DROP TABLE #ScanHist

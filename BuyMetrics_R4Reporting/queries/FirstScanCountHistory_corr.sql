SELECT 
	shh.LocationID,
	shh.SalesXactionID,
	shh.EndDate,
	shh.TotalDue
INTO #SalesHist
FROM HPB_SALES..SHH2019 shh
	INNER JOIN HPB_SALES..SIH2019 sih
		ON shh.LocationID = sih.LocationID
		AND shh.SalesXactionID = sih.SalesXactionId
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationId
WHERE shh.Status = 'A'
UNION
SELECT 
	shh.LocationID,
	shh.SalesXactionID,
	shh.EndDate,
	shh.TotalDue
FROM HPB_SALES..SHH2018 shh
	INNER JOIN HPB_SALES..SIH2018 sih
		ON shh.LocationID = sih.LocationID
		AND shh.SalesXactionID = sih.SalesXactionId
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationId
WHERE shh.Status = 'A'

SELECT 
	t.catalogId,
	spi.ItemCode,
	spi.LocationNo [Location_Priced],
	spi.DateInStock,
	spi.ProductType,
	COALESCE(sis16.ScannedOn, sis17.ScannedOn, sish.ScannedOn, sis.ScannedOn) [first_ScanDate]
INTO #ScanHist
FROM MathLab..SipsItemKeys_test sik
	INNER JOIN ReportsData..SipsProductInventory spi
		ON sik.SipsItemCode = spi.ItemCode
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
WHERE COALESCE(sis16.ScannedOn, sis17.ScannedOn, sish.ScannedOn, sis.ScannedOn) >= '1/1/2018'

SELECT
	DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.first_ScanDate), 0) [BusinessMonth],
	COUNT(sh.ItemCode) [count_FirstScans],
	AVG(COUNT(sh.ItemCode)) OVER (ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.first_ScanDate), 0) ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [12moAvg_CountFirstScans]
INTO #ScanSum
FROM #ScanHist sh
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, first_ScanDate), 0)


SELECT
	DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.EndDate), 0) [BusinessMonth],
	SUM(sh.TotalDue) [total_Sales],
	AVG(SUM(sh.TotalDue)) OVER (ORDER BY DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.EndDate), 0) ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [12moAvg_TotalSales]
INTO #SalesSum
FROM #SalesHist sh
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, sh.EndDate), 0)

SELECT 
	sc.BusinessMonth,
	sc.count_FirstScans,
	sa.total_Sales,
	sc.[12moAvg_CountFirstScans],
	sa.[12moAvg_TotalSales]
FROM #ScanSum sc
	INNER JOIN #SalesSum sa
		ON sc.BusinessMonth = sa.BusinessMonth
ORDER BY BusinessMonth
	


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


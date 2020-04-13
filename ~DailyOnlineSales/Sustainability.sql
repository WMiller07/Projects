DECLARE @StartDate DATE

SELECT 
	d.NRF_Year,
	d.NRF_MonthNum,
	d.NRF_Week_Restated,
	d.NRF_Day,
	d.Store_Date [BusinessDate]
INTO #Calendar 
FROM MathLab.dbo.NRF_Daily d

SELECT
	@StartDate = d.BusinessDate
FROM #Calendar d
WHERE d.NRF_Year = 2019
AND d.NRF_Day = 1


--Get scan history
SELECT
	 sish.ItemCodeSips,
	 --sish.ItemCodeDips,
	 --sish.SkuExtension,
	 sish.ShelfScanID,
	 sish.ScannedOn,
	 1 [isCurrent]
INTO #ShelfItemScanHistory
FROM ReportsData.dbo.ShelfItemScan sish
WHERE sish.ScannedOn >= @StartDate
UNION ALL 
SELECT
	 sish.ItemCodeSips,
	 --sish.ItemCodeDips,
	 --sish.SkuExtension,
	 sish.ShelfScanID,
	 sish.ScannedOn,
	 0 [isCurrent]
FROM ReportsData.dbo.ShelfItemScanHistory sish
WHERE sish.ScannedOn >= @StartDate
UNION ALL 
SELECT
	 sish.ItemCodeSips,
	 --sish.ItemCodeDips,
	 --sish.SkuExtension,
	 sish.ShelfScanID,
	 sish.ScannedOn,
	 0 [isCurrent]
FROM archShelfScan.dbo.ShelfItemScanHistory_2019 sish
WHERE sish.ScannedOn >= @StartDate
--UNION ALL 
--SELECT
--	 sish.ItemCodeSips,
--	 sish.ItemCodeDips,
--	 sish.SkuExtension,
--	 sish.ShelfScanID,
--	 sish.ScannedOn,
--	 0 [isCurrent]
--FROM archShelfScan.dbo.ShelfItemScanHistory_2018 sish
--WHERE sish.ScannedOn >= @StartDate
--UNION ALL
--SELECT
--	 sish.ItemCodeSips,
--	 sish.ItemCodeDips,
--	 sish.SkuExtension,
--	 sish.ShelfScanID,
--	 sish.ScannedOn,
--	 0 [isCurrent]
--FROM archShelfScan.dbo.ShelfItemScanHistory_2017 sish
--WHERE sish.ScannedOn >= @StartDate



--Get retail sales history
SELECT 
	sih.LocationID,
	sih.ItemCode,
	sih.SkuExtension,
	sih.BusinessDate, 
	sih.RegisterPrice
INTO #temp_RetailSales
FROM HPB_SALES.dbo.SIH2020 sih
WHERE ISNULL(sih.ItemCode, sih.SkuExtension) IS NOT NULL
AND sih.BusinessDate >= @StartDate
AND sih.IsReturn = 'N'
AND sih.Status = 'A'
UNION ALL
SELECT 
	sih.LocationID,
	sih.ItemCode,
	sih.SkuExtension,
	sih.BusinessDate, 
	sih.RegisterPrice
FROM HPB_SALES.dbo.SIH2019 sih
WHERE ISNULL(sih.ItemCode, sih.SkuExtension) IS NOT NULL
AND sih.BusinessDate >= @StartDate
AND sih.IsReturn = 'N'
AND sih.Status = 'A'
--UNION ALL
--SELECT 
--	sih.LocationID,
--	sih.ItemCode,
--	sih.SkuExtension,
--	sih.BusinessDate, 
--	sih.RegisterPrice
--FROM HPB_SALES.dbo.SIH2018 sih
--WHERE ISNULL(sih.ItemCode, sih.SkuExtension) IS NOT NULL
--AND sih.IsReturn = 'N'
--AND sih.Status = 'A'
--UNION ALL
--SELECT 
--	sih.LocationID,
--	sih.ItemCode,
--	sih.SkuExtension,
--	sih.BusinessDate, 
--	sih.RegisterPrice
--FROM HPB_SALES.dbo.SIH2017 sih
--WHERE ISNULL(sih.ItemCode, sih.SkuExtension) IS NOT NULL
--AND sih.IsReturn = 'N'
--AND sih.Status = 'A'

SELECT 
	spi.ItemCode,
	--sish.ItemCodeDips,
	--sish.SkuExtension,
	sish.isCurrent,
	MIN(sish.ScannedOn) [firstScannedOn],
	MAX(sish.ScannedOn) [lastScannedOn]
INTO #ScanSummary
FROM #ShelfItemScanHistory sish
	LEFT OUTER JOIN ReportsData.dbo.ShelfScan ss
		ON sish.ShelfScanID = ss.ShelfScanID
	LEFT OUTER JOIN ReportsData.dbo.ShelfScanHistory ssh
		ON sish.ShelfScanID = ssh.ShelfScanID
	LEFT OUTER JOIN ReportsData.dbo.Shelf s
		ON ISNULL(ss.ShelfID, ssh.ShelfID) = s.ShelfID
	LEFT OUTER JOIN ReportsData.dbo.SipsProductInventory spi
		ON sish.ItemCodeSips = spi.ItemCode
		AND spi.ItemStatus <> 0
WHERE s.ListOnline = 1
	AND spi.ItemCode IS NOT NULL
GROUP BY spi.ItemCode, sish.isCurrent

SELECT 
	DATEADD(DAY, DATEDIFF(DAY, 0, s.BusinessDate), 0) [BusinessDate],
	spi.ItemCode [ItemCodeSips],
	pm.ItemCode [ItemCodeDips],
	s.SkuExtension [SkuExtension],
	s.RegisterPrice,
	DATEDIFF(SECOND, ISNULL(ss.firstScannedOn, spi.DateInStock), s.BusinessDate) [DaysToSell_Retail]
INTO #RetailSales
FROM #temp_RetailSales s
	INNER JOIN (
			SELECT
				ItemCode,
				SkuExtension,
				MAX(BusinessDate) [lastBusinessDate]
			FROM #temp_RetailSales
			GROUP BY ItemCode, SkuExtension) ls
		ON s.ItemCode = ls.ItemCode
		AND s.SkuExtension = ls.SkuExtension
		AND s.BusinessDate = ls.lastBusinessDate
	INNER JOIN ReportsData..StoreLocationMaster slm
		ON s.LocationID = slm.LocationID
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(s.ItemCode, 1) = '0'							--Distro items start with 0 in the sales tables
		AND s.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON LEFT(s.ItemCode, 1) = '0'
		AND s.ItemCode = bi.ItemCode
	LEFT OUTER JOIN ReportsData.dbo.SipsProductInventory spi
		ON	LEFT(s.ItemCode, 1) <> '0'							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(s.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
	LEFT OUTER JOIN #ScanSummary ss
		ON spi.ItemCode = ss.ItemCode
	--LEFT OUTER JOIN #ShelfItemScanHistory sish_u
	--	ON spi.ItemCode = sish_u.ItemCodeSips
	--	AND sish_u.ItemCodeSips IS NOT NULL
	--LEFT OUTER JOIN #ShelfItemScanHistory sish_d
	--	ON pm.ItemCode = sish_d.ItemCodeDips
	--	AND pm.ItemCode = sish_d.ItemCodeDips
	--	AND sish_d.SkuExtension IS NOT NULL
	WHERE s.ItemCode NOT LIKE '%[^0-9]%'	
	
DROP TABLE #temp_RetailSales		





SELECT
	DATEADD(DAY, DATEDIFF(DAY, 0, tbh.UpdateTime), 0) [BusinessDate],
	tbd.SipsItemCode,
	DATEDIFF(SECOND, ISNULL(ss.firstScannedOn, spi.DateInStock), tbh.UpdateTime) [DaysToDisposal]
INTO #Disposed
FROM ReportsData.dbo.SipsTransferBinHeader tbh
	INNER JOIN ReportsData.dbo.SipsTransferBinDetail tbd
		ON tbh.TransferBinNo = tbd.TransferBinNo
	INNER JOIN ReportsData.dbo.SipsProductInventory spi
		ON tbd.SipsItemCode = spi.ItemCode
	LEFT OUTER JOIN #ScanSummary ss
		ON tbd.SipsItemCode = ss.ItemCode


SELECT 
	DATEADD(DAY, DATEDIFF(DAY, 0, ISNULL(om.RefundDate, om.ShipDate)), 0) [BusinessDate],
	om.ISIS_OrderID [iStoreOrder], --count of iStore orders
	om.Price [iStorePrice], --sum of iStore sales
	om.AmazonSalesRank,
	DATEDIFF(SECOND, ISNULL(ss.firstScannedOn, spi.DateInStock), ISNULL(om.RefundDate, om.ShipDate)) [DaysToSell_iStore]
INTO #iStoreSales
FROM ISIS.dbo.Order_Monsoon om
	INNER JOIN OFS.dbo.Order_Header oh
		ON om.ISIS_OrderID = oh.ISISOrderID
		AND oh.OrderSystem IN ('MON', 'HMP') --Excludes SAS and XFR, which are included in register sales
	INNER JOIN OFS.dbo.Order_Detail od --Purpose of order detail is only to get fulfilling location 
		ON oh.OrderID = od.OrderID
			--Problem orders have ProblemStatusID not null
		AND od.[Status] IN (1, 4) --Status codes of shipped orders
		AND (od.ProblemStatusID IS NULL
		OR od.ProblemStatusID = 0)
	LEFT OUTER JOIN ReportsData.dbo.SipsProductInventory spi
		ON od.ItemCode = spi.ItemCode
	LEFT OUTER JOIN #ScanSummary ss
		ON od.ItemCode = ss.ItemCode
WHERE 
	 om.ShippedQuantity > 0


SELECT 
	c.BusinessDate,
	COUNT(sa.ItemCode) [countShelvedItem],
	COUNT(CASE WHEN sa.isCurrent = 1
		THEN sa.ItemCode
		END) [count_ScannedItem_InStock],
	COUNT(d.SipsItemCode) [count_disposedItems],
	COUNT(rs.ItemCodeSips) [count_RetailSoldItems],
	AVG(rs.DaysToSell_Retail) [avg_RetailDaysToSell],
		COUNT(CASE WHEN rs.DaysToSell_Retail >= 0   AND rs.DaysToSell_Retail < 7  THEN sa.ItemCode END)		[count_RetailSoldItems_under7days],
		COUNT(CASE WHEN rs.DaysToSell_Retail >= 7   AND rs.DaysToSell_Retail < 28 THEN sa.ItemCode END)		[count_RetailSoldItems_7to28days],
		COUNT(CASE WHEN rs.DaysToSell_Retail >= 28  AND rs.DaysToSell_Retail < 56 THEN sa.ItemCode END)		[count_RetailSoldItems_28to56days],
		COUNT(CASE WHEN rs.DaysToSell_Retail >= 56  AND rs.DaysToSell_Retail < 112 THEN sa.ItemCode END)	[count_RetailSoldItems_56to112days],
		COUNT(CASE WHEN rs.DaysToSell_Retail >= 112 THEN sa.ItemCode END)									[count_RetailSoldItems_over112days],
	COUNT(iss.iStoreOrder) [count_iStoreSoldItems],
	AVG(iss.DaysToSell_iStore) [avg_iStoreDaysToSell],
		COUNT(CASE WHEN iss.DaysToSell_iStore >= 0   AND iss.DaysToSell_iStore < 7  THEN sa.ItemCode END)	[count_iStoreSoldItems_under7days],
		COUNT(CASE WHEN iss.DaysToSell_iStore >= 7   AND iss.DaysToSell_iStore < 28 THEN sa.ItemCode END)	[count_iStoreSoldItems_7to28days],
		COUNT(CASE WHEN iss.DaysToSell_iStore >= 28  AND iss.DaysToSell_iStore < 56 THEN sa.ItemCode END)	[count_iStoreSoldItems_28to56days],
		COUNT(CASE WHEN iss.DaysToSell_iStore >= 56  AND iss.DaysToSell_iStore < 112 THEN sa.ItemCode END)	[count_iStoreSoldItems_56to112days],
		COUNT(CASE WHEN iss.DaysToSell_iStore >= 112 THEN sa.ItemCode END)									[count_iStoreSoldItems_over112days]
FROM #Calendar c
	LEFT OUTER JOIN #ScanSummary sa
		ON c.BusinessDate = sa.firstScannedOn
	LEFT OUTER JOIN #Disposed d
		ON c.BusinessDate = d.BusinessDate
	LEFT OUTER JOIN #RetailSales rs
		ON c.BusinessDate = rs.BusinessDate
	LEFT OUTER JOIN #iStoreSales iss
		ON c.BusinessDate = iss.BusinessDate

DROP TABLE #Calendar
DROP TABLE #Disposed
DROP TABLE #iStoreSales
DROP TABLE #RetailSales
DROP TABLE #ScanSummary
DROP TABLE #ShelfItemScanHistory
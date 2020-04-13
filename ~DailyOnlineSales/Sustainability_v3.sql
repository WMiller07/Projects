SELECT
	sis.ScannedOn,
	sis.ItemCodeSips
INTO #ShelfItemScans
FROM ReportsData.dbo.ShelfItemScan sis
UNION ALL
SELECT
	sis.ScannedOn,
	sis.ItemCodeSips
FROM ReportsData.dbo.ShelfItemScanHistory sis
UNION ALL
SELECT
	sis.ScannedOn,
	sis.ItemCodeSips
FROM archShelfScan.dbo.ShelfItemScanHistory_2018 sis
UNION ALL
SELECT
	sis.ScannedOn,
	sis.ItemCodeSips
FROM archShelfScan.dbo.ShelfItemScanHistory_2017 sis


SELECT
	sis.ItemCodeSips,
	MIN(sis.ScannedOn) [DateInStock]
INTO #FirstScans
FROM #ShelfItemScans sis
GROUP BY sis.ItemCodeSips



SELECT 
	--om.ShipDate,
	--RIGHT(li.ServerName, 1) [Thicket],
	--om.Price,
	--om.ShippingFee,
	--om.AmazonSalesRank,
	--CASE WHEN spi.ItemCodeSips IS NOT NULL THEN 1 ELSE 0 END [isUsed],
	DATEADD(DAY, DATEDIFF(DAY, 0, om.ShipDate), 0) [BusinessDate],
	RIGHT(li.ServerName, 1) [Thicket],
	COUNT(om.ISIS_OrderID) [count_iStoreOrders], --count of iStore orders
	SUM(om.Price) [total_iStoreSales], --sum of iStore sales
	SUM(om.RefundAmount)[total_iStoreRefunds],
	SUM(om.ShippingFee) [total_iStoreShipping],
	SUM(om.ShippedQuantity) [total_iStoreQty], --sum of iStore quantity sold (multiple items per order occurs)
	COUNT(CASE 
			WHEN (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) < 15 
			THEN om.ISIS_OrderID END) [total_iStoreQty_AgedUnder15Days],
	COUNT(CASE 
				WHEN (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) >= 15 
				AND (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) < 30
				THEN om.ISIS_OrderID END) [total_iStoreQty_Aged15To30Days],
	COUNT(CASE 
				WHEN (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) >= 30
				AND (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) < 45 
				THEN om.ISIS_OrderID END) [total_iStoreQty_Aged30To45Days],
	COUNT(CASE 
				WHEN (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) >= 45
				AND (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) < 90 
				THEN om.ISIS_OrderID END) [total_iStoreQty_Aged45To90Days],
	COUNT(CASE 
				WHEN (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) >= 90 
				THEN om.ISIS_OrderID END) [total_iStoreQty_AgedOver90Days],
	SUM(CASE 
			WHEN (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) < 15 
			THEN om.Price END) [total_iStorePrice_AgedUnder15Days],
	SUM(CASE 
				WHEN (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) >= 15 
				AND (DATEDIFF(DAY, spi.DateInStock, om.ShipDate) ) < 30
				THEN om.Price END) [total_iStorePrice_Aged15To30Days],
	SUM(CASE 
				WHEN (DATEDIFF(DAY, spi.DateInStock, om.ShipDate)) >= 30
				AND (DATEDIFF(DAY, spi.DateInStock, om.ShipDate)) < 45 
				THEN om.Price END) [total_iStorePrice_Aged30To45Days],
	SUM(CASE 
				WHEN (DATEDIFF(DAY, spi.DateInStock, om.ShipDate)) >= 45
				AND (DATEDIFF(DAY, spi.DateInStock, om.ShipDate)) < 90 
				THEN om.Price END) [total_iStorePrice_Aged45To90Days],
	SUM(CASE 
				WHEN (DATEDIFF(DAY, spi.DateInStock, om.ShipDate)) >= 90 
				THEN om.Price END) [total_iStorePrice_AgedOver90Days]
	--SUM(ISNULL(spi.Price, pm.Price)) [total_iStoreCOGS]
--INTO #iStore_post
FROM ISIS..Order_Monsoon om
	INNER JOIN ISIS.dbo.App_ListingInstances li
		ON om.ListingInstanceID = li.ListingInstanceID
		AND li.Status = 'A'
	INNER JOIN OFS..Order_Header oh
		ON om.ISIS_OrderID = oh.ISISOrderID
		AND oh.OrderSystem = 'MON' --Excludes SAS and XFR, which are included in register sales
	INNER JOIN OFS..Order_Detail od --Purpose of order detail is only to get fulfilling location 
		ON oh.OrderID = od.OrderID
			--Problem orders have ProblemStatusID not null
		AND od.[Status] IN (1, 4) --Status codes of shipped orders
		AND (od.ProblemStatusID IS NULL
		OR od.ProblemStatusID = 0)
	LEFT OUTER JOIN #FirstScans spi
		ON LEFT(od.MarketSKU, 2) = 'S_'
		AND CAST(od.ItemCode AS INT) = CAST(spi.ItemCodeSips AS INT)
	--LEFT OUTER JOIN ReportsData.dbo.SipsProductInventory spi
	--	ON LEFT(od.MarketSKU, 2) = 'S_'
	--	AND CAST(od.ItemCode AS INT) = CAST(spi.ItemCode AS INT)
	LEFT OUTER JOIN ReportsData.dbo.ProductMaster pm
		ON LEFT(od.MarketSKU, 2) = 'D_'
		AND CAST(RIGHT(od.ItemCode, 10) AS BIGINT) = CAST(RIGHT(pm.ItemCode, 10) AS BIGINT)
WHERE om.RefundDate IS NULL
AND om.ShipDate > 0
AND DATEADD(DAY, DATEDIFF(DAY, 0, om.ShipDate), 0) >= '1/1/2018'
GROUP BY DATEADD(DAY, DATEDIFF(DAY, 0, om.ShipDate), 0),  RIGHT(li.ServerName, 1)
ORDER BY DATEADD(DAY, DATEDIFF(DAY, 0, om.ShipDate), 0),  RIGHT(li.ServerName, 1)

DROP TABLE #FirstScans
DROP TABLE #ShelfItemScans
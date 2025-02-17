SELECT 
	[ASIN],
	RIGHT(li.ServerName, 1) [Thicket],
	SKU,
	CASE WHEN SKU LIKE 'S_%' THEN 1 ELSE 0 END [isUsed],
	Price,
	CASE WHEN im.AmazonSalesRank = 0 THEN NULL ELSE im.AmazonSalesRank END [AmazonSalesRank],
	im.AmazonLowestPrice,
	CASE WHEN PricedAtFloor = 'True' THEN 1 ELSE 0 END [PricedAtFloor],
	CostOfGoods,
	DATEDIFF(DAY, InsertDate, GETDATE()) [DaysInStock]
FROM [ISIS].[dbo].[Inventory_Monsoon] im
	INNER JOIN ISIS.dbo.App_ListingInstances li
		ON im.ListingInstanceID = li.ListingInstanceID
		AND li.[Status] = 'A'
WHERE RIGHT(li.ServerName, 1) <> '7'




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
	om.[ASIN],
	RIGHT(li.ServerName, 1) [Thicket],
	DATEADD(DAY, DATEDIFF(DAY, 0, om.OrderDate) , 0) [OrderDate],
	CASE WHEN om.SKU LIKE 'S_%' THEN 1 ELSE 0 END [isUsed],
	om.Price,
	CASE WHEN om.AmazonSalesRank = 0 THEN NULL ELSE om.AmazonSalesRank END [AmazonSalesRank],
	om.AmazonLowestPrice,
	DATEDIFF(DAY, spi.DateInStock, om.ShipDate) [DaysInStock]
FROM ISIS.dbo.Order_Monsoon om
	INNER JOIN ISIS.dbo.App_ListingInstances li
		ON om.ListingInstanceID = li.ListingInstanceID
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
WHERE om.RefundDate IS NULL
AND om.ShipDate >= '1/1/2019'

DROP TABLE #ShelfItemScans
DROP TABLE #FirstScans
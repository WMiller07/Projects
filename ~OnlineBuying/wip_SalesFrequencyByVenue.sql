DECLARE @EndDate DATE = GETDATE()
DECLARE @StartDate DATE = DATEADD(MONTH, -13, @EndDate)

SELECT 
	im.CatalogID,
	od.SKU [MonsoonItemCode],
	od.ServerID,
	od.RefundAmount,
	od.ShipDate
INTO #CatalogMonsoonOrders
FROM Monsoon.dbo.OrderDetails od
	INNER JOIN Base_Analytics_Cashew.dbo.IdentifierToCatalogIdMapping im
		ON ISNULL(od.ISBN, od.UPC) = ISNULL(im.ISBN, im.UPC)
WHERE 
		LEFT(od.SKU, 3) = 'mon' 
	AND im.CatalogID IS NOT NULL
	AND od.ShipDate >= @StartDate
	AND od.ShipDate < @EndDate
UNION ALL
SELECT 
	im.CatalogID,
	od.SKU [MonsoonItemCode],
	od.ServerID,
	od.RefundAmount,
	od.ShipDate
FROM Monsoon.dbo.OrderDetailsArchive od
	INNER JOIN Base_Analytics_Cashew.dbo.IdentifierToCatalogIdMapping im
		ON ISNULL(od.ISBN, od.UPC) = ISNULL(im.ISBN, im.UPC)
WHERE	LEFT(od.SKU, 3) = 'mon' 
	AND im.CatalogID IS NOT NULL
	AND od.ShipDate >= @StartDate
	AND od.ShipDate < @EndDate

SELECT 
	om.CatalogID,
	ISNULL(COUNT(CASE 
			WHEN ms.LocationNo LIKE '006%' 
			THEN om.MonsoonItemCode
			END), 0) [countSoldItems_BookSmarter],
	ISNULL(COUNT(CASE 
			WHEN ms.LocationNo LIKE '002%' 
			THEN om.MonsoonItemCode
			END), 0) [countSoldItems_Outlet]
INTO #MonsoonOrderTypes
FROM #CatalogMonsoonOrders om
	INNER JOIN Monsoon.dbo.MonsoonServers ms
		ON om.ServerID = ms.ServerID
GROUP BY om.CatalogID 


SELECT 
	spm.CatalogID,
	--COUNT(spi.ItemCode) [countSipsPricedItems],
	ISNULL(COUNT(s.SipsItemCode), 0) [countSipsSoldItems],
	COUNT(CASE 
			WHEN s.MarketTypeID = 1
			THEN s.SipsItemCode
			END) [countSipsSoldItems_POS],
	COUNT(CASE 
			WHEN s.MarketTypeID = 2
			THEN s.SipsItemCode
			END) [countSipsSoldItems_Monsoon],
	COUNT(CASE 
			WHEN s.MarketTypeID = 4
			THEN s.SipsItemCode
			END) [countSipsSoldItems_SearchAndShip],
	COUNT(CASE 
			WHEN s.MarketTypeID = 5
			THEN s.SipsItemCode
			END) [countSipsSoldItems_HPBcom],
	COUNT(CASE 
			WHEN s.MarketTypeID = 3
			THEN s.SipsItemCode
			END) [countSipsSoldItems_MonsoonRefund],
	COUNT(CASE 
			WHEN s.MarketTypeID = 6
			THEN s.SipsItemCode
			END) [countSipsSoldItems_HPBcomRefund]
INTO #SipsOnlineOrders
FROM ReportsData.dbo.SipsProductInventory spi
	INNER JOIN ReportsData.dbo.SipsProductMaster spm
		ON spi.SipsID = spm.SipsID 
	LEFT OUTER JOIN Base_Analytics_Cashew.dbo.Sales s
		ON spi.ItemCode = s.SipsItemCode
WHERE spm.CatalogID IS NOT NULL
	AND s.BusinessDate >= @StartDate
	AND s.BusinessDate < @EndDate
GROUP BY spm.CatalogId


SELECT 
	soo.CatalogId,
	--soo.countSipsPricedItems,
	--NULL [countMonsoonPricedItems],
	soo.countSipsSoldItems,
	ISNULL(mot.countSoldItems_BookSmarter, 0) + ISNULL(mot.countSoldItems_Outlet, 0) [countMonsoonSoldItems],
	soo.countSipsSoldItems_POS,
	soo.countSipsSoldItems_Monsoon,
	soo.countSipsSoldItems_SearchAndShip,
	soo.countSipsSoldItems_HPBcom,
	mot.countSoldItems_BookSmarter,
	mot.countSoldItems_Outlet,
	soo.countSipsSoldItems_MonsoonRefund,
	soo.countSipsSoldItems_HPBcomRefund,

	ISNULL((CAST(soo.countSipsSoldItems_POS AS FLOAT)/ 
		NULLIF(CAST((ISNULL(soo.countSipsSoldItems, 0) + ISNULL((mot.countSoldItems_BookSmarter + mot.countSoldItems_Outlet), 0)) AS FLOAT), 0)) , 0) [pctSoldItems_POS],
	ISNULL((CAST(soo.countSipsSoldItems_Monsoon AS FLOAT)/ 
		NULLIF(CAST((ISNULL(soo.countSipsSoldItems, 0) + ISNULL((mot.countSoldItems_BookSmarter + mot.countSoldItems_Outlet), 0)) AS FLOAT), 0)) , 0) [pctSoldItems_Monsoon],
	ISNULL((CAST(soo.countSipsSoldItems_SearchAndShip AS FLOAT) / 
		NULLIF(CAST((ISNULL(soo.countSipsSoldItems, 0) + ISNULL((mot.countSoldItems_BookSmarter + mot.countSoldItems_Outlet), 0)) AS FLOAT), 0)) , 0) [pctSoldItems_SearchAndShip],
	ISNULL((CAST(soo.countSipsSoldItems_HPBcom AS FLOAT) /
		NULLIF(CAST((ISNULL(soo.countSipsSoldItems, 0) + ISNULL((mot.countSoldItems_BookSmarter + mot.countSoldItems_Outlet), 0)) AS FLOAT), 0)) , 0) [pctSoldItems_HPBcom],

	ISNULL((CAST(mot.countSoldItems_BookSmarter AS FLOAT) / 
		NULLIF(CAST((ISNULL(soo.countSipsSoldItems, 0) + ISNULL((mot.countSoldItems_BookSmarter + mot.countSoldItems_Outlet), 0)) AS FLOAT), 0)) , 0) [pctSoldItems_BookSmarter],
	ISNULL((CAST(mot.countSoldItems_Outlet AS FLOAT) /
		NULLIF(CAST((ISNULL(soo.countSipsSoldItems, 0) + ISNULL((mot.countSoldItems_BookSmarter + mot.countSoldItems_Outlet), 0)) AS FLOAT), 0)) , 0) [pctSoldItems_Outlet]

FROM #SipsOnlineOrders soo
	LEFT OUTER JOIN #MonsoonOrderTypes mot
		ON soo.CatalogId = mot.CatalogID
ORDER BY soo.CatalogId


DROP TABLE #CatalogMonsoonOrders
DROP TABLE #MonsoonOrderTypes
DROP TABLE #SipsOnlineOrders
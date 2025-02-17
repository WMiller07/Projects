DECLARE @EndDate DATE = GETDATE()
DECLARE @StartDate DATE = DATEADD(MONTH, -13, @EndDate)

--Only 82% of Monsoon SKUs can be mapped to catalogIDs using EAN/UPC
--Monsoon.dbo.OrderDetail EAN is always equal to 13 digit ISBN. 
--Monsoon.dbo.OrderDetail ISBN is most frequently stored as 10 digit by a large margin.
SELECT 
	im.CatalogID,
	od.SKU [MonsoonItemCode],
	od.ServerID,
	od.RefundAmount,
	od.ShipDate,
	od.ISBN,
	od.UPC,
	od.EAN
INTO #CatalogMonsoonOrders
FROM Monsoon.dbo.OrderDetails od
	LEFT OUTER JOIN Base_Analytics_Cashew.dbo.IdentifierToCatalogIdMapping im
		ON COALESCE(od.EAN, od.UPC) = ISNULL(im.ISBN, im.UPC)
WHERE 
		LEFT(od.SKU, 3) = 'mon' 
	--AND im.CatalogID IS NOT NULL
	AND od.ShipDate >= @StartDate
	AND od.ShipDate < @EndDate
UNION ALL
SELECT 
	im.CatalogID,
	od.SKU [MonsoonItemCode],
	od.ServerID,
	od.RefundAmount,
	od.ShipDate,
	od.ISBN,
	od.UPC,
	od.EAN
FROM Monsoon.dbo.OrderDetailsArchive od
	LEFT OUTER JOIN Base_Analytics_Cashew.dbo.IdentifierToCatalogIdMapping im
		ON COALESCE(od.EAN, od.UPC) = ISNULL(im.ISBN, im.UPC)
WHERE	LEFT(od.SKU, 3) = 'mon' 
	--AND im.CatalogID IS NOT NULL
	AND od.ShipDate >= @StartDate
	AND od.ShipDate < @EndDate

SELECT 
COUNT(CatalogID) [countCatalogAssignment],
COUNT(MonsoonItemCode) [countItems]
FROM #CatalogMonsoonOrders om
	INNER JOIN Monsoon.dbo.MonsoonServers ms
		ON om.ServerID = ms.ServerID
--WHERE ms.LocationNo LIKE '006%'

DROP TABLE #CatalogMonsoonOrders

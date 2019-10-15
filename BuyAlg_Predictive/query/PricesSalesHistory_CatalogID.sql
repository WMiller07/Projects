SELECT 
	t.catalogId,
	spi.LocationNo [Location_Priced],
	spi.DateInStock,
	COALESCE(sis16.ScannedOn, sis17.ScannedOn, sish.ScannedOn) [first_ScanDate],
	COALESCE(sih16.BusinessDate, sih17.BusinessDate, sih18.BusinessDate, sih19.BusinessDate) [date_Sale],
	COALESCE(sih16.RegisterPrice, sih17.RegisterPrice, sih18.RegisterPrice, sih19.RegisterPrice) [amt_Sale]
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
	LEFT OUTER JOIN HPB_SALES..SIH2016 sih16
		ON sik.SalesXactionID = sih16.SalesXactionId
		AND sik.LocationID = sih16.LocationId
		AND sih16.ItemCode NOT LIKE '%[^0-9]%'
		AND sik.SipsItemCode = CAST(RIGHT(sih16.ItemCode, 9) AS INT)
		AND LEFT(sih16.ItemCode, 1) <> '0'
	LEFT OUTER JOIN HPB_SALES..SIH2017 sih17
		ON sik.SalesXactionID = sih17.SalesXactionId
		AND sik.LocationID = sih17.LocationId
		AND sih17.ItemCode NOT LIKE '%[^0-9]%'
		AND sik.SipsItemCode = CAST(RIGHT(sih17.ItemCode, 9) AS INT)
		AND LEFT(sih17.ItemCode, 1) <> '0'
	LEFT OUTER JOIN HPB_SALES..SIH2018 sih18
		ON sik.SalesXactionID = sih18.SalesXactionId
		AND sik.LocationID = sih18.LocationId
		AND sih18.ItemCode NOT LIKE '%[^0-9]%'
		AND sik.SipsItemCode = CAST(RIGHT(sih18.ItemCode, 9) AS INT)
		AND LEFT(sih18.ItemCode, 1) <> '0'
	LEFT OUTER JOIN HPB_SALES..SIH2019 sih19
		ON sik.SalesXactionID = sih19.SalesXactionId
		AND sik.LocationID = sih19.LocationId
		AND sih19.ItemCode NOT LIKE '%[^0-9]%'
		AND sik.SipsItemCode = CAST(RIGHT(sih19.ItemCode, 9) AS INT)
		AND LEFT(sih19.ItemCode, 1) <> '0'
WHERE spi.DateInStock >= '1/1/2016'
	AND sik.IsReturn IS NULL


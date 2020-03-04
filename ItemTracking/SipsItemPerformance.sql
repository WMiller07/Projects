DECLARE @EndDate DATE = '6/1/2019'
DECLARE @StartDate DATE

SELECT 
	@StartDate = DATEADD(MONTH, -13, @EndDate)

SELECT 
	t.catalogId,
	t.title,
	t.author,
	spi.LocationNo,
	spi.ProductType,
	spi.ItemCode,
	spi.Price,
	spi.DateInStock,
	spi.Active
INTO #SipsPricedItems
FROM ReportsData..SipsProductInventory spi
	INNER JOIN ReportsData..SipsProductMaster spm
		ON spi.SipsID = spm.SipsID
	INNER JOIN Catalog..titles t
		ON spm.CatalogId = t.catalogId
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON spi.LocationNo = slm.LocationNo
		AND slm.StoreStatus = 'O'
		AND slm.StoreType = 'S'
		AND slm.OpenDate >= DATEADD(YEAR, -2, @StartDate)
WHERE spi.DateInStock >= @StartDate
	AND spi.DateInStock < @EndDate
	AND t.CatalogID NOT IN ('12962911')

SELECT 
	sis.ItemCodeSips,
	sis.ScannedOn
INTO #SipsShelfScans
FROM ReportsData..ShelfItemScan sis
UNION 
SELECT 
	sis.ItemCodeSips,
	sis.ScannedOn
FROM ReportsData..ShelfItemScanHistory sis

SELECT
	spi.ItemCode,
	MIN(ss.ScannedOn) [first_ScanDate]
INTO #FirstShelfScans
FROM #SipsShelfScans ss
	INNER JOIN #SipsPricedItems spi
		ON ss.ItemCodeSips = spi.ItemCode
GROUP BY spi.ItemCode

DROP TABLE #SipsShelfScans

SELECT 
	spi.ItemCode,
	tbh.UpdateTime [DateDisposed],
	CASE 
		WHEN tbh.TransferType IN (1, 2)
		THEN 1
		ELSE 0
		END [Disposed]
INTO #SipsItemTransfers
FROM ReportsData..SipsTransferBinHeader tbh
	INNER JOIN ReportsData..SipsTransferBinDetail tbd
		ON tbh.TransferBinNo = tbd.TransferBinNo
	INNER JOIN #SipsPricedItems spi
		ON tbd.SipsItemCode = spi.ItemCode

SELECT 
	spi.ItemCode,
	sih.BusinessDate,
	sih.RegisterPrice,
	CASE
		WHEN sih.RegisterPrice <= 3
		AND ROUND(sih.RegisterPrice, 0) = sih.RegisterPrice
		AND spi.ProductType NOT IN ('CX', 'MG', 'NOST')
		THEN 1
		ELSE 0
		END [isClearance]
INTO #SipsItemSales
FROM HPB_SALES..SHH2019 shh
	INNER JOIN HPB_SALES..SIH2019 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'			
	INNER JOIN #SipsPricedItems spi
		ON	LEFT(sih.ItemCode, 1) <> '0'							--Used items start non-zero values in the sales tables
		AND sih.ItemCode NOT LIKE '%[^0-9]%'
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables	
WHERE sih.XactionType = 'S'
	AND sih.Status = 'A'
UNION
SELECT 
	spi.ItemCode,
	sih.BusinessDate,
	sih.RegisterPrice,
	CASE
		WHEN sih.RegisterPrice <= 3
		AND ROUND(sih.RegisterPrice, 0) = sih.RegisterPrice
		AND spi.ProductType NOT IN ('CX', 'MG', 'NOST')
		THEN 1
		ELSE 0
		END [isClearance]
FROM HPB_SALES..SHH2018 shh
	INNER JOIN HPB_SALES..SIH2018 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'			
	INNER JOIN #SipsPricedItems spi
		ON	LEFT(sih.ItemCode, 1) <> '0'							--Used items start non-zero values in the sales tables
		AND sih.ItemCode NOT LIKE '%[^0-9]%'
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables	
WHERE sih.XactionType = 'S'
	AND sih.Status = 'A'
	AND sih.BusinessDate >= @StartDate


SELECT 
	spi.catalogId,
	spi.ProductType,
	spi.title,
	spi.author,
	COUNT(spi.ItemCode)		[qty_ItemsPriced],
	COUNT(sis.ItemCode)		[qty_ItemSold],
	COUNT(CASE WHEN sis.isClearance = 1 THEN 1 END)  [qty_ClearanceItemSold],
	COUNT(CASE
			WHEN sit.Disposed = 1
			THEN 1
			END)			[qty_ItemsTrashed_tbh],
	
	SUM(spi.Price) [total_ShelfPrice],
	SUM(sis.RegisterPrice) [total_RegisterPrice],
	CAST(COUNT(sis.ItemCode) AS FLOAT) / NULLIF(CAST(COUNT(spi.ItemCode) AS FLOAT), 0) [pct_SellThrough],
	CAST(SUM(sis.RegisterPrice) AS FLOAT) / NULLIF(CAST(SUM(spi.Price) AS FLOAT), 0)[pct_SalesPotential],
	CAST(SUM(DATEDIFF(DAY, ISNULL(spi.DateInStock, fss.first_ScanDate), COALESCE(sis.BusinessDate, sit.DateDisposed, GETDATE()))) AS FLOAT)/
		NULLIF(CAST(COUNT(spi.ItemCode) AS FLOAT), 0) [avg_DaysOnShelf],
	VARP(DATEDIFF(DAY, ISNULL(fss.first_ScanDate, spi.DateInStock), COALESCE(sis.BusinessDate, sit.DateDisposed, GETDATE()))) [var_DaysOnShelf],
	MAX(DATEDIFF(DAY, ISNULL(fss.first_ScanDate, spi.DateInStock), COALESCE(sis.BusinessDate, sit.DateDisposed, GETDATE()))) [max_DaysOnShelf],
	MIN(DATEDIFF(DAY, ISNULL(fss.first_ScanDate, spi.DateInStock), COALESCE(sis.BusinessDate, sit.DateDisposed, GETDATE()))) [min_DaysOnShelf]
FROM #SipsPricedItems spi
	LEFT OUTER JOIN #FirstShelfScans fss
		ON spi.ItemCode = fss.ItemCode
	LEFT OUTER JOIN #SipsItemSales sis
		ON spi.ItemCode = sis.ItemCode
	LEFT OUTER JOIN #SipsItemTransfers sit
		ON spi.ItemCode = sit.ItemCode
		and sit.Disposed = 1
GROUP BY 	
	spi.catalogId,
	spi.ProductType,
	spi.title,
	spi.author
ORDER BY qty_ItemsPriced DESC

DROP TABLE #SipsPricedItems
DROP TABLE #SipsItemSales
DROP TABLE #FirstShelfScans
DROP TABLE #SipsItemTransfers
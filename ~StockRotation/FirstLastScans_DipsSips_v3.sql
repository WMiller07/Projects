--Select all shelf scan records from current back through as much of the history as desired.
SELECT 
	CAST(sis.ItemCodeSips AS BIGINT) [ItemCodeSips],
	CAST(sis.ItemCodeDips AS BIGINT) [ItemCodeDips],
	sis.SkuExtension, 
	sis.ScannedOn,
	sis.ShelfScanID,
	sis.ShelfItemScanID,
	1 [isCurrent]
INTO #ItemScanHistory
FROM ReportsData..ShelfItemScan sis
UNION ALL
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM ReportsData..ShelfItemScanHistory sish
UNION ALL
SELECT 
	CAST(sish17.ItemCodeSips AS BIGINT) [ItemCodeSips],
	CAST(sish17.ItemCodeDips AS BIGINT) [ItemCodeDips],
	sish17.SkuExtension,
	sish17.ScannedOn,
	sish17.ShelfScanID,
	sish17.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2017 sish17
UNION ALL
SELECT 
	CAST(sish16.ItemCodeSips AS BIGINT) [ItemCodeSips],
	CAST(sish16.ItemCodeDips AS BIGINT) [ItemCodeDips],
	sish16.SkuExtension, 
	sish16.ScannedOn,
	sish16.ShelfScanID,
	sish16.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2016 sish16
UNION ALL
SELECT 
	CAST(sish15.ItemCodeSips AS BIGINT) [ItemCodeSips],
	CAST(sish15.ItemCodeDips AS BIGINT) [ItemCodeDips],
	sish15.SkuExtension,
	sish15.ScannedOn,
	sish15.ShelfScanID,
	sish15.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2015 sish15

--Get the first scan date and last scan date for each scanned item in item scan history.
--In order to avoid join errors which will hang and crash the query, do not take DIPS records where SKU extension is NULL.
--It is important that these NULL SkuExtension records are removed at this step, as their inclusion past it will result in joins attempted on NULL values.
--DIPS items with a NULL SKU extension comprise 2.6% of shelf scan records.
SELECT	
	ISNULL(ish.ItemCodeSips, ish.ItemCodeDips) [ItemCode],
	ish.SkuExtension,
	COUNT(ish.ShelfItemScanID) [count_Scans],
	MIN(ish.ScannedOn) [first_ScanDate],
	MAX(ish.ScannedOn) [last_ScanDate]
INTO #FirstLastScans
FROM #ItemScanHistory ish
WHERE ISNULL(ish.ItemCodeSips, ish.SkuExtension) IS NOT NULL
GROUP BY
	ISNULL(ish.ItemCodeSips, ish.ItemCodeDips),
	ish.SkuExtension


--Get data corresponding to the first scan date of each item.
SELECT 
	ISNULL(ish.ItemCodeSips, ish.ItemCodeDips) [ItemCode], 
	ish.SkuExtension,
	ish.isCurrent,
	ish.ShelfItemScanID [first_ShelfItemScanID],
	ish.ShelfScanID [first_ShelfScanID],
	fs.first_ScanDate
INTO #FirstScans
FROM #ItemScanHistory ish
	INNER JOIN #FirstLastScans fs
		ON ISNULL(ish.ItemCodeSips, ish.ItemCodeDips) = fs.ItemCode
		AND ish.ScannedOn = fs.first_ScanDate
		AND (ish.SkuExtension = fs.SkuExtension
			OR ish.SkuExtension IS NULL
			)

--Get data corresponding to the last scan date of each item.
SELECT 
	ISNULL(ish.ItemCodeSips, ish.ItemCodeDips) [ItemCode],
	ish.SkuExtension,
	ish.isCurrent,
	ish.ShelfItemScanID [last_ShelfItemScanID],
	ish.ShelfScanID [last_ShelfScanID],
	ls.last_ScanDate
INTO #LastScans
FROM #ItemScanHistory ish
	INNER JOIN #FirstLastScans ls
		ON ISNULL(ish.ItemCodeSips, ish.ItemCodeDips) = ls.ItemCode
		AND ish.ScannedOn = ls.last_ScanDate
		AND (ish.SkuExtension = ls.SkuExtension
			OR ish.SkuExtension IS NULL 
			)

--Store selected data in table	
SELECT 
	fs.ItemCode,
	fs.SkuExtension,
	fs.isCurrent,
	fs.first_ScanDate,
	fs.first_ShelfScanID,
	fs.first_ShelfItemScanID,
	ls.last_ScanDate,
	ls.last_ShelfScanID,
	ls.last_ShelfItemScanID
INTO Sandbox..FirstLastScans_All
FROM #FirstScans fs
	INNER JOIN #LastScans ls
		ON fs.ItemCode = ls.ItemCode
		AND (fs.SkuExtension = ls.SkuExtension
			OR fs.SkuExtension IS NULL
			)


DROP TABLE #ItemScanHistory
DROP TABLE #FirstLastScans
DROP TABLE #FirstScans
DROP TABLE #LastScans
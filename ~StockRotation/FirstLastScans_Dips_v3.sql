--Get the last scan date for each item in the history plus the 2017 archives


SELECT 
	--sis.ItemCodeSips,
	sis.ItemCodeDips,
	sis.SkuExtension, 
	sis.ScannedOn,
	sis.ShelfScanID,
	sis.ShelfItemScanID,
	1 [isCurrent]
INTO #ItemScanHistory
FROM ReportsData..ShelfItemScan sis
UNION ALL
SELECT 
	--sish.ItemCodeSips,
	sish.ItemCodeDips,
	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM ReportsData..ShelfItemScanHistory sish
UNION ALL
SELECT 
	--sish17.ItemCodeSips,
	sish17.ItemCodeDips,
	sish17.SkuExtension,
	sish17.ScannedOn,
	sish17.ShelfScanID,
	sish17.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2017 sish17
UNION ALL
SELECT 
	--sish16.ItemCodeSips,
	sish16.ItemCodeDips,
	sish16.SkuExtension, 
	sish16.ScannedOn,
	sish16.ShelfScanID,
	sish16.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2016 sish16
UNION ALL
SELECT 
	--sish15.ItemCodeSips,
	sish15.ItemCodeDips,
	sish15.SkuExtension,
	sish15.ScannedOn,
	sish15.ShelfScanID,
	sish15.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2015 sish15

SELECT	
	--ish.ItemCodeSips,
	ish.ItemCodeDips,
	ish.SkuExtension,
	COUNT(ish.ShelfItemScanID) [count_Scans],
	MIN(ish.ScannedOn) [first_ScanDate],
	MAX(ish.ScannedOn) [last_ScanDate]
INTO #FirstLastScans
FROM #ItemScanHistory ish
WHERE ish.SkuExtension IS NOT NULL
GROUP BY
	--ish.ItemCodeSips
	ish.ItemCodeDips,
	ish.SkuExtension

SELECT 
	ish.ItemCodeDips,
	ish.SkuExtension,
	ish.isCurrent,
	ish.ShelfItemScanID [first_ShelfItemScanID],
	ish.ShelfScanID [first_ShelfScanID],
	fs.first_ScanDate
INTO #FirstScans
FROM #ItemScanHistory ish
	INNER JOIN #FirstLastScans fs
		ON ish.ItemCodeDips = fs.ItemCodeDips
		AND ish.SkuExtension = fs.SkuExtension
		AND ish.SkuExtension IS NOT NULL
		AND ish.ScannedOn = fs.first_ScanDate

SELECT 
	ish.ItemCodeDips,
	ish.SkuExtension,
	ish.isCurrent,
	ish.ShelfItemScanID [last_ShelfItemScanID],
	ish.ShelfScanID [last_ShelfScanID],
	ls.last_ScanDate
INTO #LastScans
FROM #ItemScanHistory ish
	INNER JOIN #FirstLastScans ls
		ON ish.ItemCodeDips = ls.ItemCodeDips
		AND ish.SkuExtension = ls.SkuExtension
		AND ish.SkuExtension IS NOT NULL
		AND ish.ScannedOn = ls.first_ScanDate

	
SELECT 
	fs.ItemCodeDips,
	fs.SkuExtension,
	fs.isCurrent,
	fs.first_ScanDate,
	fs.first_ShelfScanID,
	fs.first_ShelfItemScanID,
	ls.last_ScanDate,
	ls.last_ShelfScanID,
	ls.last_ShelfItemScanID
INTO Sandbox..FirstLastScans_DIPS
FROM #FirstScans fs
	INNER JOIN #LastScans ls
		ON fs.ItemCodeDips = ls.ItemCodeDips
		AND fs.SkuExtension = ls.SkuExtension


DROP TABLE #ItemScanHistory
DROP TABLE #FirstLastScans
DROP TABLE #FirstScans
DROP TABLE #LastScans
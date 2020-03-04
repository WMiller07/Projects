--Get the last scan date for each item in the history plus the 2017 archives


SELECT 
	sis.ItemCodeSips,
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
	sish.ItemCodeSips,
	sish.ItemCodeDips,
	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM ReportsData..ShelfItemScanHistory sish
UNION ALL
SELECT 
	sish17.ItemCodeSips,
	sish17.ItemCodeDips,
	sish17.SkuExtension,
	sish17.ScannedOn,
	sish17.ShelfScanID,
	sish17.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2017 sish17
UNION ALL
SELECT 
	sish16.ItemCodeSips,
	sish16.ItemCodeDips,
	sish16.SkuExtension, 
	sish16.ScannedOn,
	sish16.ShelfScanID,
	sish16.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2016 sish16
UNION ALL
SELECT 
	sish15.ItemCodeSips,
	sish15.ItemCodeDips,
	sish15.SkuExtension,
	sish15.ScannedOn,
	sish15.ShelfScanID,
	sish15.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2015 sish15

SELECT	
	ish.ItemCodeSips,
	ish.ItemCodeDips,
	ish.SkuExtension,
	COUNT(ish.ShelfItemScanID) [count_Scans],
	MIN(ish.ScannedOn) [first_ScanDate],
	MAX(ish.ScannedOn) [last_ScanDate]
INTO #FirstLastScans
FROM #ItemScanHistory ish
GROUP BY
	ish.ItemCodeSips,
	ish.ItemCodeDips,
	ish.SkuExtension

SELECT 
	ish.ItemCodeSips,
	NULL [ItemCodeDips],
	NULL [SkuExtension],
	ish.isCurrent,
	fs.ShelfItemScanID,
	ish.ShelfScanID,
	fs.count_Scans,
	fs.first_ScanDate,
	ls.last_ScanDate
--INTO Sandbox..FirstLastScans
FROM #ItemScanHistory ish
	LEFT OUTER JOIN #FirstLastScans fs
		ON ish.ItemCodeSips = fs.ItemCodeSips
		AND ish.ScannedOn = fs.first_ScanDate


	

DROP TABLE #ItemScanHistory
DROP TABLE #FirstLastScans
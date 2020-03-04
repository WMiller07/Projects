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
	MIN(ScannedOn) [FirstScanDate],
	MAX(ScannedOn) [LastScanDate],
	ish.isCurrent
INTO Sandbox..FirstLastScans
FROM #ItemScanHistory ish
WHERE ISNULL(ish.ItemCodeSips, ish.SkuExtension) IS NOT NULL
GROUP BY
	ish.ItemCodeSips,
	ish.ItemCodeDips,
	ish.SkuExtension,
	ish.isCurrent

DROP TABLE #ItemScanHistory
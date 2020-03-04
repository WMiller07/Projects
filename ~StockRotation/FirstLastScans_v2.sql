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
--UNION ALL
--SELECT 
--	sish16.ItemCodeSips,
--	sish16.ItemCodeDips,
--	sish16.SkuExtension, 
--	sish16.ScannedOn,
--	sish16.ShelfScanID,
--	sish16.ShelfItemScanID,
--	0 [isCurrent]
--FROM archShelfScan..ShelfItemScanHistory_2016 sish16
--UNION ALL
--SELECT 
--	sish15.ItemCodeSips,
--	sish15.ItemCodeDips,
--	sish15.SkuExtension,
--	sish15.ScannedOn,
--	sish15.ShelfScanID,
--	sish15.ShelfItemScanID,
--	0 [isCurrent]
--FROM archShelfScan..ShelfItemScanHistory_2015 sish15

SELECT	
	ish.ItemCodeSips,
	ish.ItemCodeDips,
	ish.SkuExtension,
	MIN(ish.ScannedOn) [FirstScanDate],
	MAX(ish.ScannedOn) [LastScanDate],
	ish.isCurrent
INTO #FirstLastScans
FROM #ItemScanHistory ish
WHERE ISNULL(ish.ItemCodeSips, ish.SkuExtension) IS NOT NULL
GROUP BY
	ish.ItemCodeSips,
	ish.ItemCodeDips,
	ish.SkuExtension,
	ish.isCurrent

SELECT 
	ish.ItemCodeSips,
	ish.ItemCodeDips,
	ish.SkuExtension,
	ish.isCurrent,
	ish.ShelfItemScanID,
	ish.ShelfScanID,
	ISNULL(fss.FirstScanDate, fsd.FirstScanDate) [FirstScanDate]
INTO #FirstScans
FROM #ItemScanHistory ish
	LEFT OUTER JOIN #FirstLastScans fss
		ON ish.ItemCodeSips = fss.ItemCodeSips
		AND ish.ScannedOn = fss.FirstScanDate
		AND fss.ItemCodeSips IS NOT NULL
	LEFT OUTER JOIN #FirstLastScans fsd
		ON ish.ItemCodeDips = fsd.ItemCodeDips
		AND ish.SkuExtension = fsd.SkuExtension
		AND ish.ScannedOn = fsd.FirstScanDate
		AND fsd.SkuExtension IS NOT NULL
WHERE ISNULL(fss.FirstScanDate, fsd.FirstScanDate) IS NOT NULL

SELECT 
	ish.ItemCodeSips,
	ish.ItemCodeDips,
	ish.SkuExtension,
	ish.isCurrent,
	ish.ShelfItemScanID,
	ish.ShelfScanID,
	ISNULL(lss.LastScanDate, lsd.LastScanDate) [LastScanDate]
INTO #LastScans
FROM #ItemScanHistory ish
	LEFT OUTER JOIN #FirstLastScans lss
		ON ish.ItemCodeSips = lss.ItemCodeSips
		AND ish.ScannedOn = lss.LastScanDate
		AND lss.ItemCodeSips IS NOT NULL
	LEFT OUTER JOIN #FirstLastScans lsd
		ON ish.ItemCodeDips = lsd.ItemCodeDips
		AND ish.SkuExtension = lsd.SkuExtension
		AND ish.ScannedOn = lsd.LastScanDate
		AND lsd.SkuExtension IS NOT NULL
WHERE ISNULL(lss.LastScanDate, lsd.LastScanDate) IS NOT NULL

DROP TABLE #FirstLastScans

SELECT 
	fs.ItemCodeSips,
	fs.ItemCodeDips,
	fs.SkuExtension,
	fs.isCurrent,
	fs.FirstScanDate,
	fs.ShelfItemScanID [First_ShelfItemScanID],
	fs.ShelfScanID [First_ShelfScanID],
	lss.ItemCodeSips,
	lsd.ItemCodeDips,
	lsd.SkuExtension,
	ISNULL(lss.LastScanDate, lsd.LastScanDate) [LastScanDate],
	ISNULL(lss.ShelfItemScanID, lsd.ShelfItemScanID) [Last_ShelfItemScanID],
	ISNULL(lss.ShelfScanID, lsd.ShelfScanID) [Last_ShelfScanID]
FROM #FirstScans fs
	LEFT OUTER JOIN #LastScans lss
		ON fs.ItemCodeSips =  lss.ItemCodeSips 
		AND lss.ItemCodeSips IS NOT NULL
	LEFT OUTER JOIN #LastScans lsd
		ON fs.ItemCodeDips = lsd.ItemCodeDips
		AND fs.SkuExtension = lsd.SkuExtension
		AND lss.SkuExtension IS NOT NULL
	

DROP TABLE #ItemScanHistory
--DROP TABLE #FirstScans
--DROP TABLE #LastScans
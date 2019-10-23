DECLARE @StartDate DATE = '1/1/2018'
DECLARE @EndDate DATE = '1/1/2019'


--Get all SIPS item scans in recent history
SELECT 
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	sish.ItemCodeSips,
	sish.ScanMode,
	sish.ScannedOn
INTO #ScanHistoryRecent
FROM ReportsData..ShelfItemScan sish --ShelfItemScan table contains current scan records (the last action taken on each SKU was a scan)
WHERE 
	sish.ScannedOn < @EndDate AND
	sish.ItemCodeSips IS NOT NULL
UNION ALL
SELECT 
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	sish.ItemCodeSips,
	sish.ScanMode,
	sish.ScannedOn
FROM ReportsData..ShelfItemScanHistory sish	--ShelfItemScanHistory table contains past scan records (another scan or some other action such as sale or transfer has occurred since these scans)
WHERE 
	sish.ScannedOn >= @StartDate AND
	sish.ItemCodeSips IS NOT NULL
	
SELECT 
	sh.ShelfScanID,
	sh.ShelfItemScanID,
	sh.ItemCodeSips,
	sh.ScanMode,
	sh.ScannedOn
INTO #FirstScans
FROM #ScanHistoryRecent sh
	INNER JOIN --Inner join to the first scans of each SIPS item code in the scan history.
			(SELECT 
				ItemCodeSips, 
				MIN(ScannedOn) [ScannedOn]
			 FROM #ScanHistoryRecent
		
			 GROUP BY ItemCodeSips) fs	 
		ON sh.ScannedOn = fs.ScannedOn

--Aggregate first scan information by LocationNo and Month
SELECT 
	slm.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, fs.ScannedOn), 0) [BusinessMonth],
	COUNT(CASE 
			WHEN fs.ScanMode = 1
			THEN fs.ItemCodeSips
			END) [count_FirstSingleScans],
	COUNT(CASE 
			WHEN fs.ScanMode = 2
			THEN fs.ItemCodeSips
			END) [count_FirstFullScans]
FROM #FirstScans fs
	--A unique ShelfScanID is created when a shelf is full scanned. The ShelfScan table contains only the current ShelfScanIDs.
	--Single scans are assigned to the current ShelfScanID until the next full scan initiates a new ShelfScanID.
	LEFT OUTER JOIN ReportsData..ShelfScan ss
		ON fs.ShelfScanID = ss.ShelfScanID
	--When a full scan creates a new ShelfScanID, the old ShelfScanID is moved to ShelfScanHistory. ShelfScanHistory contains all historical ShelfScanIDs
	LEFT OUTER JOIN ReportsData..ShelfScanHistory ssh
		ON fs.ShelfScanID = ss.ShelfScanID
	INNER JOIN ReportsData..StoreLocationMaster slm
		ON ISNULL(ss.LocationID, ssh.LocationID) = slm.LocationID --Determine location for each scan: if the first scan for an item is not current, check historical 
GROUP BY slm.LocationNo, DATEADD(MONTH, DATEDIFF(MONTH, 0, fs.ScannedOn), 0)
ORDER BY LocationNo, BusinessMonth

DROP TABLE #ScanHistoryRecent
DROP TABLE #FirstScans
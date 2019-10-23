DECLARE @StartDate DATE = '1/1/2018'
DECLARE @EndDate DATE = '7/1/2019'

SELECT 
	DATEADD(MONTH, DATEDIFF(MONTH, 0, sik.first_ScannedOn), 0) [BusinessMonth],
	CASE 
		WHEN GROUPING(slm.LocationNo) = 1
		THEN '~Chain Total'
		ELSE slm.LocationNo
	END [LocationNo],
	CASE
		WHEN GROUPING(sub.[Subject]) = 1
		THEN '~All Subjects'
		ELSE sub.[Subject]
		END [Subject],
	COUNT(CASE 
			WHEN ISNULL(sish.ScanMode, sis.ScanMode) = 1
			THEN sik.SipsItemCode
			END) [count_FirstSipsItemFullScans],
	COUNT(CASE 
			WHEN ISNULL(sish.ScanMode, sis.ScanMode) = 2
			THEN sik.SipsItemCode
			END) [count_FirstSipsItemSingleScans]
FROM MathLab..SipsItemKeys_test sik
	--ScanMode is stored in the ShelfItemScan and ShelfItemScanHistory tables. It is NULL in the the ShelfScan tables since both ScanModes are assigned to same ShelfScanIDs.
	LEFT OUTER JOIN ReportsData..ShelfItemScan sis
		ON sik.first_ShelfItemScanID = sis.ShelfItemScanID
	LEFT OUTER JOIN ReportsData..ShelfItemScanHistory sish
		ON sik.first_ShelfItemScanID = sish.ShelfItemScanID
	--LocationID for each scan is stored in the ShelfScan and ShelfScanHistory tables. It is not stored in the ShelfItemScan tables.
	LEFT OUTER JOIN ReportsData..ShelfScan ss
		ON sik.first_ShelfScanID = ss.ShelfScanID
	LEFT OUTER JOIN ReportsData..ShelfScanHistory ssh
		ON sik.first_ShelfScanID = ssh.ShelfScanID
	--Get ShelfID for each ShelfScanID, since ShelfID links to subject.
	LEFT OUTER JOIN ReportsData..Shelf s
		ON ISNULL(ss.ShelfID, ssh.ShelfID) = s.ShelfID
	--Determine location for each ShelfScanID: if the first ShelfScanID for an item is not current, check historical 
	INNER JOIN ReportsData..StoreLocationMaster slm
		ON ISNULL(ss.LocationID, ssh.LocationID) = slm.LocationID 
	--Get subject name for each subject key.
	INNER JOIN ReportsData..SubjectSummary sub
		ON s.SubjectKey = sub.SubjectKey
WHERE sik.first_ScannedOn >= @StartDate
	AND sik.first_ScannedOn < @EndDate
GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, sik.first_ScannedOn), 0), slm.LocationNo, sub.[Subject]  WITH CUBE
ORDER BY LocationNo, [Subject], BusinessMonth

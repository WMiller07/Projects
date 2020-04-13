DECLARE @StartYear int = 2019 --Cannot be prior to 2011 due to (self-imposed) historical sales data inclusion limits
DECLARE @StartDate datetime2
DECLARE @EndDate datetime2

SELECT
	@StartDate = MIN(nrf.Store_StartOfWeek),
	@EndDate = MAX(nrf.Store_EndOfWeek)
FROM Sandbox..NRF_Calendar nrf
WHERE nrf.Store_EndOfWeek <= GETDATE()
	AND nrf.NRF_Year >= @StartYear

SELECT 
	slm.LocationNo,
	nrf.NRF_Year,
	nrf.NRF_MonthName,
	nrf.NRF_MonthNum,
	nrf.NRF_Week,
	nrf.NRF_Week_Restated,
	nrf.Store_StartOfWeek,
	nrf.Store_EndOfWeek
INTO #KeyTable
FROM Sandbox..NRF_Calendar nrf
	CROSS JOIN ReportsData..StoreLocationMaster slm
WHERE 
	slm.StoreType IN ('S', 'O')
	AND nrf.Store_EndOfWeek <=  @EndDate
	AND nrf.Store_StartOfWeek >= @StartDate

SELECT 
	spi.LocationNo,
	spi.ProductType,
	spi.ItemCode,
	spi.SipsID,
	spi.Price,
	spi.DateInStock
INTO #SipsProductInventory
FROM ReportsData..SipsProductInventory spi
UNION
SELECT 
	spi.LocationNo,
	spi.ProductType,
	spi.ItemCode,
	spi.SipsID,
	spi.Price,
	spi.DateInStock
FROM archSIPS..archSipsProductInventory spi
UNION
SELECT 
	spi.LocationNo,
	spi.ProductType,
	spi.ItemCode,
	spi.SipsID,
	spi.Price,
	spi.DateInStock
FROM archSIPS..archSipsProductInventory2 spi
UNION
SELECT 
	spi.LocationNo,
	spi.ProductType,
	spi.ItemCode,
	spi.SipsID,
	spi.Price,
	spi.DateInStock
FROM archSIPS..archSipsProductInventory3 spi

/*******************
Sales
*******************/


SELECT 
	slm.LocationNo,
	ssh.BusinessDate,
	ssh.SipsItemCode,
	ssh.RegisterPrice,
	ssh.ExtendedAmt
INTO #Sales
FROM ReportsData..SipsSalesHistory ssh
INNER JOIN ReportsData..StoreLocationMaster slm
	ON ssh.LocationID = slm.LocationId
WHERE ssh.IsReturn = 'N'


/*******************
Buys

SELECT 
	slm.LocationNo,
	CAST(bhh.BuyXactionID AS BIGINT) [BuyXactionID], --Cast as INT to facilitate future join to updated buy tables
	bhh.EndDate [BusinessDate],
	bhh.TotalOffer,
	bhh.TotalQuantity,
	DATEDIFF(SECOND, bhh.StartDate, bhh.EndDate) [seconds_BuyWait],
	bhh.[Status] [BuyStatus]
INTO #Buys_pre
FROM rHPB_Historical.dbo.BuyHeaderHistory bhh
	INNER JOIN ReportsData.dbo.StoreLocationMaster slm
		ON bhh.LocationID = slm.LocationId
WHERE bhh.EndDate >= @StartDate
	AND bhh.EndDate <= @EndDate
	AND bhh.TotalQuantity < 10000
	AND bhh.TotalOffer < 100000
	AND bhh.[Status] = 'A'

SELECT 
	kt.LocationNo,
	kt.Store_StartOfWeek,
	COUNT(b.BuyXactionID) [buys_CountTransactions],
	SUM(b.TotalQuantity) [buys_QtyPurchased],
	SUM(b.TotalOffer) [buys_AmtPurchased],
	SUM(b.seconds_BuyWait) [buys_BuyWaitSeconds]
INTO #Buys_post
FROM #KeyTable kt
	INNER JOIN #Buys_pre b
		ON kt.LocationNo = b.LocationNo
		AND kt.Store_StartOfWeek <= b.BusinessDate
		AND kt.Store_EndOfWeek >= b.BusinessDate
GROUP BY kt.LocationNo, kt.Store_StartOfWeek

DROP TABLE #Buys_pre
*/

/*******************
Transfers
*******************/
SELECT 
	tbh.LocationNo [original_LocationNo],
	tbd.SipsItemCode
INTO #Transfers_OriginalLocations
FROM ReportsData.dbo.SipsTransferBinHeader tbh
	INNER JOIN ReportsData.dbo.SipsTransferBinDetail tbd
		ON tbh.TransferBinNo = tbd.TransferBinNo
	INNER JOIN (
			SELECT 
				tbd.SipsItemCode,
				MIN(tbd.TransferBinNo) [first_TransferBinNo]
			FROM ReportsData.dbo.SipsTransferBinHeader tbh
				INNER JOIN ReportsData.dbo.SipsTransferBinDetail tbd
					ON tbh.TransferBinNo = tbd.TransferBinNo
				INNER JOIN #SipsProductInventory spi
					ON tbd.SipsItemCode = spi.ItemCode
			WHERE tbd.SipsItemCode IS NOT NULL
			GROUP BY tbd.SipsItemCode
				) f
		ON tbd.TransferBinNo = f.first_TransferBinNo
		AND tbd.SipsItemCode = f.SipsItemCode

SELECT
	tbh.LocationNo,
	tbh.UpdateTime [BusinessDate],
	tbd.SipsItemCode,
	CASE WHEN tbh.TransferType NOT IN (3, 4) THEN 1 ELSE NULL END [bool_ToDispose],
	CASE WHEN tbh.TransferType = 3 THEN 1 ELSE NULL END [bool_ToLocation],
	CASE WHEN tbh.TransferType = 4 THEN 1 ELSE NULL END [bool_ToBookSmarter]
	--CASE WHEN f.SipsItemCode IS NOT NULL THEN 1 ELSE NULL END [bool_LastTransfer]
INTO #Transfers
FROM ReportsData.dbo.SipsTransferBinHeader tbh
	INNER JOIN ReportsData.dbo.SipsTransferBinDetail tbd
		ON tbh.TransferBinNo = tbd.TransferBinNo
	--To avoid occasional duplication issues
	--LEFT OUTER JOIN (
	--		SELECT 
	--			tbd.SipsItemCode,
	--			MAX(tbd.TransferBinNo) [last_TransferBinNo]
	--		FROM ReportsData.dbo.SipsTransferBinHeader tbh
	--			INNER JOIN ReportsData.dbo.SipsTransferBinDetail tbd
	--				ON tbh.TransferBinNo = tbd.TransferBinNo
	--			INNER JOIN #SipsProductInventory spi
	--				ON tbd.SipsItemCode = spi.ItemCode
	--		WHERE tbd.SipsItemCode IS NOT NULL
	--		GROUP BY tbd.SipsItemCode
	--			) f
	--	ON tbd.TransferBinNo = f.last_TransferBinNo
	--	AND tbd.SipsItemCode = f.SipsItemCode



	
/*******************
Pricing
*******************/

SELECT
	spc.ItemCode,
	spc.ModifiedTime [date_FirstPriceChange],
	spc.OldPrice,
	spc.NewPrice 
INTO #Pricing_OriginalPrice
FROM ReportsData..SipsPriceChanges spc
	INNER JOIN (
		SELECT 
			spc.ItemCode,
			MIN(spc.ModifiedTime) [first_ModifiedTime]
		FROM ReportsData..SipsPriceChanges spc
			INNER JOIN #SipsProductInventory spi
				ON spc.ItemCode = spi.ItemCode
		GROUP BY spc.ItemCode
				) f
			ON spc.ItemCode = f.ItemCode
			AND spc.ModifiedTime = f.first_ModifiedTime


SELECT 
	spi.ItemCode,
	ISNULL(tol.original_LocationNo, spi.LocationNo) [LocationNo],
	spi.DateInStock,
	po.date_FirstPriceChange,
	CASE 
		WHEN DATEDIFF(DAY, spi.DateInStock, po.date_FirstPriceChange) < 7
		THEN po.NewPrice
		ELSE po.OldPrice
		END [OriginalPrice], --Any price ajdustments made in the first week of an items life spans are counted as a correction rather than a markdown
	spi.Price [CurrentPrice],
	CASE WHEN t.listPrice > = 0.10 THEN t.listPrice ELSE NULL END [listPrice], --Some list prices are recorded as zero or around zero - making sure they're removed from consideration
	CASE 
		WHEN spi.Price = ROUND(spi.Price, 0)
		AND spi.Price <= 3.00
		THEN 1
		END [isClearance],
	CASE 
		WHEN DATEDIFF(DAY, spi.DateInStock, po.date_FirstPriceChange) > 30
		AND po.NewPrice < (0.75 * po.OldPrice)
		AND po.NewPrice <> ROUND(po.NewPrice, 0)
		THEN 1
		END [isMarkdown]
INTO #Pricing
FROM #SipsProductInventory spi
	INNER JOIN ReportsData.dbo.SipsProductMaster spm
		ON spi.SipsID = spm.SipsID
	LEFT OUTER JOIN #Transfers_OriginalLocations tol
		ON spi.ItemCode = tol.SipsItemCode
	LEFT OUTER JOIN #Pricing_OriginalPrice po
		ON spi.ItemCode = po.ItemCode
	LEFT OUTER JOIN Catalog..titles t
		ON spm.CatalogId = t.catalogId
WHERE spi.Price < 100000


DROP TABLE #Transfers_OriginalLocations
DROP TABLE #Pricing_OriginalPrice


/*
Shelf aging
*/
--Select all shelf scan records from current back through as much of the history as desired.
SELECT 
	CAST(sis.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sis.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sis.SkuExtension, 
	sis.ScannedOn,
	sis.ScannedBy,
	sis.ShelfScanID,
	sis.ShelfItemScanID,
	1 [isCurrent]
INTO #ItemScanHistory
FROM ReportsData..ShelfItemScan sis
WHERE sis.ScannedOn >= @StartDate
--WHERE sis.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION 
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM ReportsData..ShelfItemScanHistoryActive sish
WHERE sish.ScannedOn >= @StartDate
UNION 
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM ReportsData..ShelfItemScanHistory sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION 
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2019 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION 
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2018 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION 
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2017 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION 
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2016 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2015 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION 
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2014 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2013 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2012 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION 
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2011 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION 
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2010 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'
UNION 
SELECT 
	CAST(sish.ItemCodeSips AS BIGINT) [ItemCodeSips],
--	CAST(sish.ItemCodeDips AS BIGINT) [ItemCodeDips],
--	sish.SkuExtension, 
	sish.ScannedOn,
	sish.ScannedBy,
	sish.ShelfScanID,
	sish.ShelfItemScanID,
	0 [isCurrent]
FROM archShelfScan..ShelfItemScanHistory_2009 sish
WHERE sish.ScannedOn >= @StartDate
--WHERE sish.ItemCodeDips NOT LIKE '%[^0-9]%'

SELECT	
	ish.ItemCodeSips [ItemCode],
	--ISNULL(ish.ItemCodeSips, ish.ItemCodeDips) [ItemCode],
	--ish.SkuExtension,
	MIN(ish.ScannedOn) [first_ScannedOn],  
	MAX(ish.ScannedOn) [last_ScannedOn],
	MAX(ish.isCurrent) [isCurrent]
INTO #FirstLastScans
FROM #ItemScanHistory ish
WHERE ish.ItemCodeSips IS NOT NULL
GROUP BY
	ish.ItemCodeSips 

SELECT *
FROM #FirstLastScans fls
INNER JOIN ReportsData..ShelfScanHistory ssh
	ON fls.



SELECT 
	--Pricing
	kt.Store_StartOfWeek,
	p.LocationNo,
	p.ItemCode,
	p.DateInStock [pricing_Date],
	p.CurrentPrice [pricing_CurrentPrice],
	p.OriginalPrice [pricing_OriginalPrice],
	p.listPrice [pricing_ListPrice],
	p.isClearance [pricing_isClearance],
	p.isMarkdown [pricing_isMarkdown],
	--ShelfScan
	c.first_ScannedOn [scans_DateFirstScan],
	c.last_ScannedOn [scans_DateLastScan],
	--Transfer
	t.LocationNo [transfer_FromLocation],
	t.BusinessDate [transfer_Date],
	t.bool_ToBookSmarter [transfer_isBookSmarter],
	t.bool_ToDispose [transfer_isDisposal],
	t.bool_ToLocation [transfer_isLocation],
	--Sales
	s.LocationNo [sales_Location],
	s.BusinessDate [sales_Date],
	s.RegisterPrice [sales_Price],
	CASE 
		WHEN s.RegisterPrice = ROUND(s.RegisterPrice, 0)
		AND s.RegisterPrice <= 3.00
		THEN 1
		END [sales_isClearance],
	CASE 
		WHEN s.RegisterPrice < (0.6 * p.CurrentPrice)
		THEN 1
		END [sales_isMarkdown],
	--Aging
	CAST(DATEDIFF(ss, ISNULL(c.first_ScannedOn, p.DateInStock), CASE WHEN (t.bool_ToDispose = 1) AND (t.BusinessDate <= kt.Store_EndOfWeek) THEN t.BusinessDate ELSE kt.Store_EndOfWeek END) AS FLOAT) / 60 / 60 / 24 [DaysOnShelf]
INTO Sandbox..SipsHistoricalAging_test
FROM #Pricing p
	LEFT OUTER JOIN #Sales s
		ON p.ItemCode = s.SipsItemCode
	LEFT OUTER JOIN #Transfers t
		ON p.ItemCode = t.SipsItemCode
	LEFT OUTER JOIN #KeyTable kt
		ON p.DateInStock <= kt.Store_EndOfWeek
		AND p.LocationNo = kt.LocationNo
	LEFT OUTER JOIN #FirstLastScans c
		ON p.ItemCode = c.ItemCode
		AND DATEDIFF(MONTH, ISNULL(c.last_ScannedOn, p.DateInStock), kt.Store_EndOfWeek) <= 8
		

DROP TABLE #SipsProductInventory
DROP TABLE #Pricing
DROP TABLE #Sales
DROP TABLE #Transfers
DROP TABLE #ItemScanHistory
DROP TABLE #FirstLastScans
DROP TABLE #KeyTable


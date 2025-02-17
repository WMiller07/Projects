DECLARE @StartDate DATE = '7/1/2019'
DECLARE @EndDate DATE = '7/31/2019'
DECLARE @TestLocations TABLE (LocationNo CHAR(5))

INSERT INTO @TestLocations VALUES 
	('00019'),('00052'),('00129'),('00040'),('00080'),
	('00126'),('00123'),('00118'),('00056'),('00105'),
	('00083'),('00015'),('00011'),('00013'),('00069'),
	('00072'),('00037'),('00067'),('00048'),('00064'),
	('00071'),('00096'),('00124'),('00014'),('00073'), ('00130')


SELECT LocationNo
INTO #R3Locs
FROM Sandbox..LocBuyAlgorithms lba
WHERE lba.VersionNo = 'v1.r3'

--SELECT
--	DATEADD(DAY,DATEDIFF(DAY, 0, bbh.CreateTime), 0)		[BusinessDate],
--	bbh.LocationNo											[LocationNo],
--	COUNT(bbh.BuyBinNo)										[count_BuyTransactions],
--	SUM(bbh.TotalOffer)										[total_Offers],
--	SUM(bbh.TotalQuantity)									[total_Quantity]
--INTO #BuyHeaderMetrics
--FROM BUYS..BuyBinHeader bbh
--	INNER JOIN @TestLocations tl 
--		ON bbh.LocationNo = tl.LocationNo
--WHERE 
--	bbh.CreateTime >= @StartDate AND
--	bbh.CreateTime < DATEADD(DAY, 1, @EndDate) AND
--	bbh.StatusCode = 1 
--GROUP BY 
--	DATEADD(DAY,DATEDIFF(DAY, 0, bbh.CreateTime), 0),
--	bbh.LocationNo


--Get most recently generated buy offers for all R4 offers, first for location offers, then chain offers
SELECT 
	ba.CatalogID,
	ba.LocationNo,
	ba.Location_SuggestedOffer
INTO #R4LastLocOffers 
FROM Sandbox..BuyAlgorithm_V1_R4 ba
	INNER JOIN (
		SELECT 
			CatalogID,
			LocationNo,
			MAX(Date_Generated) [Date_Generated]
		FROM Sandbox..BuyAlgorithm_V1_R4
		GROUP BY CatalogID, LocationNo) rl
			ON ba.CatalogID = rl.CatalogID
			AND ba.Date_Generated = rl.Date_Generated
			AND ba.LocationNo = rl.LocationNo

SELECT 
	ba.CatalogID,
	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer]
INTO #R4LastChainOffers 
FROM Sandbox..BuyAlgorithm_V1_R4 ba
	INNER JOIN (
		SELECT 
			CatalogID,
			MAX(Date_Generated) [Date_Generated]
		FROM Sandbox..BuyAlgorithm_V1_R4
		GROUP BY CatalogID) rl
			ON ba.CatalogID = rl.CatalogID
			AND ba.Date_Generated = rl.Date_Generated
GROUP BY ba.CatalogID


SELECT 
	CASE 
		WHEN r3l.LocationNo IS NOT NULL
			THEN 'Jun19 Release'
		WHEN tl.LocationNo IS NOT NULL
			THEN 'Oct19 Release'
		ELSE 'Unched Release'
		END		[LocationGroup],
	bbi.LocationNo,
	bbi.BuyBinNo,
	bt.BuyType,
	bbi.Offer,
	bbi.Quantity,
	bbi.Offer/bbi.Quantity [ItemOffer],
	spm.CatalogId,
	ISNULL(llo.Location_SuggestedOffer, lco.Chain_SuggestedOffer) [SuggestedOffer],
	CASE 
		WHEN llo.Location_SuggestedOffer IS NOT NULL
			THEN 2
		WHEN lco.Chain_SuggestedOffer IS NOT NULL
			THEN 1
		ELSE 0
	END [OfferType]
INTO #R4Offers
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.LocationNo = bbi.LocationNo 
		AND bbh.BuyBinNo = bbi.BuyBinNo
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON bbh.LocationNo = slm.LocationNo
		AND slm.StoreType = 'S'
		AND slm.OpenDate <= DATEADD(YEAR, -1, @StartDate)
	LEFT OUTER JOIN @TestLocations tl 
		ON bbh.LocationNo = tl.LocationNo
	LEFT OUTER JOIN #R3Locs r3l
		ON bbh.LocationNo = r3l.LocationNo
	INNER JOIN BUYS..BuyTypes bt
		ON bbi.BuyTypeID = bt.BuyTypeID
	LEFT OUTER JOIN ReportsData..SipsProductMaster spm
		ON bbi.SipsID = spm.SipsID
	LEFT OUTER JOIN #R4LastChainOffers lco
		ON spm.CatalogId = lco.CatalogID
	LEFT OUTER JOIN #R4LastLocOffers llo
		ON bbi.LocationNo = llo.LocationNo
		AND spm.CatalogId = llo.CatalogID 
WHERE 
	bbh.CreateTime >= @StartDate AND
	bbh.CreateTime < DATEADD(DAY, 1, @EndDate) AND
	bbh.StatusCode = 1  AND
	bbi.StatusCode = 1 AND 
	bbi.Offer < 100000 AND
	bbi.Quantity > 0 
ORDER BY LocationNo, BuyBinNo

SELECT
	CASE 
		WHEN GROUPING(r4o.LocationGroup) = 1
			THEN 'All Locations'
		ELSE r4o.LocationGroup
		END [LocationGroup],
	CASE 
		WHEN GROUPING(r4o.LocationNo) = 1
			THEN 'All Locations'
		ELSE r4o.LocationNo
		END [LocationNo],
	CASE 
		WHEN GROUPING(r4o.BuyType) = 1
			THEN 'All BuyTypes'
		ELSE r4o.BuyType
		END [BuyType], 
	SUM(r4o.Quantity) [Quantity],
	SUM(r4o.Offer) [Actual_Cost],
	SUM(CASE 
		WHEN r4o.SuggestedOffer IS NULL
		THEN r4o.Offer
		ELSE r4o.SuggestedOffer
		END) [Projected_Cost],
	SUM(CASE 
		WHEN r4o.SuggestedOffer IS NULL
		THEN r4o.Offer
		ELSE r4o.SuggestedOffer
		END) - SUM(r4o.Offer) [Change_Cost],
	SUM(r4o.Offer)/SUM(r4o.Quantity) [avg_ItemOffer],
	SUM(CASE 
		WHEN r4o.SuggestedOffer IS NULL
		THEN r4o.Offer
		ELSE r4o.SuggestedOffer
		END) /
		SUM(r4o.Quantity) [avg_ItemOfferIncR4],
	SUM(CASE
		WHEN r4o.CatalogID IS NOT NULL
		THEN r4o.Offer
		END) /
		SUM(CASE
			WHEN r4o.CatalogID IS NOT NULL
			THEN r4o.Quantity
			END) [avg_ScannedItemOffer],
	SUM(CASE
		WHEN r4o.SuggestedOffer IS NOT NULL
		THEN r4o.SuggestedOffer
		END) /
		SUM(CASE
			WHEN r4o.SuggestedOffer IS NOT NULL
			THEN r4o.Quantity
			END) [avg_ScannedSuggestedOffer],
	CAST(COUNT(r4o.CatalogID) AS FLOAT)/CAST(COUNT(r4o.BuyType) AS FLOAT) [pct_QtyScanned],
	CAST(COUNT(r4o.SuggestedOffer) AS FLOAT)/CAST(COUNT(r4o.BuyType) AS FLOAT) [pct_QtySuggested]
FROM #R4Offers r4o
--WHERE BuyType IN ('UN', 'PB', 'DVD', 'CDU')
GROUP BY CUBE(LocationGroup, LocationNo, BuyType)
HAVING ((GROUPING(r4o.LocationGroup) <> 1) OR (GROUPING(r4o.LocationNo) = 1))
ORDER BY LocationGroup, LocationNo, BuyType

DROP TABLE #R3Locs
DROP TABLE #R4LastChainOffers
DROP TABLE #R4LastLocOffers
DROP TABLE #R4Offers
DECLARE @StartDate DATE = '8/1/2017'
DECLARE @EndDate DATE = '8/21/2019'
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
	ba.Location_SuggestedOffer,
	ba.Date_Generated,
	ba.ListPrice
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
	MIN(ba.ListPrice) [ListPrice],
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
	DATEADD(MONTH, DATEDIFF(MONTH, 0, bbi.CreateTime), 0) [BusinessMonth],
	CASE 
		WHEN r3l.LocationNo IS NOT NULL
			THEN 'Jun19 release stores'
		WHEN tl.LocationNo IS NOT NULL
			THEN 'Oct19 release stores'
		ELSE 'Unsched release stores'
		END		[LocationGroup],
	bbi.BuyBinNo,
	bt.BuyType,
	bbi.Offer,
	bbi.Quantity,
	bbi.Offer/bbi.Quantity [ItemOffer],
	spm.CatalogId,
	ISNULL(llo.Location_SuggestedOffer, lco.Chain_SuggestedOffer) [R4SuggestedOffer],
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
	bbi.Quantity > 0 AND
	bt.BuyType IN ('UN', 'PB', 'DVD', 'CDU')


SELECT
	BusinessMonth,
	CASE
		WHEN GROUPING(r4o.LocationGroup) = 1
		THEN 'Chain'
		ELSE r4o.LocationGroup
		END [LocationGroup],
	SUM(r4o.Quantity) [Quantity],
	SUM(r4o.Offer)/SUM(r4o.Quantity) [avg_ItemOffer],
	SUM(CASE 
		WHEN r4o.R4SuggestedOffer IS NULL
		THEN r4o.Offer
		ELSE r4o.R4SuggestedOffer
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
		WHEN r4o.R4SuggestedOffer IS NOT NULL
		THEN r4o.R4SuggestedOffer
		END) /
		SUM(CASE
			WHEN r4o.R4SuggestedOffer IS NOT NULL
			THEN r4o.Quantity
			END) [avg_ScannedSuggestedOffer],
	CAST(COUNT(r4o.CatalogID) AS FLOAT)/CAST(COUNT(r4o.BuyType) AS FLOAT) [pct_QtyScanned],
	CAST(COUNT(r4o.R4SuggestedOffer) AS FLOAT)/CAST(COUNT(r4o.BuyType) AS FLOAT) [pct_QtySuggested]
FROM #R4Offers r4o
GROUP BY BusinessMonth, LocationGroup WITH CUBE
ORDER BY LocationGroup, BusinessMonth

DROP TABLE #R3Locs
DROP TABLE #R4LastChainOffers
DROP TABLE #R4LastLocOffers
DROP TABLE #R4Offers
DECLARE @StartDate DATE = '9/1/2019'
DECLARE @EndDate DATE = '10/1/2019'
DECLARE @LastR4GenDate DATE
DECLARE @LastR41GenDate DATE

--1 - Item Create Date
--2 - Shelf Scan Record Historical Record
--3 - Shelf Scan Current Record
--4 - Transfer
--5 – Sale

SELECT 
	spi.LocationNo,
	t.isbn10,
	t.isbn13,
	t.title,
	t.author,
	lc.CatalogID,
	lc.ItemCode [ItemCodeSips],
	lc.First_RecordDate [DateInStock],
	CASE
		WHEN lc.LifeCycle_Complete = 0
		AND lc.LastEventType IN (2,3)
		THEN lc.First_ScanDate
		END [current_FirstScan],
	CASE
		WHEN lc.LifeCycle_Complete = 1
		AND lc.LastEventType = 5
		THEN lc.First_ScanDate
		END [historic_FirstScan],
	CASE
		WHEN lc.LifeCycle_Complete = 1
		AND lc.LastEventType = 4
		THEN lc.Last_RecordDate
		END [historic_TrashDate],
	lc.Sale_Price [RegisterPrice],
	lc.Last_SaleDate [SaleDate]
INTO #ScannedItems
FROM Buy_Analytics..ItemCode_LifeCycle lc
	INNER JOIN ReportsData..SipsProductInventory spi
		ON lc.ItemCode = spi.ItemCode
	INNER JOIN Catalog..titles t
		ON lc.CatalogID = t.catalogId
WHERE lc.First_RecordDate > '1/1/2019'


SELECT 
	si.LocationNo,
	si.CatalogId,
	si.ISBN13,
	si.title,
	si.author,
	COUNT(si.current_FirstScan) [qty_OnHand]
INTO #CurrentMultiples
FROM #ScannedItems si
GROUP BY si.LocationNo, si.CatalogId, si.ISBN13, si.title, si.author
--HAVING COUNT(si.current_FirstScan) = 1

SELECT 
	@LastR4GenDate = MAX(ba4.Date_Generated)
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba4

SELECT 
	@LastR41GenDate = MAX(ba41.Date_Generated)
FROM Buy_Analytics..BuyAlgorithm_V1_R41 ba41

SELECT 
	ba4.CatalogID,
	MIN(ba4.Chain_SuggestedOffer) [Chain_SuggestedOffer],
	MIN(ba4.Chain_Buy_Offer_Pct) [Chain_SuggestedOfferPct]
INTO #ba4ChainOffers
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba4
WHERE ba4.Date_Generated = @LastR4GenDate
GROUP BY ba4.CatalogID

SELECT 
	ba41.CatalogID,
	MIN(ba41.Chain_SuggestedOffer) [Chain_SuggestedOffer],
	MIN(ba41.Chain_Buy_Offer_Pct) [Chain_SuggestedOfferPct]
INTO #ba41ChainOffers
FROM Buy_Analytics..BuyAlgorithm_V1_R41 ba41
WHERE ba41.Date_Generated = @LastR41GenDate
GROUP BY ba41.CatalogID


SELECT DISTINCT
	bbh.CreateTime,
	bbh.LocationNo,
	bbi.ItemLineNo,
	bbi.CatalogID,
	bbi.SuggestedOffer,
	bbi.Quantity,
	ISNULL(lba4.Location_SuggestedOffer, cba4.Chain_SuggestedOffer) [r4_SuggestedOffer],
	ISNULL(lba4.Location_Buy_Offer_Pct, cba4.Chain_SuggestedOfferPct) [r4_SuggestedOfferPct],
	ISNULL(lba41.Location_SuggestedOffer, cba41.Chain_SuggestedOffer) [r41_SuggestedOffer],
	ISNULL(lba41.Location_Buy_Offer_Pct, cba41.Chain_SuggestedOfferPct) [r41_SuggestedOfferPct]
INTO #ChangedOffers
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON bbh.LocationNo = lba.LocationNo
		AND lba.VersionNo = 'v1.r4'
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_V1_R4 lba4
		ON bbi.CatalogID = lba4.CatalogID
		AND lba4.Date_Generated = @LastR4GenDate
		AND bbi.LocationNo = lba4.LocationNo
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_V1_R41 lba41
		ON bbi.CatalogID = lba41.CatalogID
		AND lba41.Date_Generated = @LastR41GenDate
		AND bbi.LocationNo = lba41.LocationNo
	LEFT OUTER JOIN #ba4ChainOffers cba4
		ON bbi.CatalogID = cba4.CatalogID
	LEFT OUTER JOIN #ba41ChainOffers cba41
		ON bbi.CatalogID = cba41.CatalogID
WHERE bbi.Scoring_ID IS NOT NULL
	AND bbh.CreateTime > @StartDate
	AND bbh.CreateTime < @EndDate
	AND bbh.StatusCode = 1
	AND bbi.StatusCode = 1
	AND bbi.Quantity > 0
ORDER BY bbh.LocationNo, bbh.CreateTime

SELECT 
	co.LocationNo,
	SUM(co.SuggestedOffer) [total_ActualSuggestedOffer],
	SUM(co.SuggestedOffer)/SUM(co.Quantity) [avg_ActualSuggestedOffer],
	SUM(r4_SuggestedOffer) [total_R4SuggestedOffers],
	SUM(r4_SuggestedOffer)/SUM(co.Quantity) [avg_R4SuggstedOffer],
	SUM(r41_SuggestedOffer) [total_R41SuggestedOffers],
	SUM(r41_SuggestedOffer)/SUM(co.Quantity) [avg_R41SuggstedOffer]
FROM #ChangedOffers co
GROUP BY LocationNo WITH ROLLUP
ORDER BY LocationNo



DROP TABLE #ba4ChainOffers
DROP TABLE #ba41ChainOffers
DROP TABLE #ScannedItems
DROP TABLE #CurrentMultiples
DROP TABLE #ChangedOffers
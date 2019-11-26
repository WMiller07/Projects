DECLARE @StartDate DATE = '10/1/2019'
DECLARE @EndDate DATE = '11/1/2019'
DECLARE @LastR4GenDate DATE
DECLARE @LastR41GenDate DATE


SELECT 
	LocationNo,
	CatalogID,
	MAX(ba4.Date_Generated) [LastR40GenDate]
INTO #LastR40Gen
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba4
GROUP BY CatalogID, LocationNo

SELECT 
	LocationNo,
	CatalogID,
	MAX(ba41.Date_Generated) [LastR41GenDate]
INTO #LastR41Gen
FROM Buy_Analytics..BuyAlgorithm_V1_R41 ba41
GROUP BY CatalogID, LocationNo

SELECT 
	ba4.CatalogID,
	MIN(ba4.Chain_SuggestedOffer) [Chain_SuggestedOffer],
	MIN(ba4.Chain_Buy_Offer_Pct) [Chain_SuggestedOfferPct]
INTO #ba4ChainOffers
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba4
	INNER JOIN #LastR40Gen lag
		ON ba4.CatalogID = lag.CatalogID
		AND ba4.Date_Generated = lag.LastR40GenDate
GROUP BY ba4.CatalogID

SELECT 
	ba4.CatalogID,
	ba4.LocationNo,
	MIN(ba4.Location_SuggestedOffer) [Location_SuggestedOffer],
	MIN(ba4.Location_Buy_Offer_Pct) [Location_SuggestedOfferPct]
INTO #ba4LocOffers
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba4
	INNER JOIN #LastR40Gen lag
		ON ba4.CatalogID = lag.CatalogID
		AND ba4.LocationNo = lag.LocationNo
		AND ba4.Date_Generated = lag.LastR40GenDate
GROUP BY ba4.CatalogID, ba4.LocationNo

SELECT 
	ba41.CatalogID,
	MIN(ba41.Chain_SuggestedOffer) [Chain_SuggestedOffer],
	MIN(ba41.Chain_Buy_Offer_Pct) [Chain_SuggestedOfferPct]
INTO #ba41ChainOffers
FROM Buy_Analytics..BuyAlgorithm_V1_R41 ba41
	INNER JOIN #LastR41Gen lag
		ON ba41.CatalogID = lag.CatalogID
		AND ba41.Date_Generated = lag.LastR41GenDate
WHERE ba41.Date_Generated = @LastR41GenDate
GROUP BY ba41.CatalogID


SELECT 
	ba41.CatalogID,
	ba41.LocationNo,
	MIN(ba41.Location_SuggestedOffer) [Location_SuggestedOffer],
	MIN(ba41.Location_Buy_Offer_Pct) [Location_SuggestedOfferPct]
INTO #ba41LocOffers
FROM Buy_Analytics..BuyAlgorithm_V1_R41 ba41
	INNER JOIN #LastR41Gen lag
		ON ba41.CatalogID = lag.CatalogID
		AND ba41.LocationNo = lag.LocationNo
		AND ba41.Date_Generated = lag.LastR41GenDate
GROUP BY ba41.CatalogID, ba41.LocationNo


SELECT DISTINCT
	bbh.CreateTime,
	bbh.LocationNo,
	bbi.ItemLineNo,
	bbi.CatalogID,
	CASE 
		WHEN t.binding IN ('Mass Market Paperback', 'Audio CD', 'CD') 
		THEN t.binding 
		ELSE 'General' 
		END [CatatlogBinding],
	bbi.SuggestedOffer,
	bbi.Quantity,
	ISNULL(lba4.Location_SuggestedOffer, cba4.Chain_SuggestedOffer) [r40_SuggestedOffer],
	ISNULL(lba4.Location_SuggestedOfferPct, cba4.Chain_SuggestedOfferPct) [r40_SuggestedOfferPct],
	ISNULL(lba41.Location_SuggestedOffer, cba41.Chain_SuggestedOffer) [r41_SuggestedOffer],
	ISNULL(lba41.Location_SuggestedOfferPct, cba41.Chain_SuggestedOfferPct) [r41_SuggestedOfferPct],
	ISNULL(lbt42.BuyOfferPct * adl.Avg_Sale_Price, cbt42.BuyOfferPct * adc.Avg_Sale_Price) [r42_SuggestedOffer],
	ISNULL(lbt42.BuyOfferPct, cbt42.BuyOfferPct) [r42_SuggestedOfferPct]
INTO #SO_Comp
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON bbh.LocationNo = lba.LocationNo
		AND lba.VersionNo = 'v1.r4'
	INNER JOIN Catalog..titles t
		ON bbi.CatalogID = t.catalogId
	LEFT OUTER JOIN #ba4LocOffers lba4
		ON bbi.CatalogID = lba4.CatalogID
		AND bbi.LocationNo = lba4.LocationNo
	LEFT OUTER JOIN #ba41LocOffers lba41
		ON bbi.CatalogID = lba41.CatalogID
		AND bbi.LocationNo = lba41.LocationNo
	LEFT OUTER JOIN #ba4ChainOffers cba4
		ON bbi.CatalogID = cba4.CatalogID
	LEFT OUTER JOIN #ba41ChainOffers cba41
		ON bbi.CatalogID = cba41.CatalogID
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Chain adc
		ON bbi.CatalogID = adc.CatalogID
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Location adl
		ON bbi.LocationNo = adl.LocationNo
		AND bbi.CatalogID = adl.CatalogID
	LEFT OUTER JOIN Buy_Analytics_Cashew..AccumulatedDaysOnShelf_BuyTable_V1_R42 lbt42
		ON	(adl.Total_Accumulated_Days_With_Trash_Penalty / (adl.Total_Sold + 1)) > lbt42.AccDaysRangeFrom
		AND (adl.Total_Accumulated_Days_With_Trash_Penalty / (adl.Total_Sold + 1)) <= lbt42.AccDaysRangeTo
		AND (CASE 
				WHEN t.binding IN ('Mass Market Paperback', 'Audio CD', 'CD') 
				THEN t.binding 
				ELSE 'General' 
				END) = lbt42.CatalogBinding
	LEFT OUTER JOIN Buy_Analytics_Cashew..AccumulatedDaysOnShelf_BuyTable_V1_R42 cbt42
		ON	(adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) > cbt42.AccDaysRangeFrom
		AND (adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) <= cbt42.AccDaysRangeTo
		AND (CASE 
				WHEN t.binding IN ('Mass Market Paperback', 'Audio CD', 'CD') 
				THEN t.binding 
				ELSE 'General' 
				END) = cbt42.CatalogBinding
WHERE bbi.Scoring_ID IS NOT NULL
	AND bbh.CreateTime > @StartDate
	AND bbh.CreateTime < @EndDate
	AND bbh.StatusCode = 1
	AND bbi.StatusCode = 1
	AND bbi.Quantity > 0
ORDER BY bbh.LocationNo, bbh.CreateTime

SELECT * 
FROM #SO_Comp
ORDER BY r42_SuggestedOfferPct, r42_SuggestedOffer DESC

SELECT 
	co.LocationNo,
	SUM(co.SuggestedOffer)/SUM(co.Quantity) [avg_ActualSuggestedOffer],
	SUM(r40_SuggestedOffer)/SUM(co.Quantity) [avg_R40LatestSuggestedOffer],
	SUM(r41_SuggestedOffer)/SUM(co.Quantity) [avg_R41SuggestedOffer],
	SUM(r42_SuggestedOffer)/SUM(co.Quantity) [avg_R42SuggestedOffer],
	SUM(co.SuggestedOffer) [total_ActualSuggestedOffer],
	SUM(r40_SuggestedOffer) [total_R40SuggestedOffers],
	SUM(r41_SuggestedOffer) [total_R41SuggestedOffers],
	SUM(r42_SuggestedOffer) [total_R42SuggestedOffers]
FROM #SO_comp co
GROUP BY LocationNo WITH ROLLUP
ORDER BY LocationNo

--SELECT 
--	bt.BuyOfferPct,
--	bt.CatalogBinding,
--	SUM(c40.Quantity) [qty_R40],
--	SUM(c41.Quantity) [qty_R41],
--	SUM(c42.Quantity) [qty_R42],
--	SUM(c40.r40_SuggestedOffer) [offer_R40],
--	SUM(c41.r41_SuggestedOffer) [offer_R41],
--	SUM(c42.r42_SuggestedOffer) [offer_R42]
--FROM Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt
--	LEFT OUTER JOIN #SO_Comp c40
--		ON bt.BuyOfferPct = c40.r40_SuggestedOfferPct
--		AND bt.CatalogBinding = c40.CatatlogBinding
--	LEFT OUTER JOIN #SO_Comp c41
--		ON bt.BuyOfferPct = c41.r41_SuggestedOfferPct
--		AND bt.CatalogBinding = c41.CatatlogBinding
--	LEFT OUTER JOIN #SO_Comp c42
--		ON bt.BuyOfferPct = c42.r42_SuggestedOfferPct
--		AND bt.CatalogBinding = c42.CatatlogBinding
--GROUP BY bt.BuyOfferPct, bt.CatalogBinding
--ORDER BY bt.BuyOfferPct, bt.CatalogBinding

DROP TABLE #ba4ChainOffers
DROP TABLE #ba41ChainOffers
DROP TABLE #SO_Comp
DECLARE @StartDate DATE = '10/1/2019'
DECLARE @EndDate DATE = '11/1/2019'


SELECT 
	ba.CatalogID,
	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer]
INTO #ChainSuggestedOffers
FROM Buy_Analytics_Cashew..BuyAlgorithm_V1_R42 ba
INNER JOIN 
	(
	SELECT 
		ba.CatalogID,
		MAX(ba.Date_Generated) [Date_Generated]
	FROM Buy_Analytics_Cashew..BuyAlgorithm_V1_R42 ba
	GROUP BY ba.CatalogID
	) bam
		ON ba.CatalogID = bam.CatalogID
		AND ba.Date_Generated = bam.Date_Generated
GROUP BY ba.CatalogID

SELECT 
	ba.CatalogID,
	ba.LocationNo,
	ba.Location_SuggestedOffer
INTO #LocSuggestedOffers
FROM Buy_Analytics_Cashew..BuyAlgorithm_V1_R42 ba
INNER JOIN 
	(
	SELECT 
		ba.CatalogID,
		ba.LocationNo,
		MAX(ba.Date_Generated) [Date_Generated]
	FROM Buy_Analytics_Cashew..BuyAlgorithm_V1_R42 ba
	WHERE ba.LocationNo IS NOT NULL
	GROUP BY ba.CatalogID, ba.LocationNo
	) bam
		ON ba.CatalogID = bam.CatalogID
		AND ba.LocationNo = bam.LocationNo
		AND ba.Date_Generated = bam.Date_Generated
ORDER By CatalogID, LocationNo

--SELECT 
--	bbi.LocationNo,
--	bbi.BuyBinNo,
--	bbi.ItemLineNo,
--	spm.CatalogID,
--	t.title,
--	cso.Chain_SuggestedOffer,
--	bbi.Offer,
--	bbi.Quantity
----INTO #OfferComparison
--FROM BUYS..BuyBinItems bbi
--	INNER JOIN ReportsData..SipsProductMaster spm
--		ON bbi.SipsID = spm.SipsID
--	INNER JOIN Catalog..titles t
--		ON spm.CatalogId = t.catalogId
--	LEFT OUTER JOIN #ChainSuggestedOffers cso
--		ON spm.CatalogID = cso.CatalogID
--	--LEFT OUTER JOIN #LocSuggestedOffers lso
--	--	ON spm.CatalogID = lso.CatalogID
--	--	AND bbi.LocationNo = lso.LocationNo
--WHERE 
--	spm.CatalogID IS NOT NULL
--	AND bbi.CreateTime >= @StartDate
--	AND bbi.CreateTime < @EndDate
--	AND bbi.StatusCode = 1
--	AND bbi.Quantity > 0
--	AND bbi.Offer < 10000
--	AND bbi.Scoring_ID IS NULL
--	AND bbi.SearchResultSourceID IS NOT NULL
--ORDER BY LocationNo, BuyBinNo, ItemLineNo

SELECT 
	spm.CatalogID,
	t.title,
	SUM(bbi.Quantity) [count_BuyItems],
	COUNT(cso.CatalogID) [count_SuggestedOfferItems],
	AVG(btc.BuyOfferPct * adc.Avg_Sale_Price) [chain_suggestedOffer],
	AVG(btl.BuyOfferPct * adl.Avg_Sale_Price) [avg_LocSuggestedOffer],
	STDEVP(btl.BuyOfferPct * adl.Avg_Sale_Price) [dev_LocSuggestedOffer],
	MIN(btl.BuyOfferPct * adl.Avg_Sale_Price) [min_LocOffer],
	MAX(btl.BuyOfferPct * adl.Avg_Sale_Price) [max_LocOffer],
	SUM(bbi.Offer) / NULLIF(SUM(bbi.Quantity), 0) [avg_ItemOffer],
	STDEVP(bbi.Offer/ NULLIF(bbi.Quantity, 0)) [dev_ItemOffer],
	MIN(bbi.Offer/ NULLIF(bbi.Quantity, 0)) [min_ItemOffer],
	MAX(bbi.Offer/ NULLIF(bbi.Quantity, 0)) [max_ItemOffer],
	--SUM(ISNULL(cso.Chain_SuggestedOffer, bbi.Offer) * bbi.Quantity)  [total_ChainSuggestedOfferAmt],
	SUM(ISNULL(btc.BuyOfferPct * adc.Avg_Sale_Price, bbi.Offer) * bbi.Quantity)  [total_ChainSuggestedOfferAmt],
	--SUM(COALESCE(lso.Location_SuggestedOffer, cso.Chain_SuggestedOffer, bbi.Offer) * bbi.Quantity) [total_LocSuggestedOfferAmt],
	SUM(COALESCE(btl.BuyOfferPct * adl.Avg_Sale_Price, btc.BuyOfferPct * adc.Avg_Sale_Price, bbi.Offer) * bbi.Quantity) [total_LocSuggestedOfferAmt],
	SUM(bbi.Offer * bbi.Quantity) 	[total_ActualOffers]
INTO #OfferComparison
FROM BUYS..BuyBinItems bbi
	INNER JOIN ReportsData..SipsProductMaster spm
		ON bbi.SipsID = spm.SipsID
	INNER JOIN Catalog..titles t
		ON spm.CatalogId = t.catalogId
	LEFT OUTER JOIN #ChainSuggestedOffers cso
		ON spm.CatalogID = cso.CatalogID
	LEFT OUTER JOIN #LocSuggestedOffers lso
		ON spm.CatalogID = lso.CatalogID
		AND bbi.LocationNo = lso.LocationNo
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Chain adc
		ON spm.CatalogId = adc.CatalogID
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Location adl
		ON spm.CatalogId = adl.CatalogID
		AND bbi.LocationNo = adl.LocationNo
	LEFT OUTER JOIN Buy_Analytics_Cashew..AccumulatedDaysOnShelf_BuyTable_V1_R42 btc
		ON (adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) > btc.AccDaysRangeFrom
		AND (adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) <= btc.AccDaysRangeTo
		AND (CASE WHEN t.binding IN ('Mass Market Paperback', 'Audio CD', 'CD') then t.binding else 'General' end) = btc.CatalogBinding
	LEFT OUTER JOIN Buy_Analytics_Cashew..AccumulatedDaysOnShelf_BuyTable_V1_R42 btl
		ON (adl.Total_Accumulated_Days_With_Trash_Penalty / (adl.Total_Sold + 1)) > btl.AccDaysRangeFrom
		AND (adl.Total_Accumulated_Days_With_Trash_Penalty / (adl.Total_Sold + 1)) <= btl.AccDaysRangeTo
		AND (CASE WHEN t.binding IN ('Mass Market Paperback', 'Audio CD', 'CD') then t.binding else 'General' end) = btl.CatalogBinding
WHERE 
	spm.CatalogID IS NOT NULL
	AND bbi.CreateTime >= @StartDate
	AND bbi.CreateTime < @EndDate
	AND bbi.StatusCode = 1
	AND bbi.Quantity > 0
	AND bbi.Offer < 10000
	AND bbi.Scoring_ID IS NULL
	AND bbi.SearchResultSourceID IS NOT NULL
GROUP BY spm.CatalogID, t.title

SELECT * 
FROM #OfferComparison
ORDER BY count_BuyItems DESC

SELECT
	SUM(total_ChainSuggestedOfferAmt) [total_ChainSuggestedOffers],
	SUM(total_LocSuggestedOfferAmt) [total_LocSuggestedOffers],
	SUM(total_ActualOffers)	[total_ActualOffers],
	COUNT(total_ChainSuggestedOfferAmt) [total_ChainSuggestedOffers],
	COUNT(total_LocSuggestedOfferAmt) [total_LocSuggestedOffers],
	COUNT(total_ActualOffers)	[total_ActualOffers]
FROM #OfferComparison oc
WHERE oc.Chain_SuggestedOffer IS NOT NULL


DROP TABLE #OfferComparison
DROP TABLE #ChainSuggestedOffers
DROP TABLE #LocSuggestedOffers

--DROP TABLE #LocSuggestedOffers
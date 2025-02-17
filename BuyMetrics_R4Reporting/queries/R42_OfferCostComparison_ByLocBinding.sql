 DECLARE @StartDate DATE = '9/1/2019'
 DECLARE @EndDate DATE = '10/1/2019'
-- DECLARE @LastAlgorithmUpdate DATE


--SELECT 
--	@LastAlgorithmUpdate = MAX(Date_Generated) 
--FROM Buy_Analytics..BuyAlgorithm_V1_R4
--GROUP BY CatalogID


----Get most recently generated buy offers for all R4 offers, first for location offers, then chain offers
--SELECT 
--	ba.CatalogID,
--	ba.LocationNo,
--	ba.Location_SuggestedOffer,
--	ba.Location_Buy_Offer_Pct,
--	ba.Date_Generated,
--	ba.ListPrice
--INTO #R40LastLocOffers 
--FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
--WHERE ba.Date_Generated = @LastAlgorithmUpdate


--SELECT 
--	ba.CatalogID,
--	ba.Date_Generated,
--	MIN(ba.Chain_Buy_Offer_Pct) [Chain_BuyOfferPct],
--	MIN(ba.ListPrice) [ListPrice],
--	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer]
--INTO #R40LastChainOffers 
--FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
--WHERE ba.Date_Generated = @LastAlgorithmUpdate
--GROUP BY ba.CatalogID, ba.Date_Generated


--SELECT 
--	ba.CatalogID,
--	ba.LocationNo,
--	ba.Location_SuggestedOffer,
--	ba.Location_Buy_Offer_Pct,
--	ba.Date_Generated,
--	ba.ListPrice
--INTO #R41LastLocOffers 
--FROM Buy_Analytics..BuyAlgorithm_V1_R41 ba
--WHERE ba.Date_Generated = @LastAlgorithmUpdate


--SELECT 
--	ba.CatalogID,
--	ba.Date_Generated,
--	MIN(ba.Chain_Buy_Offer_Pct) [Chain_BuyOfferPct],
--	MIN(ba.ListPrice) [ListPrice],
--	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer]
--INTO #R41LastChainOffers 
--FROM Buy_Analytics..BuyAlgorithm_V1_R41 ba
--WHERE ba.Date_Generated = @LastAlgorithmUpdate
--GROUP BY ba.CatalogID, ba.Date_Generated

 
SELECT 
	bbi.LocationNo,
	bbi.CatalogID,
	CASE 
		WHEN t.binding IN ('Mass Market Paperback', 'Audio CD', 'CD') 
		THEN t.binding 
		ELSE 'General' 
		END [CatalogBinding],
	bbi.Quantity,
	lbt40.BuyOfferPct [loc_BuyOfferPct_R40],
	lbt42.BuyOfferPct [loc_BuyOfferPct_R42],
	ISNULL(adl.Avg_Sale_Price, adl.Avg_Price) * lbt40.BuyOfferPct [loc_SuggestedOffer_R40],
	ISNULL(adl.Avg_Sale_Price, adl.Avg_Price) * lbt42.BuyOfferPct [loc_SuggestedOffer_R42],
	cbt40.BuyOfferPct [chain_BuyOfferPct_R40],
	cbt42.BuyOfferPct [chain_BuyOfferPct_R42],
	ISNULL(adc.Avg_Sale_Price, adc.Avg_Price) * cbt40.BuyOfferPct [chain_SuggestedOffer_R40],
	ISNULL(adc.Avg_Sale_Price, adc.Avg_Price) * cbt42.BuyOfferPct [chain_SuggestedOffer_R42]
INTO #LocSuggestedOffers 	
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON bbh.LocationNo = lba.LocationNo
		AND lba.VersionNo = 'V1.R4'
	INNER JOIN Catalog..titles t
		ON bbi.CatalogID = t.catalogId
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Chain adc
		ON bbi.CatalogID = adc.CatalogID
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Location adl
		ON bbi.LocationNo = adl.LocationNo
		AND bbi.CatalogID = adl.CatalogID
	LEFT OUTER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 lbt40
		ON (adl.Total_Accumulated_Days_With_Trash_Penalty / adl.Total_Item_Count) > lbt40.AccDaysRangeFrom
		AND (adl.Total_Accumulated_Days_With_Trash_Penalty / adl.Total_Item_Count) <= lbt40.AccDaysRangeTo
		AND (CASE 
				WHEN t.binding IN ('Mass Market Paperback', 'Audio CD', 'CD') 
				THEN t.binding 
				ELSE 'General' 
				END) = lbt40.CatalogBinding
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 lbt42
		ON	(adl.Total_Accumulated_Days_With_Trash_Penalty / (adl.Total_Sold + 1)) > lbt42.AccDaysRangeFrom
		AND (adl.Total_Accumulated_Days_With_Trash_Penalty / (adl.Total_Sold + 1)) <= lbt42.AccDaysRangeTo
		AND (CASE 
				WHEN t.binding IN ('Mass Market Paperback', 'Audio CD', 'CD') 
				THEN t.binding 
				ELSE 'General' 
				END) = lbt42.CatalogBinding
	LEFT OUTER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 cbt40
		ON	(adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count) > cbt40.AccDaysRangeFrom
		AND (adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count) <= cbt40.AccDaysRangeTo
		AND (CASE 
				WHEN t.binding IN ('Mass Market Paperback', 'Audio CD', 'CD') 
				THEN t.binding 
				ELSE 'General' 
				END) = cbt40.CatalogBinding
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 cbt42
		ON	(adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) > cbt42.AccDaysRangeFrom
		AND (adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) <= cbt42.AccDaysRangeTo
		AND (CASE 
				WHEN t.binding IN ('Mass Market Paperback', 'Audio CD', 'CD') 
				THEN t.binding 
				ELSE 'General' 
				END) = cbt42.CatalogBinding
WHERE 
		bbh.StatusCode = 1
	AND bbi.StatusCode = 1
	AND bbi.Offer < 100000
	AND bbi.Quantity > 0
	AND bbh.CreateTime >= @StartDate
	AND bbh.CreateTime < @EndDate

SELECT 
	ISNULL(lso.loc_BuyOfferPct_R42, lso.chain_BuyOfferPct_R42) [BuyOfferPct],
	SUM(lso.loc_SuggestedOffer_R40 * lso.Quantity)		[total_LocOffers_R40],
	SUM(lso.loc_SuggestedOffer_R42 * lso.Quantity)		[total_LocOffers_R42],
	AVG(lso.loc_SuggestedOffer_R40)		[avg_LocOffer_R40],
	AVG(lso.loc_SuggestedOffer_R42)		[avg_LocOffer_R42],
	SUM(lso.chain_SuggestedOffer_R40 * lso.Quantity)	[total_ChainOffers_R40],
	SUM(lso.chain_SuggestedOffer_R42 * lso.Quantity)	[total_ChainOffers_R42],
	AVG(lso.chain_SuggestedOffer_R40)	[avg_ChainOffer_R40],
	AVG(lso.chain_SuggestedOffer_R42)   [avg_ChainOffer_R42],
	SUM(ISNULL(lso.loc_SuggestedOffer_R40, lso.chain_SuggestedOffer_R40) * lso.Quantity) [total_SuggestedOffers_R40],
	SUM(ISNULL(lso.loc_SuggestedOffer_R42, lso.chain_SuggestedOffer_R42) * lso.Quantity) [total_SuggestedOffers_R42]
FROM #LocSuggestedOffers lso
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt
		ON lso.CatalogBinding = bt.CatalogBinding
		AND lso.
GROUP BY ISNULL(lso.loc_BuyOfferPct_R42, lso.chain_BuyOfferPct_R42)
ORDER BY ISNULL(lso.loc_BuyOfferPct_R42, lso.chain_BuyOfferPct_R42)

--SELECT 
--	lso.LocationNo,
--	lso.CatalogBinding,
--	SUM(lso.loc_SuggestedOffer_R40 * lso.Quantity)		[total_LocOffers_R40],
--	SUM(lso.loc_SuggestedOffer_R42 * lso.Quantity)		[total_LocOffers_R42],
--	AVG(lso.loc_SuggestedOffer_R40)		[avg_LocOffer_R40],
--	AVG(lso.loc_SuggestedOffer_R42)		[avg_LocOffer_R42],
--	SUM(lso.chain_SuggestedOffer_R40 * lso.Quantity)	[total_ChainOffers_R40],
--	SUM(lso.chain_SuggestedOffer_R42 * lso.Quantity)	[total_ChainOffers_R42],
--	AVG(lso.chain_SuggestedOffer_R40)	[avg_ChainOffer_R40],
--	AVG(lso.chain_SuggestedOffer_R42)   [avg_ChainOffer_R42],
--	SUM(ISNULL(lso.loc_SuggestedOffer_R40, lso.chain_SuggestedOffer_R40) * lso.Quantity) [total_SuggestedOffers_R40],
--	SUM(ISNULL(lso.loc_SuggestedOffer_R42, lso.chain_SuggestedOffer_R42) * lso.Quantity) [total_SuggestedOffers_R42]
--FROM #LocSuggestedOffers lso
--GROUP BY lso.LocationNo, CatalogBinding WITH CUBE
--ORDER BY lso.LocationNo, CatalogBinding

DROP TABLE #LocSuggestedOffers
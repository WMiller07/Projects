/****** Script for SelectTopNRows command from SSMS  ******/
DECLARE @StartDate DATE = '9/1/2019'
DECLARE @EndDate DATE = '10/1/2019'
DECLARE @LastR4ChainGenDate DATE
DECLARE @LastR4LocGenDate DATE

SELECT 
	@LastR4ChainGenDate = MAX(ba.Date_Generated)
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R4 ba

SELECT 
	@LastR4LocGenDate = MAX(adl.Insert_Date)
FROM Buy_Analytics.dbo.BuyAlgorithm_AggregateData_Location adl

SELECT 
	ba.CatalogID,
	MIN(ba.Chain_Buy_Offer_Pct) [chain_BuyOfferPct],
	MIN(ba.Chain_SuggestedOffer) [chain_BuyOfferAmt]
INTO #ChainSuggestedOffers
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R4 ba
WHERE ba.Date_Generated = @LastR4ChainGenDate
GROUP BY ba.CatalogID

SELECT 
	ba.CatalogID,
	ba.LocationNo,
	MIN(ba.Location_Buy_Offer_Pct) [loc_BuyOfferPct],
	MIN(ba.Location_SuggestedOffer) [loc_BuyOfferAmt]
INTO #LocationSuggestedOffers
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R4 ba
WHERE ba.Date_Generated = @LastR4ChainGenDate
GROUP BY ba.CatalogID, ba.LocationNo

SELECT DISTINCT
	adc.CatalogID,
	bt.CatalogBinding,
	adc.Total_Item_Count,
	adc.Total_Accumulated_Days_With_Trash_Penalty,
	adc.Avg_Sale_Price,
	adc.Total_Sold,
	bt.BuyOfferPct [R4BuyOfferPct],
	bts.BuyOfferPct [R4sBuyOfferPct],
	adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count [avg_Item_Acc_Days],
	adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1) [avg_Sold_Acc_Days],
	CAST(adc.Avg_Sale_Price * bt.BuyOfferPct AS DECIMAL(19,2)) [R4BuyOfferAmt],
	CAST(adc.Avg_Sale_Price * bts.BuyOfferPct AS DECIMAL(19,2)) [R4sBuyOfferAmt],
	cso.chain_BuyOfferPct [chain_R4BuyOfferPct],
	cso.chain_BuyOfferAmt [chain_R4BuyOfferAmt]
INTO #ChainCalculatedOffers
FROM Buy_Analytics.dbo.BuyAlgorithm_AggregateData_Chain adc
	INNER JOIN Catalog..titles t
		ON adc.CatalogID = t.catalogId
	INNER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt
		ON (CASE
				WHEN t.binding IN ('Audio CD', 'CD', 'Mass Market Paperback')
				THEN t.binding
				ELSE 'General'
				END) = bt.CatalogBinding
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count) AS DECIMAL(19, 2)) > bt.AccDaysRangeFrom
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count) AS DECIMAL(19, 2)) <= bt.AccDaysRangeTo
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 bts
		ON (CASE
				WHEN t.binding IN ('Audio CD', 'CD', 'Mass Market Paperback')
				THEN t.binding
				ELSE 'General'
				END) = bt.CatalogBinding
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) AS DECIMAL(19, 2)) > bts.AccDaysRangeFrom
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) AS DECIMAL(19, 2)) <= bts.AccDaysRangeTo
	INNER JOIN #ChainSuggestedOffers cso
		ON adc.CatalogID = cso.CatalogID
WHERE adc.Insert_Date > '10/17/19' AND adc.Insert_Date < '10/18/19'

SELECT
	adc.CatalogID,
	bt.CatalogBinding,
	adc.LocationNo,
	adc.Total_Item_Count,
	adc.Total_Sold,
	bt.BuyOfferPct [R4BuyOfferPct],
	bts.BuyOfferPct [R4sBuyOfferPct],
	adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count [avg_Item_Acc_Days],
	adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1) [avg_Sold_Acc_Days],
	adc.Total_Accumulated_Days_With_Trash_Penalty,
	adc.Avg_Sale_Price,
	CAST(adc.Avg_Sale_Price * bt.BuyOfferPct AS DECIMAL(19,2)) [R4BuyOfferAmt],
	CAST(adc.Avg_Sale_Price * bts.BuyOfferPct AS DECIMAL(19,2)) [R4SBuyOfferAmt],
	lso.loc_BuyOfferPct [chain_R4BuyOfferPct],
	lso.loc_BuyOfferAmt [chain_R4BuyOfferAmt]
INTO #LocationCalculatedOffers
FROM Buy_Analytics.dbo.BuyAlgorithm_AggregateData_Location adc
	INNER JOIN Catalog..titles t
		ON adc.CatalogID = t.catalogId
	INNER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt
		ON (CASE
				WHEN t.binding IN ('Audio CD', 'CD', 'Mass Market Paperback')
				THEN t.binding
				ELSE 'General'
				END) = bt.CatalogBinding
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count) AS DECIMAL(19, 2)) > bt.AccDaysRangeFrom
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count) AS DECIMAL(19, 2)) <= bt.AccDaysRangeTo
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 bts
		ON (CASE
				WHEN t.binding IN ('Audio CD', 'CD', 'Mass Market Paperback')
				THEN t.binding
				ELSE 'General'
				END) = bt.CatalogBinding
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) AS DECIMAL(19, 2)) > bts.AccDaysRangeFrom
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) AS DECIMAL(19, 2)) <= bts.AccDaysRangeTo
	INNER JOIN #LocationSuggestedOffers lso
		ON adc.CatalogID = lso.CatalogID
		AND adc.LocationNo = lso.LocationNo
WHERE adc.Insert_Date > '10/17/19' AND adc.Insert_Date < '10/18/19'

--SELECT
--	CAST(COUNT(CASE
--			WHEN o.R4BuyOfferAmt <> o.R4SBuyOfferAmt
--			THEN o.CatalogID
--			END) AS FLOAT) / NULLIF(CAST(COUNT(o.CatalogID) AS FLOAT), 0) [pct_TitleOffersChanged],
--	SUM(o.R4SBuyOfferAmt) / NULLIF(SUM(o.R4BuyOfferAmt), 0) [pct_AmtOffersChanged]
--FROM #ChainOffers o

--SELECT
--	CAST(COUNT(CASE
--			WHEN o.R4BuyOfferAmt <> o.R4SBuyOfferAmt
--			THEN o.CatalogID
--			END) AS FLOAT) / NULLIF(CAST(COUNT(o.CatalogID) AS FLOAT), 0) [pct_TitleOffersChanged],
--	SUM(o.R4SBuyOfferAmt) / NULLIF(SUM(o.R4BuyOfferAmt), 0) [pct_AmtOffersChanged]
--FROM #LocationOffers o

SELECT 
	bbi.LocationNo,
	ISNULL(lo.CatalogBinding, co.CatalogBinding) [Binding],
	ISNULL(lo.R4sBuyOfferPct, co.R4sBuyOfferPct) [BuyOfferPct],
	COUNT(DISTINCT bbi.CatalogID) [count_Titles],
	SUM(bbi.SuggestedOffer) [total_R40SuggestedOffers],
	SUM(bbi.SuggestedOffer)/SUM(bbi.Quantity) [avg_R40SuggestedOffer],
	SUM(ISNULL(lo.R4SBuyOfferAmt, co.R4sBuyOfferAmt)) [total_R42SuggestedOffers],
	SUM(ISNULL(lo.R4SBuyOfferAmt, co.R4sBuyOfferAmt))/SUM(bbi.Quantity) [avg_R42SuggestedOffers]
FROM BUYS..BuyBinItems bbi
	LEFT OUTER JOIN #ChainCalculatedOffers co
		ON bbi.CatalogID = co.CatalogID
	LEFT OUTER JOIN #LocationCalculatedOffers lo
		ON bbi.CatalogID = lo.CatalogID
		AND bbi.LocationNo = lo.LocationNo
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON bbi.LocationNo = lba.LocationNo
	INNER JOIN Catalog..titles t
		ON bbi.CatalogID = t.catalogId
WHERE 
		bbi.StatusCode = 1
	AND bbi.CreateTime >= @StartDate
	AND bbi.CreateTime < @EndDate
	AND bbi.Quantity > 0
GROUP BY 
	bbi.LocationNo, 	
	ISNULL(lo.CatalogBinding, co.CatalogBinding),
	ISNULL(lo.R4sBuyOfferPct, co.R4sBuyOfferPct)
	WITH ROLLUP
ORDER BY bbi.LocationNo, ISNULL(lo.R4sBuyOfferPct, co.R4sBuyOfferPct), [Binding]

SELECT 
	bbi.LocationNo,
	ISNULL(lo.CatalogBinding, co.CatalogBinding) [Binding],
	SUM(bbi.SuggestedOffer) [total_R40SuggestedOffers],
	SUM(bbi.SuggestedOffer)/SUM(bbi.Quantity) [avg_R40SuggestedOffer],
	SUM(ISNULL(lo.R4SBuyOfferAmt, co.R4sBuyOfferAmt)) [total_R42SuggestedOffers],
	SUM(ISNULL(lo.R4SBuyOfferAmt, co.R4sBuyOfferAmt))/SUM(bbi.Quantity) [avg_R42SuggestedOffers]
FROM BUYS..BuyBinItems bbi
	LEFT OUTER JOIN #ChainCalculatedOffers co
		ON bbi.CatalogID = co.CatalogID
	LEFT OUTER JOIN #LocationCalculatedOffers lo
		ON bbi.CatalogID = lo.CatalogID
		AND bbi.LocationNo = lo.LocationNo
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON bbi.LocationNo = lba.LocationNo
	INNER JOIN Catalog..titles t
		ON bbi.CatalogID = t.catalogId
WHERE 
		bbi.StatusCode = 1
	AND bbi.CreateTime >= @StartDate
	AND bbi.CreateTime < @EndDate
	AND bbi.Quantity > 0
GROUP BY 
	bbi.LocationNo, 	
	ISNULL(lo.CatalogBinding, co.CatalogBinding)
ORDER BY bbi.LocationNo, [Binding]

DROP TABLE #ChainSuggestedOffers
DROP TABLE #LocationSuggestedOffers
DROP TABLE #ChainCalculatedOffers
DROP TABLE #LocationCalculatedOffers




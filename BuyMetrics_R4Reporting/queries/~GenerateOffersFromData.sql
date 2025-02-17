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

SELECT
	adc.CatalogID,
	adc.Total_Item_Count,
	adc.Total_Sold,
	bt.BuyOfferPct,
	adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count [avg_Item_Acc_Days],
	adc.Total_Accumulated_Days_With_Trash_Penalty / (CASE WHEN adc.Total_Sold = 0 THEN 1 ELSE adc.Total_Sold END) [avg_Sold_Acc_Days],
	adc.Total_Accumulated_Days_With_Trash_Penalty,
	adc.Avg_Sale_Price,
	CAST(adc.Avg_Sale_Price * bt.BuyOfferPct AS DECIMAL(19,2)) [BuyOfferAmt],
	cso.chain_BuyOfferPct [chain_R4BuyOfferPct],
	cso.chain_BuyOfferAmt [chain_R4BuyOfferAmt]
INTO #ChainOffers
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
	INNER JOIN #ChainSuggestedOffers cso
		ON adc.CatalogID = cso.CatalogID
WHERE adc.Insert_Date > '10/7/19' AND adc.Insert_Date < '10/8/19'

SELECT
	adc.CatalogID,
	adc.LocationNo,
	adc.Total_Item_Count,
	adc.Total_Sold,
	bt.BuyOfferPct,
	adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count [avg_Item_Acc_Days],
	adc.Total_Accumulated_Days_With_Trash_Penalty / (CASE WHEN adc.Total_Sold = 0 THEN 1 ELSE adc.Total_Sold END) [avg_Sold_Acc_Days],
	adc.Total_Accumulated_Days_With_Trash_Penalty,
	adc.Avg_Sale_Price,
	CAST(adc.Avg_Sale_Price * bt.BuyOfferPct AS DECIMAL(19,2)) [BuyOfferAmt],
	lso.loc_BuyOfferPct [chain_R4BuyOfferPct],
	lso.loc_BuyOfferAmt [chain_R4BuyOfferAmt]
INTO #LocationOffers
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
	INNER JOIN #LocationSuggestedOffers lso
		ON adc.CatalogID = lso.CatalogID
		AND adc.LocationNo = lso.LocationNo
WHERE adc.Insert_Date > '10/7/19' AND adc.Insert_Date < '10/8/19'

SELECT *
FROM #LocationOffers lo
WHERE lo.BuyOfferAmt =r lo.chain_R4BuyOfferAmt

DROP TABLE #ChainSuggestedOffers
DROP TABLE #ChainOffers




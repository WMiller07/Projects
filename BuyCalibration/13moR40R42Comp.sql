/****** Script for SelectTopNRows command from SSMS  ******/
DECLARE @StartDate DATE = '10/1/2018'
DECLARE @EndDate DATE = '11/1/2019'
DECLARE @LastR4ChainGenDate DATE
DECLARE @LastR4LocGenDate DATE

SELECT 
	@LastR4ChainGenDate = MAX(ba.Date_Generated)
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R4 ba


SELECT 
	ba.CatalogID,
	MIN(ba.Chain_Buy_Offer_Pct) [chain_BuyOfferPct],
	MIN(ba.Chain_SuggestedOffer) [chain_BuyOfferAmt]
INTO #ChainSuggestedOffers
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R4 ba
WHERE ba.Date_Generated = @LastR4ChainGenDate
GROUP BY ba.CatalogID


SELECT DISTINCT
	adc.CatalogID,
	bt.CatalogBinding,
	bts.CatalogBinding [alt_CatalogBinding],
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
				END) = bts.CatalogBinding
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) AS DECIMAL(19, 2)) > bts.AccDaysRangeFrom
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) AS DECIMAL(19, 2)) <= bts.AccDaysRangeTo
	INNER JOIN #ChainSuggestedOffers cso
		ON adc.CatalogID = cso.CatalogID
WHERE adc.Insert_Date = (SELECT MAX(adc.Insert_Date) FROM Buy_Analytics.dbo.BuyAlgorithm_AggregateData_Chain adc)

SELECT 
	bbi.CatalogID,
	COUNT(bbi.CatalogID) [qty_Purchased]
INTO #ChainQtyPurchased
FROM BUYS..BuyBinItems bbi
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON bbi.LocationNo = lba.LocationNo
	INNER JOIN Catalog..titles t
		ON bbi.CatalogID = t.catalogId
WHERE 
		bbi.StatusCode = 1
	AND bbi.CreateTime >= @StartDate
	AND bbi.CreateTime < @EndDate
	AND bbi.Quantity > 0
GROUP BY bbi.CatalogID

--SELECT
--	cqp.CatalogID,
--	co.CatalogBinding,
--	cqp.qty_Purchased,
--	co.R4BuyOfferAmt,
--	co.R4sBuyOfferAmt,
--	co.R4BuyOfferPct,
--	co.R4sBuyOfferPct,
--	co.Total_Accumulated_Days_With_Trash_Penalty,
--	co.Total_Item_Count,
--	co.Total_Sold,
--	co.Avg_Sale_Price,
--	co.avg_Item_Acc_Days,
--	co.avg_Sold_Acc_Days
--FROM #ChainQtyPurchased cqp
--	INNER JOIN #ChainCalculatedOffers co
--		ON cqp.CatalogID = co.CatalogID

SELECT 
	co.CatalogBinding,
	CASE
		WHEN GROUPING(co.R4BuyOfferPct) = 1
		THEN 999
		ELSE co.R4BuyOfferPct
		END [R4BuyOfferPct],
	SUM(co.R4BuyOfferAmt * cqp.qty_Purchased) [R40TotalCost],
	SUM(cqp.qty_Purchased) [R40QtyPurchased]
INTO #R40Offers
FROM #ChainQtyPurchased cqp
	INNER JOIN #ChainCalculatedOffers co
		ON cqp.CatalogID = co.CatalogID
GROUP BY co.CatalogBinding, co.R4BuyOfferPct WITH ROLLUP
ORDER BY co.CatalogBinding

SELECT 
	co.CatalogBinding,
	CASE
		WHEN GROUPING(co.R4sBuyOfferPct) = 1
		THEN 999
		ELSE co.R4sBuyOfferPct
		END [R4sBuyOfferPct],
	SUM(co.R4sBuyOfferAmt * cqp.qty_Purchased) [R42TotalCost],
	SUM(cqp.qty_Purchased) [R42QtyPurchased]
INTO #R42Offers
FROM #ChainQtyPurchased cqp
	INNER JOIN #ChainCalculatedOffers co
		ON cqp.CatalogID = co.CatalogID
GROUP BY co.CatalogBinding, co.R4sBuyOfferPct WITH ROLLUP
ORDER BY co.CatalogBinding

SELECT 
	r40.CatalogBinding,
	r40.R4BuyOfferPct [BuyOfferPct],
	r40.R40TotalCost,
	r42.R42TotalCost,
	r40.R40QtyPurchased,
	r42.R42QtyPurchased
FROM #R40Offers r40
	INNER JOIN #R42Offers r42
		ON r40.CatalogBinding = r42.CatalogBinding
		AND r40.R4BuyOfferPct = r42.R4sBuyOfferPct
ORDER BY r40.CatalogBinding, r40.R4BuyOfferPct 

DROP TABLE #R40Offers
DROP TABLE #R42Offers
DROP TABLE #ChainSuggestedOffers
DROP TABLE #ChainCalculatedOffers
DROP TABLE #ChainQtyPurchased











DECLARE @StartDate DATE = '10/18/2018'
DECLARE @EndDate DATE = '11/18/2019'
DECLARE @LastR4ChainGenDate DATE
DECLARE @LastR4LocGenDate DATE
DECLARE @LastR41AvgGenDate DATE

SELECT 
	@LastR41AvgGenDate = MAX(adac.Date_Generated)
FROM Buy_Analytics..AccumulatedDays_Average_Chain_V1_R41 adac


SELECT 
	ba.CatalogID,
	MIN(ba.Chain_Buy_Offer_Pct) [chain_BuyOfferPct],
	MIN(ba.Chain_SuggestedOffer) [chain_BuyOfferAmt]
INTO #ChainSuggestedOffers
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R4 ba
WHERE ba.Date_Generated = @LastR4ChainGenDate
GROUP BY ba.CatalogID

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

SELECT 
	adc.CatalogID,
	t.title,
	t.author,
	t.releaseDate,
	bt.CatalogBinding,
	adc.Total_Item_Count,
	adc.Total_Accumulated_Days_With_Trash_Penalty,
	adc.Avg_Sale_Price,
	adc.Total_Sold,
	cqp.qty_Purchased,
	bt.BuyOfferPct [R4BuyOfferPct],
	bts.BuyOfferPct [R4sBuyOfferPct],
	adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count [avg_Item_Acc_Days],
	adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1) [avg_Sold_Acc_Days],
	CAST(adc.Avg_Sale_Price * bt.BuyOfferPct AS DECIMAL(19,2)) [R4BuyOfferAmt],
	CAST(adc.Avg_Sale_Price * bts.BuyOfferPct AS DECIMAL(19,2)) [R4sBuyOfferAmt]
INTO #ChainCalculatedOffers
FROM Buy_Analytics.dbo.BuyAlgorithm_AggregateData_Chain adc
	INNER JOIN Catalog..titles t
		ON adc.CatalogID = t.catalogId
	INNER JOIN Buy_Analytics..AccumulatedDays_Average_Chain_V1_R41 adac
		ON adac.Date_Generated = @LastR41AvgGenDate
		AND adc.CatalogID = adac.CatalogID
	INNER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt
		ON (CASE
				WHEN t.binding IN ('Audio CD', 'CD', 'Mass Market Paperback')
				THEN t.binding
				ELSE 'General'
				END) = bt.CatalogBinding
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count) AS DECIMAL(19, 2)) > bt.AccDaysRangeFrom
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count) AS DECIMAL(19, 2)) <= bt.AccDaysRangeTo
	INNER JOIN Buy_Analytics_Cashew..AccumulatedDaysOnShelf_BuyTable_V1_R42 bts
		ON (CASE
				WHEN t.binding IN ('Audio CD', 'CD', 'Mass Market Paperback')
				THEN t.binding
				ELSE 'General'
				END) = bts.CatalogBinding
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) AS DECIMAL(19, 2)) > bts.AccDaysRangeFrom
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty / (adc.Total_Sold + 1)) AS DECIMAL(19, 2)) <= bts.AccDaysRangeTo
	INNER JOIN #ChainQtyPurchased cqp
		ON adc.CatalogID = cqp.CatalogID
--WHERE adc.Insert_Date > '10/17/19' AND adc.Insert_Date < '10/18/19'
ORDER BY CatalogID

SELECT 
	SUM(cco.qty_Purchased) [qty_Purchased],
	CAST(SUM(CASE WHEN cco.R4sBuyOfferPct < cco.R4BuyOfferPct THEN cco.qty_Purchased END) AS FLOAT)/ 
		CAST(SUM(cco.qty_Purchased) AS FLOAT) [pct_QtyLoweredOffer],
	SUM(CASE WHEN cco.R4sBuyOfferPct < cco.R4BuyOfferPct THEN cco.qty_Purchased END) [qty_LowertOffer],
	SUM(cco.qty_Purchased * cco.R4BuyOfferAmt) [R40TotalCost],
	SUM(cco.qty_Purchased * cco.R4sBuyOfferAmt) [R42TotalCost]
FROM #ChainCalculatedOffers cco
--WHERE cco.R4BuyOfferPct >= 0.05 AND
--(CAST(cco.Total_Sold AS FLOAT) / CAST(cco.Total_Item_Count AS FLOAT)) <= 0.5



--SELECT 
--	cco.R4sBuyOfferPct,
--	CAST(SUM(cco.Total_Sold) AS FLOAT)/CAST(SUM(cco.Total_Item_Count) AS FLOAT) [pct_SellThrough],
--		AVG(cco.Avg_Sale_Price) [avg_SalePrice],
--	SUM(cco.qty_Purchased) [total_QtyPurchased_13mo],
--	COUNT(cco.CatalogID) [count_Titles], 
--	SUM(cco.Total_Sold) [total_Sold_AllTime],
--	CAST(COUNT(CASE 
--				WHEN (CAST(DATEDIFF(DAY, cco.releaseDate, @EndDate ) AS FLOAT) / 365) < 2
--				THEN cco.CatalogID
--		END) AS FLOAT) / CAST(COUNT(cco.CatalogID) AS FLOAT) [pct_NewRelease]
--FROM #ChainCalculatedOffers cco
--WHERE (CAST(cco.Total_Sold AS FLOAT)/CAST(cco.Total_Item_Count AS FLOAT)) <= 1
--GROUP BY cco.R4sBuyOfferPct
--ORDER BY cco.R4sBuyOfferPct

--SELECT 
--	cco.R4BuyOfferPct,
--	CAST(SUM(cco.Total_Sold) AS FLOAT)/CAST(SUM(cco.Total_Item_Count) AS FLOAT) [pct_SellThrough],
--	AVG(cco.Avg_Sale_Price) [avg_SalePrice],
--	SUM(cco.qty_Purchased) [total_QtyPurchased_13mo],
--	COUNT(cco.CatalogID) [count_Titles], 
--	SUM(cco.Total_Sold) [total_Sold_AllTime],
--	CAST(COUNT(CASE 
--		WHEN (CAST(DATEDIFF(DAY, cco.releaseDate, @EndDate ) AS FLOAT) / 365) < 2
--		THEN cco.CatalogID
--		END) AS FLOAT) / CAST(COUNT(cco.CatalogID) AS FLOAT) [pct_NewRelease]
--FROM #ChainCalculatedOffers cco
--WHERE (CAST(cco.Total_Sold AS FLOAT)/CAST(cco.Total_Item_Count AS FLOAT)) <= 1
--GROUP BY cco.R4BuyOfferPct
--ORDER BY cco.R4BuyOfferPct



DROP TABLE #ChainSuggestedOffers
DROP TABLE #ChainCalculatedOffers
DROP TABLE #ChainQtyPurchased
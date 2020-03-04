DECLARE @StartDate DATE = '4/1/2019'
DECLARE @EndDate DATE = '6/1/2019'

/**************************
Step 1: Determine the actual buy grade for each catalogID in the chain, based on the performance of items priced between StartDate and EndDate
**************************/
SELECT 
	spi.LocationNo,
	lc.CatalogID,
	CASE 
		WHEN t.binding IN ('Mass Market Paperback', 'CD', 'Audio CD')
		THEN t.binding
		ELSE 'General'
		END [CatalogBinding],
	lc.ItemCode,
	lc.First_RecordDate,
	CASE 
		WHEN lc.Days_Scanned = 0 
		THEN lc.Days_Salable_Priced 
		ELSE lc.Days_Salable_Scanned 
		END [Item_Acc_Days_NR],
	((case when lc.Days_Scanned = 0 then lc.Days_Salable_Priced else lc.Days_Salable_Scanned end) +
		(case when lc.Current_Item_Status in ('T', 'D') 
		and (datediff(day, lc.First_RecordDate,  lc.Last_TransferDate) >= 7 
		or datediff(hour, lc.First_ScanDate,  lc.Last_TransferDate) >= 24) then 181
		else 0 end)
		) [Item_Acc_Days_TrashPenalty],
	CASE
		WHEN lc.LastEventType = 5
		THEN lc.Sale_Price
		END [Sale_Price]
INTO #ActualDayAccumulation
FROM Buy_Analytics..ItemCode_LifeCycle lc
	INNER JOIN ReportsData..SipsProductInventory spi
		ON spi.ItemCode = lc.ItemCode
	INNER JOIN Catalog..titles t
		ON lc.CatalogID = t.catalogId
	INNER JOIN ReportsData..StoreLocationMaster slm
		ON spi.LocationNo = slm.LocationNo
WHERE 
		lc.First_RecordDate >= @StartDate
	AND lc.First_RecordDate < @EndDate
	AND slm.StoreType = 'S'


--This could easily be combined with the query above, but it is kept as a separate temp table for now for the sake of keeping the data at each stage of processing accessible.
SELECT
	CASE
		WHEN GROUPING(ada.LocationNo) = 1
		THEN 'Chain'
		ELSE ada.LocationNo
		END [LocationNo],
	ada.CatalogID,
	ada.CatalogBinding,
	MIN(First_RecordDate) [first_CatalogRecordDate],
	COUNT(ada.ItemCode) [count_ItemsPriced],
	COUNT(ada.Sale_Price) [count_ItemsSold],
	SUM(ada.Item_Acc_Days_TrashPenalty) [Catalog_AccDays_TrashPenalty],
	SUM(ada.Item_Acc_Days_NR) [Catalog_AccDays_NR],
	CAST(SUM(ada.Item_Acc_Days_TrashPenalty) AS FLOAT) /
		NULLIF(CAST(COUNT(ada.ItemCode) AS FLOAT), 0) [avg_CatalogAccDays_TrashPenalty_R40],
	CAST(SUM(ada.Item_Acc_Days_TrashPenalty) AS FLOAT) /
		NULLIF(CAST((COUNT(ada.Sale_Price) + 1) AS FLOAT), 0) [avg_CatalogAccDays_TrashPenalty_R42],
	AVG(ada.Sale_Price) [avg_SalePrice]
INTO #CatalogDayAccumulation
FROM #ActualDayAccumulation ada
GROUP BY CUBE(ada.LocationNo), ada.CatalogID, ada.CatalogBinding

SELECT
	cda.LocationNo,
	cda.CatalogID,
	cda.CatalogBinding,
	cda.first_CatalogRecordDate,
	cda.count_ItemsPriced,
	cda.count_ItemsSold,
	cda.avg_CatalogAccDays_TrashPenalty_R40,
	cda.avg_CatalogAccDays_TrashPenalty_R42,
	cda.avg_SalePrice,
	bt.BuyGradeName [BuyGradeName],
	bt.BuyOfferPct [BuyOfferPct],
	bt.BuyOfferPct * cda.avg_SalePrice [BuyOfferAmt]
INTO #ChainActualGrades
FROM #CatalogDayAccumulation cda
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 bt
		ON cda.CatalogBinding = bt.CatalogBinding
		AND cda.avg_CatalogAccDays_TrashPenalty_R42 > bt.AccDaysRangeFrom
		AND cda.avg_CatalogAccDays_TrashPenalty_R42 <= bt.AccDaysRangeTo
WHERE LocationNo = 'Chain'

SELECT
	cda.LocationNo,
	cda.CatalogID,
	cda.CatalogBinding,
	cda.first_CatalogRecordDate,
	cda.count_ItemsPriced,
	cda.count_ItemsSold,
	cda.avg_CatalogAccDays_TrashPenalty_R40,
	cda.avg_CatalogAccDays_TrashPenalty_R42,
	cda.avg_SalePrice, 
	bt.BuyGradeName [BuyGradeName],
	bt.BuyOfferPct [BuyOfferPct],
	bt.BuyOfferPct * ISNULL(cda.avg_SalePrice, cag.avg_SalePrice) [BuyOfferAmt]
INTO #LocationActualGrades
FROM #CatalogDayAccumulation cda
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 bt
		ON cda.CatalogBinding = bt.CatalogBinding
		AND cda.avg_CatalogAccDays_TrashPenalty_R42 > bt.AccDaysRangeFrom
		AND cda.avg_CatalogAccDays_TrashPenalty_R42 <= bt.AccDaysRangeTo
	INNER JOIN #ChainActualGrades cag
		ON cda.CatalogID = cag.CatalogID
WHERE cda.LocationNo <> 'Chain'



--DROP TABLE #ActualDayAccumulation
--DROP TABLE #CatalogDayAccumulation

/**************************
Step 2: Evaluate algorithm offer percentage for each catalogID priced b
etween StartDate and EndDate
**************************/
--Get all chain-level offers generated between start date and end date
--Get all chain-level offers generated between start date and end date
SELECT DISTINCT
	ba.CatalogID,
	ba.Chain_Buy_Offer_Pct,
	ba.Chain_Avg_Sale_Price,
	ba.Chain_SuggestedOffer,
	CAST(adc.Total_Accumulated_Days_With_Trash_Penalty AS FLOAT) / NULLIF(CAST(adc.Total_Sold AS FLOAT), 0) [avg_Accumulated_Days_With_Trash_Penalty],
	ba.Date_Generated
INTO #ChainBuyGrades
FROM Sandbox..BuyAlgorithm_V1_R42_190401 ba
	INNER JOIN Sandbox..BuyAlgorithm_AggregateData_Chain_190401 adc
		ON ba.CatalogID = adc.CatalogID

--Get all location-level offers generated between start date and end date
SELECT
	ba.CatalogID,
	ba.LocationNo,
	ba.Location_Buy_Offer_Pct,
	ISNULL(ba.Location_Avg_Sale_Price, ba.Chain_Avg_Sale_Price) [Location_Avg_Sale_Price],
	ba.Location_SuggestedOffer,
	CAST(adl.Total_Accumulated_Days_With_Trash_Penalty AS FLOAT) / NULLIF(CAST(adl.Total_Sold AS FLOAT), 0) [avg_Accumulated_Days_With_Trash_Penalty],
	ba.Date_Generated
INTO #LocBuyGrades
FROM Sandbox..BuyAlgorithm_V1_R42_190401 ba
	INNER JOIN Sandbox..BuyAlgorithm_AggregateData_Location_190401 adl
		ON ba.CatalogID = adl.CatalogID
		AND ba.LocationNo = adl.LocationNo
WHERE ba.LocationNo IS NOT NULL


SELECT 
	la.LocationNo,
	la.CatalogID,
	la.CatalogBinding,
	la.count_ItemsPriced,
	la.count_ItemsSold,
	la.avg_CatalogAccDays_TrashPenalty_R42 [avg_CatalogAccDays_TrashPenalty],
	la.avg_SalePrice [actual_AvgSalePrice],
	la.BuyGradeName [actual_BuyGradeName],
	la.BuyOfferPct [actual_BuyOfferPct],
	la.BuyOfferAmt [actual_BuyOfferAmt],
	ISNULL(lbg.Location_Avg_Sale_Price, cbg.Chain_Avg_Sale_Price) [pred_AvgSalePrice],
	ISNULL(lbg.Location_Buy_Offer_Pct, cbg.Chain_Buy_Offer_Pct) [pred_BuyOfferPct],
	ISNULL(lbg.Location_SuggestedOffer, cbg.Chain_SuggestedOffer) [pred_SuggestedOffer],
	ISNULL(lbg.avg_Accumulated_Days_With_Trash_Penalty, cbg.avg_Accumulated_Days_With_Trash_Penalty) [pred_AAD],
	cbg.Chain_Avg_Sale_Price [pred_AvgSalePrice_Chain],
	cbg.Chain_Buy_Offer_Pct [pred_BuyOfferPct_Chain],
	cbg.Chain_SuggestedOffer [pred_SuggestedOffer_Chain],
    cbg.avg_Accumulated_Days_With_Trash_Penalty [pred_AAD_Chain],
	lbg.Location_Avg_Sale_Price [pred_AvgSalePrice_Loc],
	lbg.Location_Buy_Offer_Pct [pred_BuyOfferPct_Loc],
	lbg.Location_SuggestedOffer [pred_SuggestedOffer_Loc],
	lbg.avg_Accumulated_Days_With_Trash_Penalty [pred_AAD_Loc],
	ISNULL(lbg.Date_Generated, cbg.Date_Generated) [Date_Generated],
	'LocChain' [OfferType]
FROM #LocationActualGrades la
	LEFT OUTER JOIN #LocBuyGrades lbg
		ON la.CatalogID = lbg.CatalogID
		AND la.LocationNo = lbg.LocationNo
	INNER JOIN #ChainBuyGrades cbg
		ON la.CatalogID = cbg.CatalogID
	INNER JOIN #ChainActualGrades ca
		ON la.CatalogID = ca.CatalogID
UNION
SELECT 
	ca.LocationNo,
	ca.CatalogID,
	ca.CatalogBinding,
	ca.count_ItemsPriced,
	ca.count_ItemsSold,
	ca.avg_CatalogAccDays_TrashPenalty_R42 [avg_CatalogAccDays_TrashPenalty],
	ca.avg_SalePrice [actual_AvgSalePrice],
	ca.BuyGradeName [actual_BuyGradeName],
	ca.BuyOfferPct [actual_BuyOfferPct],
	ca.BuyOfferAmt [actual_BuyOfferAmt],
	cbg.Chain_Avg_Sale_Price [pred_AvgSalePrice],
	cbg.Chain_Buy_Offer_Pct [pred_BuyOfferPct],
	cbg.Chain_SuggestedOffer [pred_SuggestedOffer],
    cbg.avg_Accumulated_Days_With_Trash_Penalty [pred_AAD],
	NULL [pred_AvgSalePrice_Chain],
	NULL [pred_BuyOfferPct_Chain],
	NULL [pred_SuggestedOffer_Chain],
    NULL [pred_AAD_Chain],
	NULL [pred_AvgSalePrice_Loc],
	NULL [pred_BuyOfferPct_Loc],
	NULL [pred_SuggestedOffer_Loc],
	NULL [pred_AAD_Loc],
	cbg.Date_Generated,
	'ChainOnly' [OfferType]
FROM #ChainActualGrades ca
	INNER JOIN #ChainBuyGrades cbg
		ON ca.CatalogID = cbg.CatalogID


DROP TABLE #CatalogDayAccumulation
DROP TABLE #ActualDayAccumulation
DROP TABLE #ChainActualGrades
DROP TABLE #LocationActualGrades
DROP TABLE #ChainBuyGrades
DROP TABLE #LocBuyGrades
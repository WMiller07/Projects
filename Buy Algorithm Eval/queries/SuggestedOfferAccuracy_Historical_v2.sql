DECLARE @StartDate DATE = '4/1/2019'
DECLARE @EndDate DATE = '12/9/2019'


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
		) [Item_Acc_Days_TrashPenalty_R40],
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

SELECT DISTINCT
	ba.CatalogID,
	ba.Chain_Buy_Offer_Pct,
	ba.Chain_Avg_Sale_Price,
	ba.Chain_SuggestedOffer,
	CAST(adc.Total_Accumulated_Days_With_Trash_Penalty AS FLOAT) / NULLIF(CAST(adc.Total_Item_Count AS FLOAT), 0) [avg_Accumulated_Days_With_Trash_Penalty_R40],
	CAST(adc.Total_Accumulated_Days_With_Trash_Penalty AS FLOAT) / NULLIF(CAST(adc.Total_Sold AS FLOAT), 0) [avg_Accumulated_Days_With_Trash_Penalty_R42],
	ba.Date_Generated
INTO #ChainBuyGrades
FROM Sandbox..BuyAlgorithm_V1_R4_190401 ba
	INNER JOIN Sandbox..BuyAlgorithm_AggregateData_Chain_190401 adc
		ON ba.CatalogID = adc.CatalogID
	--INNER JOIN Catalog..titles t
	--	ON ba.CatalogID = t.catalogId
	--INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt40
	--	ON CAST(adc.Total_Accumulated_Days_With_Trash_Penalty AS FLOAT) / NULLIF(CAST(adc.Total_Item_Count AS FLOAT), 0) > bt40.AccDaysRangeFrom
	--	AND CAST(adc.Total_Accumulated_Days_With_Trash_Penalty AS FLOAT) / NULLIF(CAST(adc.Total_Item_Count AS FLOAT), 0) <= bt40.AccDaysRangeTo
	--	AND (CASE WHEN t.binding IN ('Mass Market Paperback', 'CD', 'Audio CD') THEN t.binding ELSE 'General' END) = bt40.CatalogBinding
--WHERE ba.Date_Generated >= @StartDate
--	AND ba.Date_Generated < @EndDate

--Get all location-level offers generated between start date and end date
SELECT
	ba.CatalogID,
	ba.LocationNo,
	ba.Location_Buy_Offer_Pct,
	ISNULL(ba.Location_Avg_Sale_Price, ba.Chain_Avg_Sale_Price) [Location_Avg_Sale_Price],
	ba.Location_SuggestedOffer,
	CAST(adl.Total_Accumulated_Days_With_Trash_Penalty AS FLOAT) / NULLIF(CAST(adl.Total_Item_Count AS FLOAT), 0) [avg_Accumulated_Days_With_Trash_Penalty_R40],
	CAST(adl.Total_Accumulated_Days_With_Trash_Penalty AS FLOAT) / NULLIF(CAST(adl.Total_Sold AS FLOAT), 0) [avg_Accumulated_Days_With_Trash_Penalty_R42],
	ba.Date_Generated
INTO #LocBuyGrades
FROM Sandbox..BuyAlgorithm_V1_R4_190401 ba
	INNER JOIN Sandbox..BuyAlgorithm_AggregateData_Location_190401 adl
		ON ba.CatalogID = adl.CatalogID
		AND ba.LocationNo = adl.LocationNo
	--INNER JOIN Catalog..titles t
	--	ON ba.CatalogID = t.catalogId
	--INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt40
	--	ON CAST(adl.Total_Accumulated_Days_With_Trash_Penalty AS FLOAT) / NULLIF(CAST(adl.Total_Item_Count AS FLOAT), 0) > bt40.AccDaysRangeFrom
	--	AND CAST(adl.Total_Accumulated_Days_With_Trash_Penalty AS FLOAT) / NULLIF(CAST(adl.Total_Item_Count AS FLOAT), 0) <= bt40.AccDaysRangeFrom
	--	AND (CASE WHEN t.binding IN ('Mass Market Paperback', 'CD', 'Audio CD') THEN t.binding ELSE 'General' END) = bt40.CatalogBinding
WHERE ba.LocationNo IS NOT NULL


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
	SUM(ada.Item_Acc_Days_TrashPenalty_R40) [Catalog_AccDays_TrashPenalty_R40],
	SUM(ada.Item_Acc_Days_NR) [Catalog_AccDays_NR],
	CAST(SUM(ada.Item_Acc_Days_NR) AS FLOAT) /
		NULLIF(CAST(COUNT(ada.ItemCode) AS FLOAT), 0) [avg_CatalogAccDays_NR],
	CAST(SUM(ada.Item_Acc_Days_TrashPenalty_R40) AS FLOAT) /
		NULLIF(CAST(COUNT(ada.ItemCode) AS FLOAT), 0) [avg_CatalogAccDays_TrashPenalty_R40],
	CAST(SUM(ada.Item_Acc_Days_TrashPenalty_R40) AS FLOAT) /
		NULLIF(CAST((COUNT(ada.Sale_Price) + 1) AS FLOAT), 0) [avg_CatalogAccDays_TrashPenalty_R42],
	AVG(ada.Sale_Price) [avg_SalePrice],
	AVG(cbg.avg_Accumulated_Days_With_Trash_Penalty_R40 - ada.Item_Acc_Days_TrashPenalty_R40) [avg_ChainError],
	AVG(lbg.avg_Accumulated_Days_With_Trash_Penalty_R40 - ada.Item_Acc_Days_TrashPenalty_R40) [avg_LocError],
	AVG(POWER(cbg.avg_Accumulated_Days_With_Trash_Penalty_R40 - ada.Item_Acc_Days_TrashPenalty_R40, 2.0)) [avg_ChainErrorSquared],
	AVG(POWER(lbg.avg_Accumulated_Days_With_Trash_Penalty_R40 - ada.Item_Acc_Days_TrashPenalty_R40, 2.0)) [avg_LocErrorSquared]
INTO #CatalogDayAccumulation
FROM #ActualDayAccumulation ada
	INNER JOIN #ChainBuyGrades cbg
		ON ada.CatalogID = cbg.CatalogID
	LEFT OUTER JOIN #LocBuyGrades lbg
		ON ada.CatalogID = lbg.CatalogID
		AND ada.LocationNo = lbg.LocationNo
GROUP BY CUBE(ada.LocationNo), ada.CatalogID, ada.CatalogBinding

SELECT
	cda.LocationNo,
	cda.CatalogID,
	cda.CatalogBinding,
	cda.first_CatalogRecordDate,
	cda.count_ItemsPriced,
	cda.count_ItemsSold,
	cda.avg_CatalogAccDays_NR,
	cda.avg_CatalogAccDays_TrashPenalty_R40,
	cda.avg_CatalogAccDays_TrashPenalty_R42,
	cda.avg_SalePrice,
	cda.avg_ChainError [avg_Error],
	cda.avg_ChainErrorSquared [avg_ErrorSquared],
	bt40.BuyGradeName [BuyGradeName_R40],
	bt40.BuyOfferPct [BuyOfferPct_R40],
	bt40.BuyOfferPct * cda.avg_SalePrice [BuyOfferAmt_R40],
	bt42.BuyGradeName [BuyGradeName_R42],
	bt42.BuyOfferPct [BuyOfferPct_R42],
	bt42.BuyOfferPct * cda.avg_SalePrice [BuyOfferAmt_R42]
INTO #ChainActualGrades
FROM #CatalogDayAccumulation cda
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt40
		ON cda.CatalogBinding = bt40.CatalogBinding
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 > bt40.AccDaysRangeFrom
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 <= bt40.AccDaysRangeTo
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 bt42
		ON cda.CatalogBinding = bt42.CatalogBinding
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 > bt42.AccDaysRangeFrom
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 <= bt42.AccDaysRangeTo
WHERE LocationNo = 'Chain'

SELECT
	cda.LocationNo,
	cda.CatalogID,
	cda.CatalogBinding,
	cda.first_CatalogRecordDate,
	cda.count_ItemsPriced,
	cda.count_ItemsSold,
	cda.avg_CatalogAccDays_NR,
	cda.avg_CatalogAccDays_TrashPenalty_R40,
	cda.avg_CatalogAccDays_TrashPenalty_R42,
	cda.avg_SalePrice,
	cda.avg_LocError [avg_Error],
	cda.avg_LocErrorSquared [avg_ErrorSquared],
	bt40.BuyGradeName [BuyGradeName_R40],
	bt40.BuyOfferPct [BuyOfferPct_R40],
	bt40.BuyOfferPct * cda.avg_SalePrice [BuyOfferAmt_R40],
	bt42.BuyGradeName [BuyGradeName_R42],
	bt42.BuyOfferPct [BuyOfferPct_R42],
	bt42.BuyOfferPct * cda.avg_SalePrice [BuyOfferAmt_R42]
INTO #LocationActualGrades
FROM #CatalogDayAccumulation cda
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt40
		ON cda.CatalogBinding = bt40.CatalogBinding
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 > bt40.AccDaysRangeFrom
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 <= bt40.AccDaysRangeTo
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 bt42
		ON cda.CatalogBinding = bt42.CatalogBinding
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 > bt42.AccDaysRangeFrom
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 <= bt42.AccDaysRangeTo
WHERE LocationNo <> 'Chain'



--DROP TABLE #ActualDayAccumulation
--DROP TABLE #CatalogDayAccumulation

/**************************
Step 2: Evaluate algorithm offer percentage for each catalogID priced between StartDate and EndDate
**************************/



SELECT 
	ca.LocationNo,
	ca.CatalogID,
	ca.CatalogBinding,
	ca.count_ItemsPriced,
	ca.count_ItemsSold,
	ca.avg_CatalogAccDays_NR,
	ca.avg_CatalogAccDays_TrashPenalty_R40,
	ca.avg_CatalogAccDays_TrashPenalty_R42,
	ca.avg_SalePrice [actual_AvgSalePrice],
	ca.avg_Error,
	ca.avg_ErrorSquared,
	ca.BuyGradeName_R40 [actual_BuyGradeName_R40],
	ca.BuyOfferPct_R40 [actual_BuyOfferPct_R40],
	ca.BuyOfferAmt_R40 [actual_BuyOfferAmt_R40],
	ca.BuyGradeName_R42 [actual_BuyGradeName_R42],
	ca.BuyOfferPct_R42 [actual_BuyOfferPct_R42],
	ca.BuyOfferAmt_R42 [actual_BuyOfferAmt_R42],
	cbg.Chain_Avg_Sale_Price [pred_AvgSalePrice],
	cbg.Chain_Buy_Offer_Pct [pred_BuyOfferPct_R40],
	cbg.avg_Accumulated_Days_With_Trash_Penalty_R40 [pred_AAD_R40],
	cbg.avg_Accumulated_Days_With_Trash_Penalty_R42 [pred_AAD_R42],
	cbg.Chain_SuggestedOffer [pred_SuggestedOffer_R40],
	cbg.Date_Generated
--INTO #ChainPredictions
FROM #ChainActualGrades ca
	INNER JOIN #ChainBuyGrades cbg
		ON ca.CatalogID = cbg.CatalogID
--ORDER BY ca.count_ItemsPriced DESC, BuyOfferPct_R40 DESC
UNION
SELECT 
	la.LocationNo,
	la.CatalogID,
	la.CatalogBinding,
	la.count_ItemsPriced,
	la.count_ItemsSold,
	la.avg_CatalogAccDays_NR,
	la.avg_CatalogAccDays_TrashPenalty_R40,
	la.avg_CatalogAccDays_TrashPenalty_R42,
	la.avg_SalePrice [actual_AvgSalePrice],
	la.avg_Error,
	la.avg_ErrorSquared,
	la.BuyGradeName_R40 [actual_BuyGradeName_R40],
	la.BuyOfferPct_R40 [actual_BuyOfferPct_R40],
	la.BuyOfferAmt_R40 [actual_BuyOfferAmt_R40],
	lbg.Location_Avg_Sale_Price [pred_AvgSalePrice],
	lbg.Location_Buy_Offer_Pct [pred_BuyOfferPct_R40],
	lbg.avg_Accumulated_Days_With_Trash_Penalty_R40 [pred_AAD_R40],
	lbg.avg_Accumulated_Days_With_Trash_Penalty_R42 [pred_AAD_R42],
	lbg.Location_SuggestedOffer [pred_SuggestedOffer_R40],
	lbg.Date_Generated
--INTO #LocPredictions
FROM #LocationActualGrades la
	LEFT OUTER JOIN #LocBuyGrades lbg
		ON la.CatalogID = lbg.CatalogID
		AND la.LocationNo = lbg.LocationNo
--ORDER BY la.count_ItemsPriced DESC, la.BuyOfferPct_R40 DESC




DROP TABLE #CatalogDayAccumulation
DROP TABLE #ActualDayAccumulation
DROP TABLE #ChainActualGrades
DROP TABLE #LocationActualGrades
DROP TABLE #ChainBuyGrades
DROP TABLE #LocBuyGrades
--DROP TABLE #ChainPredictions
--DROP TABLE #LocPredictions
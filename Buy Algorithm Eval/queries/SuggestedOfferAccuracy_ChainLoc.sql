DECLARE @StartDate DATE 
DECLARE @EndDate DATE --= '10/15/19'


/**************************
Step 0: Set StartDate and EndDate parameter values based on beginning of offer pct tracking and the latest
ItemCode_LifeCycle update.
**************************/
--Find first algorithm generation date that has associated offer percentages, set as start date
SELECT 
	@StartDate = MIN(ba.Date_Generated)
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
WHERE ba.Chain_Buy_Offer_Pct IS NOT NULL

----Find last date in ItemCode_LifeCycle table, set 31 days prior as end date to give at least "B" merchandise a full chance to sell
SELECT 
	@EndDate = DATEADD(DAY, -31, MAX(lc.Last_RecordDate))
FROM Buy_Analytics..ItemCode_LifeCycle lc



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
	SUM(ada.Item_Acc_Days_TrashPenalty_R40) [Catalog_AccDays_TrashPenalty_R40],
	SUM(ada.Item_Acc_Days_NR) [Catalog_AccDays_NR],
	CAST(SUM(ada.Item_Acc_Days_NR) AS FLOAT) /
		NULLIF(CAST(COUNT(ada.ItemCode) AS FLOAT), 0) [avg_CatalogAccDays_NR],
	CAST(SUM(ada.Item_Acc_Days_TrashPenalty_R40) AS FLOAT) /
		NULLIF(CAST(COUNT(ada.ItemCode) AS FLOAT), 0) [avg_CatalogAccDays_TrashPenalty_R40],
	CAST(SUM(ada.Item_Acc_Days_TrashPenalty_R40) AS FLOAT) /
		NULLIF(CAST((COUNT(ada.Sale_Price) + 1) AS FLOAT), 0) [avg_CatalogAccDays_TrashPenalty_R41],
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
	cda.avg_CatalogAccDays_NR,
	cda.avg_CatalogAccDays_TrashPenalty_R40,
	cda.avg_CatalogAccDays_TrashPenalty_R41,
	cda.avg_SalePrice,
	bt40.BuyGradeName [BuyGradeName_R40],
	bt40.BuyOfferPct [BuyOfferPct_R40],
	bt40.BuyOfferPct * cda.avg_SalePrice [BuyOfferAmt_R40]
INTO #ChainActualGrades
FROM #CatalogDayAccumulation cda
	INNER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt40
		ON cda.CatalogBinding = bt40.CatalogBinding
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 > bt40.AccDaysRangeFrom
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 <= bt40.AccDaysRangeTo
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
	cda.avg_CatalogAccDays_TrashPenalty_R41,
	cda.avg_SalePrice,
	bt40.BuyGradeName [BuyGradeName_R40],
	bt40.BuyOfferPct [BuyOfferPct_R40],
	bt40.BuyOfferPct * cda.avg_SalePrice [BuyOfferAmt_R40]
INTO #LocationActualGrades
FROM #CatalogDayAccumulation cda
	INNER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt40
		ON cda.CatalogBinding = bt40.CatalogBinding
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 > bt40.AccDaysRangeFrom
		AND cda.avg_CatalogAccDays_TrashPenalty_R40 <= bt40.AccDaysRangeTo
WHERE LocationNo <> 'Chain'



--DROP TABLE #ActualDayAccumulation
--DROP TABLE #CatalogDayAccumulation

/**************************
Step 2: Evaluate algorithm offer percentage for each catalogID priced between StartDate and EndDate
**************************/
--Get all chain-level offers generated between start date and end date
--Get all chain-level offers generated between start date and end date
SELECT DISTINCT
	ba.CatalogID,
	ba.Chain_Buy_Offer_Pct,
	ba.Chain_Avg_Sale_Price,
	ba.Chain_SuggestedOffer,
	ba.Date_Generated
INTO #ChainBuyGrades
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
WHERE ba.Date_Generated >= @StartDate
	AND ba.Date_Generated < @EndDate

--Get all location-level offers generated between start date and end date
SELECT
	ba.CatalogID,
	ba.LocationNo,
	ba.Location_Buy_Offer_Pct,
	ISNULL(ba.Location_Avg_Sale_Price, ba.Chain_Avg_Sale_Price) [Location_Avg_Sale_Price],
	ba.Location_SuggestedOffer,
	ba.Date_Generated
INTO #LocBuyGrades
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
WHERE ba.Date_Generated >=  @StartDate
	AND ba.Date_Generated < @EndDate
	AND ba.LocationNo IS NOT NULL

--SELECT COUNT(CatalogID) FROM #ChainBuyGrades

--SELECT COUNT(DISTINCT CatalogID) FROM #LocBuyGrades


--Organize algorthim generations by date ranges
SELECT
	cba.CatalogID,
	cba.Date_Generated [from_GenDate],
	LEAD(cba.Date_Generated, 1, DATEADD(DAY, 7, cba.Date_Generated)) OVER (PARTITION BY cba.CatalogID ORDER BY cba.Date_Generated) [to_GenDate]
INTO #ChainBuyAlgorithmDates
FROM #ChainBuyGrades cba

SELECT
	lba.LocationNo,
	lba.CatalogID,
	lba.Date_Generated [from_GenDate],
	LEAD(lba.Date_Generated, 1, DATEADD(DAY, 7, lba.Date_Generated)) OVER (PARTITION BY lba.CatalogID ORDER BY lba.Date_Generated) [to_GenDate]
INTO #LocBuyAlgorithmDates
FROM #LocBuyGrades lba


SELECT 
	ca.LocationNo,
	ca.CatalogID,
	ca.CatalogBinding,
	ca.count_ItemsPriced,
	ca.count_ItemsSold,
	ca.avg_CatalogAccDays_NR,
	ca.avg_CatalogAccDays_TrashPenalty_R40,
	ca.avg_CatalogAccDays_TrashPenalty_R41,
	ca.avg_SalePrice [actual_AvgSalePrice],
	ca.BuyGradeName_R40 [actual_BuyGradeName_R40],
	ca.BuyOfferPct_R40 [actual_BuyOfferPct_R40],
	ca.BuyOfferAmt_R40 [actual_BuyOfferAmt_R40],
	cbg.Chain_Avg_Sale_Price [pred_AvgSalePrice],
	cbg.Chain_Buy_Offer_Pct [pred_BuyOfferPct_R40],
	cbg.Chain_SuggestedOffer [pred_SuggestedOffer_R40],
	cbg.Date_Generated
--INTO #ChainPredictions
FROM #ChainActualGrades ca
	INNER JOIN #ChainBuyAlgorithmDates cad
		ON ca.CatalogID = cad.CatalogID
		AND	ca.first_CatalogRecordDate > cad.from_GenDate
		AND ca.first_CatalogRecordDate <= cad.to_GenDate
	INNER JOIN #ChainBuyGrades cbg
		ON ca.CatalogID = cbg.CatalogID
		AND cad.from_GenDate = cbg.Date_Generated
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
	la.avg_CatalogAccDays_TrashPenalty_R41,
	la.avg_SalePrice [actual_AvgSalePrice],
	la.BuyGradeName_R40 [actual_BuyGradeName_R40],
	la.BuyOfferPct_R40 [actual_BuyOfferPct_R40],
	la.BuyOfferAmt_R40 [actual_BuyOfferAmt_R40],
	lbg.Location_Avg_Sale_Price [pred_AvgSalePrice],
	lbg.Location_Buy_Offer_Pct [pred_BuyOfferPct_R40],
	lbg.Location_SuggestedOffer [pred_SuggestedOffer_R40],
	lbg.Date_Generated
--INTO #LocPredictions
FROM #LocationActualGrades la
	INNER JOIN #LocBuyAlgorithmDates lad
		ON la.CatalogID = lad.CatalogID
		AND la.LocationNo = lad.LocationNo
		AND	la.first_CatalogRecordDate > lad.from_GenDate
		AND la.first_CatalogRecordDate <= lad.to_GenDate
	LEFT OUTER JOIN #LocBuyGrades lbg
		ON la.CatalogID = lbg.CatalogID
		AND la.LocationNo = lbg.LocationNo
		AND lad.from_GenDate = lbg.Date_Generated
--ORDER BY la.count_ItemsPriced DESC, la.BuyOfferPct_R40 DESC



	

DROP TABLE #CatalogDayAccumulation
DROP TABLE #ChainActualGrades
DROP TABLE #LocationActualGrades
DROP TABLE #ChainBuyAlgorithmDates
DROP TABLE #LocBuyAlgorithmDates
DROP TABLE #ChainBuyGrades
DROP TABLE #LocBuyGrades
--DROP TABLE #ChainPredictions
--DROP TABLE #LocPredictions
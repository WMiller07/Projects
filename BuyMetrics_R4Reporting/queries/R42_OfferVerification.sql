DECLARE @StartDate DATE 
DECLARE @EndDate DATE = '12/2/2019'

SELECT
	@StartDate = DATEADD(MONTH, -13, @EndDate)


SELECT 
	pu.CatalogID,
	pu.ISBN,
	pu.Title,
	SUM((CASE
			WHEN lc.Days_Scanned = 0 
			THEN lc.Days_Salable_Priced 
			ELSE lc.Days_Salable_Scanned END) +
		(CASE 
			WHEN lc.Current_Item_Status in ('T', 'D') 
			AND (datediff(day, lc.First_RecordDate,  lc.Last_TransferDate) >= 7 
				OR datediff(hour, lc.First_ScanDate,  lc.Last_TransferDate) >= 24) 
			THEN 181
			ELSE 0 END)) [Total_Accumulated_Days_With_Trash_Penalty],	
	SUM(CASE
			WHEN lc.LastEventType = 5
			THEN 1
			ELSE 0
			END) [Total_Sold],
	SUM(CASE
			WHEN lc.LifeCycle_Complete = 0
			THEN 1
			ELSE 0
			END) [Total_Available],
	SUM(CASE 
			WHEN lc.Current_Item_Status IN ('T', 'D')
			THEN 1
			ELSE 0
			END) [Total_Trash_Donate],
	COUNT(lc.ItemCode) [Total_Items],
	AVG(lc.Sale_Price) [Avg_Sale_Price],
	SUM((CASE
			WHEN lc.Days_Scanned = 0 
			THEN lc.Days_Salable_Priced 
			ELSE lc.Days_Salable_Scanned END) +
			(CASE 
				WHEN lc.Current_Item_Status in ('T', 'D') 
				AND (datediff(day, lc.First_RecordDate,  lc.Last_TransferDate) >= 7 
					OR datediff(hour, lc.First_ScanDate,  lc.Last_TransferDate) >= 24) 
				THEN 181
				ELSE 0 END)) /
			CAST(COUNT(lc.ItemCode) AS FLOAT) [avg_AccumulatedDaysTrashPenalty_R40],
	SUM((CASE
			WHEN lc.Days_Scanned = 0 
			THEN lc.Days_Salable_Priced 
			ELSE lc.Days_Salable_Scanned END) +
		(CASE 
			WHEN lc.Current_Item_Status in ('T', 'D') 
			AND (datediff(day, lc.First_RecordDate,  lc.Last_TransferDate) >= 7 
				OR datediff(hour, lc.First_ScanDate,  lc.Last_TransferDate) >= 24) 
			THEN 181
			ELSE 0 END)) /
		 (SUM(
			 CASE
				WHEN lc.LastEventType = 5
				THEN 1
				ELSE 0
				END) + 1) [avg_AccumulatedDaysTrashPenalty_R42]
INTO #ProductsLifeCycle
FROM Base_Analytics..Products_Used pu
	INNER JOIN Data_Extracts..ItemCode_LifeCycle lc
		ON pu.ItemCode = lc.ItemCode
WHERE pu.CatalogID IN ('2239921', '4502062', '13656244', '659447')
	--pu.ISBN IN ('9780316018746', '9780316018708', '9780316211222', '9781503900837') --Subbed CatalogIDs instead once they were found, as the search time for ISBNs is far larger.
	AND pu.LocationNo = '00116'
	AND ISNULL(lc.Last_ScanDate, lc.First_RecordDate) >= @StartDate
	AND ISNULL(lc.Last_ScanDate, lc.First_RecordDate) < @EndDate
GROUP BY pu.CatalogID, pu.ISBN, pu.Title

SELECT
	plc.CatalogID,
	MAX(ba40.Date_Generated) [last_GenDate_r40],
	MAX(ba42.Date_Generated) [last_GenDate_r42]
INTO #LastGenDates
FROM #ProductsLifeCycle plc
	INNER JOIN Buy_Analytics..BuyAlgorithm_V1_R4 ba40
		ON plc.CatalogId = ba40.CatalogID
		AND ba40.LocationNo = '00116'
	INNER JOIN Buy_Analytics..BuyAlgorithm_V1_R42 ba42
		ON plc.CatalogId = ba42.CatalogID
		AND ba42.LocationNo = '00116'
GROUP BY plc.CatalogId 

SELECT 
	plc.CatalogId,
	plc.ISBN,
	plc.Title,
	plc.Total_Accumulated_Days_With_Trash_Penalty,
	plc.Total_Available,
	plc.Total_Sold,
	plc.Total_Trash_Donate,
	plc.Total_Items,
	plc.avg_AccumulatedDaysTrashPenalty_R40,
	plc.avg_AccumulatedDaysTrashPenalty_R42,
	ba40.Chain_Buy_Offer_Pct [Chain_BuyOfferPct_r40],
	ba42.Chain_Buy_Offer_Pct [Chain_BuyOfferPct_r42],
	ba40.Chain_SuggestedOffer [Chain_SuggestedOffer_r40],
	ba42.Chain_SuggestedOffer [Chain_SuggestedOffer_r42],
	ba40.Location_Buy_Offer_Pct [Location_BuyOfferPct_r40],
	ba42.Location_Buy_Offer_Pct [Location_BuyOfferPct_r42],
	ba40.Location_SuggestedOffer [Location_SuggestedOffer_r40],
	ba42.Location_SuggestedOffer [Location_SuggestedOffer_r42],
	bt40.BuyOfferPct [BuyOfferPct_r40], --* ISNULL(plc.Avg_Sale_Price, ba40.Chain_Avg_Sale_Price) [Location_SuggestedOffer_r40_recalculated],
	bt42.BuyOfferPct [BuyOfferPct_R42], --* ISNULL(plc.Avg_Sale_Price, ba42.Chain_Avg_Sale_Price) [Location_SuggestedOffer_r42_recalculated]
	bt40.BuyOfferPct * ISNULL(plc.Avg_Sale_Price, ba40.Chain_Avg_Sale_Price) [Location_SuggestedOffer_r40_recalculated],
	bt42.BuyOfferPct * ISNULL(plc.Avg_Sale_Price, ba42.Chain_Avg_Sale_Price) [Location_SuggestedOffer_r42_recalculated]
FROM #ProductsLifeCycle plc
	INNER JOIN #LastGenDates lgd
		ON plc.CatalogId = lgd.CatalogId
	INNER JOIN Buy_Analytics..BuyAlgorithm_V1_R4 ba40
		ON plc.CatalogId = ba40.CatalogID
		AND lgd.last_GenDate_r40 = ba40.Date_Generated
		AND ba40.LocationNo = '00116'
	INNER JOIN Buy_Analytics..BuyAlgorithm_V1_R42 ba42
		ON plc.CatalogId = ba42.CatalogID
		AND lgd.last_GenDate_r42 = ba42.Date_Generated
		AND ba42.LocationNo = '00116'
	INNER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 bt40
		ON plc.avg_AccumulatedDaysTrashPenalty_R40 > bt40.AccDaysRangeFrom
		AND plc.avg_AccumulatedDaysTrashPenalty_R40 <= bt40.AccDaysRangeTo
		AND bt40.CatalogBinding = 'General' --all problem CatalogIDs reported were of "General" CatalogBinding, so defaulting to that
	INNER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R42 bt42
		ON plc.avg_AccumulatedDaysTrashPenalty_R42 > bt42.AccDaysRangeFrom
		AND plc.avg_AccumulatedDaysTrashPenalty_R42 <= bt42.AccDaysRangeTo
		AND bt42.CatalogBinding = 'General' --all problem CatalogIDs reported were of "General" CatalogBinding, so defaulting to that

DROP TABLE #ProductsLifeCycle
DROP TABLE #LastGenDates
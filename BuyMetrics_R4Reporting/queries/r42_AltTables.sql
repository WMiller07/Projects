DECLARE @StartDate DATE = '9/1/2019'
DECLARE @EndDate DATE = '10/1/2019'

SELECT 
	bbi.LocationNo,
	bbi.CatalogID,
	CASE 
		WHEN t.binding IN ('Audio CD', 'CD', 'Mass Market Paperbacks')
		THEN t.binding
		ELSE 'General'
		END [CatalogBinding],
	bbi.Quantity,
	bbi.SuggestedOffer
INTO #BuyItems
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN Catalog..titles t
		ON bbi.CatalogID = t.catalogId

WHERE bbh.StatusCode = 1
	AND bbi.StatusCode = 1
	AND bbi.Quantity > 0
	AND bbi.Scoring_ID IS NOT NULL
	AND bbh.CreateTime >= @StartDate
	AND bbh.CreateTime < @EndDate




SELECT 
	bi.LocationNo,
	SUM(cbt13.BuyOfferPct * adc.Avg_Sale_Price) [Total_Cost],
	SUM(lbt13.BuyOfferPct * COALESCE(adl.Avg_Sale_Price, adc.Avg_Sale_Price)) [loc_Total_Cost],
	SUM(lbt3.BuyOfferPct * COALESCE(a23.Avg_Sale_Price, adl.Avg_Sale_Price, adc.Avg_Sale_Price)) [loc3mo_Total_Cost]
FROM #BuyItems bi
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Chain adc
		ON bi.CatalogID = adc.CatalogID
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Location adl
		ON bi.LocationNo = adl.LocationNo
		AND bi.CatalogID = adl.CatalogID
	LEFT OUTER JOIN Sandbox..BuyAlgorithm_AggregateData_Location_2Items3Mo a23
		ON adl.LocationNo = a23.LocationNo
		AND adl.CatalogID = a23.CatalogID
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 lbt3
		ON  bi.CatalogBinding = lbt3.CatalogBinding
		AND CAST((a23.Total_Accumulated_Days_With_Trash_Penalty * (CASE WHEN a23.Total_Available = 0 THEN 1 ELSE a23.Total_Available END)) / (a23.Total_Sold + 1) AS DECIMAL(18, 2)) > lbt3.AccDaysRangeFrom
		AND CAST((a23.Total_Accumulated_Days_With_Trash_Penalty * (CASE WHEN a23.Total_Available = 0 THEN 1 ELSE a23.Total_Available END)) / (a23.Total_Sold + 1) AS DECIMAL(18, 2)) <= lbt3.AccDaysRangeTo
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 lbt13
		ON  bi.CatalogBinding = lbt13.CatalogBinding
		AND CAST((adl.Total_Accumulated_Days_With_Trash_Penalty) / (adl.Total_Sold + 1) AS DECIMAL(18, 2)) > lbt13.AccDaysRangeFrom
		AND CAST((adl.Total_Accumulated_Days_With_Trash_Penalty) / (adl.Total_Sold + 1) AS DECIMAL(18, 2)) <= lbt13.AccDaysRangeTo
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 cbt13
		ON  bi.CatalogBinding = cbt13.CatalogBinding
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty) / (adc.Total_Sold + 1) AS DECIMAL(18, 2)) > cbt13.AccDaysRangeFrom
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty) / (adc.Total_Sold + 1) AS DECIMAL(18, 2)) <= cbt13.AccDaysRangeTo
WHERE a23.CatalogID IS NOT NULL
GROUP BY bi.LocationNo WITH ROLLUP

SELECT 
	bi.LocationNo,
	bi.CatalogID,
	SUM(cbt13.BuyOfferPct * adc.Avg_Sale_Price) [Total_Chain_Cost],
	AVG(cbt13.BuyOfferPct * adc.Avg_Sale_Price) [avg_Chain_Cost],
	SUM(lbt13.BuyOfferPct * COALESCE(adl.Avg_Sale_Price, adc.Avg_Sale_Price)) [loc_Total_Cost],
	AVG(lbt13.BuyOfferPct * COALESCE(adl.Avg_Sale_Price, adc.Avg_Sale_Price)) [avg_Loc__Cost],
	SUM(lbt3.BuyOfferPct * COALESCE(a23.Avg_Sale_Price, adl.Avg_Sale_Price, adc.Avg_Sale_Price)) [loc3mo_Total_Cost],
	AVG(lbt3.BuyOfferPct * COALESCE(a23.Avg_Sale_Price, adl.Avg_Sale_Price, adc.Avg_Sale_Price)) [avg_Loc3mo_Cost],
	MIN(a23.Total_Available) [loc_TotalAvailable]
FROM #BuyItems bi
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Chain adc
		ON bi.CatalogID = adc.CatalogID
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Location adl
		ON bi.LocationNo = adl.LocationNo
		AND bi.CatalogID = adl.CatalogID
	LEFT OUTER JOIN Sandbox..BuyAlgorithm_AggregateData_Location_2Items3Mo a23
		ON adl.LocationNo = a23.LocationNo
		AND adl.CatalogID = a23.CatalogID
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 lbt3
		ON  bi.CatalogBinding = lbt3.CatalogBinding
		AND CAST((a23.Total_Accumulated_Days_With_Trash_Penalty * (CASE WHEN a23.Total_Available = 0 THEN 1 ELSE a23.Total_Available END)) / (a23.Total_Sold + 1) AS DECIMAL(18, 2)) > lbt3.AccDaysRangeFrom
		AND CAST((a23.Total_Accumulated_Days_With_Trash_Penalty * (CASE WHEN a23.Total_Available = 0 THEN 1 ELSE a23.Total_Available END)) / (a23.Total_Sold + 1) AS DECIMAL(18, 2)) <= lbt3.AccDaysRangeTo
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 lbt13
		ON  bi.CatalogBinding = lbt13.CatalogBinding
		AND CAST((adl.Total_Accumulated_Days_With_Trash_Penalty) / (adl.Total_Sold + 1) AS DECIMAL(18, 2)) > lbt13.AccDaysRangeFrom
		AND CAST((adl.Total_Accumulated_Days_With_Trash_Penalty) / (adl.Total_Sold + 1) AS DECIMAL(18, 2)) <= lbt13.AccDaysRangeTo
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 cbt13
		ON  bi.CatalogBinding = cbt13.CatalogBinding
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty) / (adc.Total_Sold + 1) AS DECIMAL(18, 2)) > cbt13.AccDaysRangeFrom
		AND CAST((adc.Total_Accumulated_Days_With_Trash_Penalty) / (adc.Total_Sold + 1) AS DECIMAL(18, 2)) <= cbt13.AccDaysRangeTo
WHERE a23.CatalogID IS NOT NULL
GROUP BY bi.LocationNo, bi.CatalogID
ORDER BY LocationNo, loc_TotalAvailable DESC

DROP TABLE #BuyItems
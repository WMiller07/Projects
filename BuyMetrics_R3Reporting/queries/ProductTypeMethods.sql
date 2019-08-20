-- Get buy data set consisting of all suggested offer IDs and suggester offer amounts by product type for each location.
SELECT 
	bbh.LocationNo,
	bbh.BuyBinNo,
	bbi.ItemLineNo,
	bt.BuyType [ProductType_User],
	CASE
		WHEN ot4.CatalogBinding = 'Mass Market Paperback'
			THEN 'PB'
		WHEN ot4.CatalogBinding IN ('CD', 'Audio CD')
			THEN 'CDU'
		ELSE bt.BuyType
		END [ProductType_Catalog],
	ot4.CatalogBinding,
	bbi.Scoring_ID,
	bbi.CatalogID,
	bbi.SipsID,
	bbi.ISBN,
	ba.ListPrice,
	bbi.SuggestedOffer,
	bbi.SuggestedOfferType,
	bbi.Quantity
INTO #R3Offers
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN BUYS..BuyTypes bt
		ON bbi.BuyTypeID = bt.BuyTypeID
	INNER JOIN Sandbox..BuyAlgorithm_V1_R3 ba
		ON bbi.Scoring_ID = ba.OfferID
	LEFT OUTER JOIN Catalog..Titles t
		ON bbi.CatalogID = t.catalogId
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 ot4
		ON LTRIM(RTRIM(t.binding)) = LTRIM(RTRIM(ot4.CatalogBinding))
		AND ot4.BuyGradeName = 'A'
WHERE 
	bbh.StatusCode = 1 AND
	bbi.SuggestedOfferVersion = 'v1.r3' AND 
	bbi.CatalogID IS NOT NULL 


--Get most recently generated buy offers for all R3 offers, first for location offers, then chain offers
SELECT 
	ba.CatalogID,
	ba.LocationNo,
	ba.Location_SuggestedOffer,
	ba.Date_Generated,
	ba.ListPrice
INTO #R3LastLocOffers 
FROM Sandbox..BuyAlgorithm_V1_R3 ba
	INNER JOIN (
		SELECT 
			CatalogID,
			LocationNo,
			MAX(Date_Generated) [Date_Generated]
		FROM Sandbox..BuyAlgorithm_V1_R3
		GROUP BY CatalogID, LocationNo) rl
			ON ba.CatalogID = rl.CatalogID
			AND ba.Date_Generated = rl.Date_Generated
			AND ba.LocationNo = rl.LocationNo

SELECT 
	ba.CatalogID,
	MIN(ba.ListPrice) [ListPrice],
	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer]
INTO #R3LastChainOffers 
FROM Sandbox..BuyAlgorithm_V1_R3 ba
	INNER JOIN (
		SELECT 
			CatalogID,
			MAX(Date_Generated) [Date_Generated]
		FROM Sandbox..BuyAlgorithm_V1_R3
		GROUP BY CatalogID) rl
			ON ba.CatalogID = rl.CatalogID
			AND ba.Date_Generated = rl.Date_Generated
GROUP BY ba.CatalogID

--Get most recently generated buy offers for all R4 offers, first for location offers, then chain offers
SELECT 
	ba.CatalogID,
	ba.LocationNo,
	ba.Location_SuggestedOffer,
	ba.Date_Generated,
	ba.ListPrice
INTO #R4LastLocOffers 
FROM Sandbox..BuyAlgorithm_V1_R4 ba
	INNER JOIN (
		SELECT 
			CatalogID,
			LocationNo,
			MAX(Date_Generated) [Date_Generated]
		FROM Sandbox..BuyAlgorithm_V1_R4
		GROUP BY CatalogID, LocationNo) rl
			ON ba.CatalogID = rl.CatalogID
			AND ba.Date_Generated = rl.Date_Generated
			AND ba.LocationNo = rl.LocationNo

SELECT 
	ba.CatalogID,
	MIN(ba.ListPrice) [ListPrice],
	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer]
INTO #R4LastChainOffers 
FROM Sandbox..BuyAlgorithm_V1_R4 ba
	INNER JOIN (
		SELECT 
			CatalogID,
			MAX(Date_Generated) [Date_Generated]
		FROM Sandbox..BuyAlgorithm_V1_R4
		GROUP BY CatalogID) rl
			ON ba.CatalogID = rl.CatalogID
			AND ba.Date_Generated = rl.Date_Generated
GROUP BY ba.CatalogID

SELECT DISTINCT
	r3o.LocationNo,
	r3o.BuyBinNo,
	r3o.ItemLineNo,
	r3o.ProductType_Catalog,
	r3o.ProductType_User,
	r3o.Scoring_ID,
	r3o.CatalogID,
	r3o.Quantity,
	r3o.ListPrice,
	r3o.SuggestedOffer [SuggestedOffer_R3],
	ISNULL(r3lo.Location_SuggestedOffer, r3co.Chain_SuggestedOffer) [SuggestedOffer_R3Update],
	ISNULL(r4lo.Location_SuggestedOffer, r4co.Chain_SuggestedOffer) [SuggestedOffer_R4],
	CASE 
		WHEN adl.LocationNo IS NULL 
		THEN CAST((ot.BuyOfferPct * adc.Avg_Sale_Price) AS decimal(19, 2)) 
		ELSE CAST((ot.BuyOfferPct * adl.Avg_Sale_Price) AS decimal(19, 2))
		END [SuggestedOffer_R3Calc],
	CASE 
		WHEN adl.LocationNo IS NULL 
		THEN CAST((ot4.BuyOfferPct * adc.Avg_Sale_Price) AS decimal(19, 2)) 
		ELSE CAST((ot4.BuyOfferPct * adl.Avg_Sale_Price) AS decimal(19, 2))
		END [SuggestedOffer_R4Calc],
	CASE 
		WHEN adl.LocationNo IS NULL 
		THEN ot.BuyOfferPct 
		END [Chain_BuyOfferPct],
	adc.Avg_Sale_Price [chain_AvgSalePrice],
	adc.Total_Accumulated_Days_With_Trash_Penalty/adc.Total_Item_Count [chain_DaysSalableScanned],
	CASE 
		WHEN adl.LocationNo IS NULL 
		THEN CAST((ot.BuyOfferPct * adc.Avg_Sale_Price) AS decimal(19, 2)) 
		END [SuggestedOffer_CalcChain],
	CASE 
		WHEN adl.LocationNo IS NOT NULL 
		THEN ot.BuyOfferPct 
		END [Loc_BuyOfferPct],
    adl.Avg_Sale_Price [loc_AvgSalePrice],
	adl.Total_Accumulated_Days_With_Trash_Penalty/adl.Total_Item_Count [loc_DaysSalableScanned],
	CASE 
		WHEN adl.LocationNo IS NOT NULL 
		THEN CAST((ot.BuyOfferPct * adl.Avg_Sale_Price) AS decimal(19, 2)) 
		END [SuggestedOffer_CalcLoc]
INTO #AlgorithmOffers
FROM #R3Offers r3o
	LEFT OUTER JOIN #R3LastLocOffers r3lo
		ON r3o.CatalogID = r3lo.CatalogID
		AND r3o.LocationNo = r3lo.LocationNo
	LEFT OUTER JOIN #R3LastChainOffers r3co
		ON r3o.CatalogID = r3co.CatalogID
	LEFT OUTER JOIN #R4LastLocOffers r4lo
		ON r3o.CatalogID = r4lo.CatalogID
		AND r3o.LocationNo = r4lo.LocationNo
	LEFT OUTER JOIN #R4LastChainOffers r4co
		ON r3o.CatalogID = r4co.CatalogID
	LEFT OUTER JOIN Sandbox..BuyAlgorithm_AggregateData_Chain adc
		ON r3o.CatalogID = adc.CatalogID
	LEFT OUTER JOIN Sandbox..BuyAlgorithm_AggregateData_Location adl
		ON r3o.CatalogID = adl.CatalogID
		AND r3o.LocationNo = adl.LocationNo
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R3 ot
		ON ISNULL(adl.Total_Accumulated_Days_With_Trash_Penalty/adl.Total_Item_Count, adc.Total_Accumulated_Days_With_Trash_Penalty/adc.Total_Item_Count) >= ot.AccDaysRangeFrom
		AND ISNULL(adl.Total_Accumulated_Days_With_Trash_Penalty/adl.Total_Item_Count, adc.Total_Accumulated_Days_With_Trash_Penalty/adc.Total_Item_Count) < ot.AccDaysRangeTo
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 ot4
		ON ISNULL(adl.Total_Accumulated_Days_With_Trash_Penalty/adl.Total_Item_Count, adc.Total_Accumulated_Days_With_Trash_Penalty/adc.Total_Item_Count) >= ot.AccDaysRangeFrom
		AND ISNULL(adl.Total_Accumulated_Days_With_Trash_Penalty/adl.Total_Item_Count, adc.Total_Accumulated_Days_With_Trash_Penalty/adc.Total_Item_Count) < ot.AccDaysRangeTo
		AND r3o.CatalogBinding = ot4.CatalogBinding
ORDER BY LocationNo, BuyBinNo, ItemLineNo

SELECT	
	SUM(ao.SuggestedOffer_R3)/SUM(ao.Quantity) [avg_R3SuggestedOffer],
	SUM(ao.SuggestedOffer_R3Update)/SUM(ao.Quantity) [avg_R3UpdateSuggestedOffer],
	SUM(ao.SuggestedOffer_R4)/SUM(ao.Quantity) [avg_R4SuggestedOffer],
	SUM(ao.SuggestedOffer_R3Calc)/SUM(ao.Quantity) [avg_R3CalcSuggestedOffer],
	SUM(ao.SuggestedOffer_R4Calc)/SUM(ao.Quantity) [avg_R4CalcSuggestedOffer]
FROM #AlgorithmOffers ao

SELECT	
	ao.ProductType_User,
	SUM(ao.Quantity) [Quantity],
	SUM(ao.SuggestedOffer_R3)/SUM(ao.Quantity) [avg_R3SuggestedOffer],
	SUM(ao.SuggestedOffer_R3Update)/SUM(ao.Quantity) [avg_R3UpdateSuggestedOffer],
	SUM(ao.SuggestedOffer_R4)/SUM(ao.Quantity) [avg_R4SuggestedOffer],
	SUM(ao.SuggestedOffer_R3Calc)/SUM(ao.Quantity) [avg_R3CalcSuggestedOffer],
	SUM(ao.SuggestedOffer_R4Calc)/SUM(ao.Quantity) [avg_R4CalcSuggestedOffer]
FROM #AlgorithmOffers ao
GROUP BY ao.ProductType_Catalog
ORDER BY Quantity DESC

SELECT	
	ao.ProductType_Catalog,
	SUM(ao.Quantity) [Quantity],
	SUM(ao.SuggestedOffer_R3)/SUM(ao.Quantity) [avg_R3SuggestedOffer],
	SUM(ao.SuggestedOffer_R3Update)/SUM(ao.Quantity) [avg_R3UpdateSuggestedOffer],
	SUM(ao.SuggestedOffer_R4)/SUM(ao.Quantity) [avg_R4SuggestedOffer],
	SUM(ao.SuggestedOffer_R3Calc)/SUM(ao.Quantity) [avg_R3CalcSuggestedOffer],
	SUM(ao.SuggestedOffer_R4Calc)/SUM(ao.Quantity) [avg_R4CalcSuggestedOffer]
FROM #AlgorithmOffers ao
GROUP BY ao.ProductType_Catalog
ORDER BY Quantity DESC


DROP TABLE #R3Offers
DROP TABLE #R3LastChainOffers
DROP TABLE #R3LastLocOffers
DROP TABLE #R4LastChainOffers
DROP TABLE #R4LastLocOffers
DROP TABLE #AlgorithmOffers

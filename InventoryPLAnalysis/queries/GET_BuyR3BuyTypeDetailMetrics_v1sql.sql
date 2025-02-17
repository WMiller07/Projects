SELECT 
	bt.BuyType,
	bt.BuyTypeID,
	ads.BuyGradeID,
	ads.BuyGradeName,
	ads.AccDaysRangeFrom,
	ads.AccDaysRangeTo,
	CASE
		WHEN bt.BuyType = 'CDU' AND ads.BuyGradeID = 3
			THEN 0.1000
		WHEN bt.BuyType = 'PB' AND ads.BuyGradeID = 1
			THEN 0.300
		WHEN bt.BuyType = 'PB' AND ads.BuyGradeID = 2
			THEN 0.200
		WHEN bt.BuyType = 'PB' AND ads.BuyGradeID = 3
			THEN 0.1000
		ELSE ads.BuyOfferPct
		END	[BuyOfferPct]
INTO #AdjOfferTable
FROM [Sandbox].[dbo].[AccumulatedDaysOnShelf_BuyTable_V1_R3] ads
	CROSS JOIN BUYS..BuyTypes bt

SELECT 
	bt.BuyType,
	spm.ProductType,
	t.binding,
	t.author,
	t.artist,
	t.title,
	t.isbn13,
	t.catalogId,
	bbi.Quantity,
	bbi.Offer,
	bbi.SuggestedOffer,
	bbi.SuggestedOfferType,
	CASE 
		WHEN bbi.SuggestedOfferType = 1
			THEN ROUND(bbi.SuggestedOffer / NULLIF(adc.Avg_Sale_Price, 0), 2)
		WHEN bbi.SuggestedOfferType = 2
			THEN ROUND(bbi.SuggestedOffer / NULLIF(adl.Avg_Sale_Price, 0), 2)
		END [calc_SuggestedOfferPct], --Calculate what percentage was actually paid per item in order to assess how many offers have changed as the offer tables have been updated.
	ot.BuyOfferPct [tab_SuggestedOfferPct],
	aot.BuyOfferPct [adj_SuggestedOfferPct],
	aot.BuyOfferPct * ISNULL(adl.Avg_Sale_Price, adc.Avg_Sale_Price) [adj_SuggestedOffer],
	bbi.CreateTime,
	bbi.Scoring_ID, 
	ba.Chain_SuggestedOffer,
	ba.Location_SuggestedOffer,
	adc.Total_Item_Count [Chain_Total_Item_Count],	
	adc.Total_Accumulated_Days_With_Trash_Penalty [Chain_Total_Accumulated_Days_With_Trash_Penalty],  	
	adc.Days_Total_FromCreate [Chain_Days_Total_FromCreate],	
	adc.Days_Total_Scanned [Chain_Days_Total_Scanned],	
	adc.Days_Total_Salable_Priced [Chain_Days_Total_Salable_Priced],	
	adc.Days_Total_Salable_Scanned [Chain_Days_Total_Salable_Scanned],	
	adc.Days_Total_Salable_Online [Chain_Days_Total_Salable_Online],	
	adc.Total_Transfers [Chain_Total_Transfers],	
	adc.Total_Trash_Donate [Chain_Total_Trash_Donate],	
	adc.Total_Sold [Chain_Total_Sold],	
	adc.Total_Available [Chain_Total_Available],	
	adc.Total_Scan_Count [Chain_Total_Scan_Count],	
	adc.Avg_Price [Chain_Avg_Price],	
	adc.Avg_Sale_Price [Chain_Avg_Sale_Price],		
	adc.Avg_Days_Priced_To_Sold [Chain_Avg_Days_Priced_To_Sold],
	adc.Total_Accumulated_Days_With_Trash_Penalty/NULLIF(adc.Total_Item_Count, 0) [Chain_Avg_Days_Scanned_To_Sold],
	adl.Total_Item_Count [Loc_Total_Item_Count],	
	adl.Total_Accumulated_Days_With_Trash_Penalty [Loc_Total_Accumulated_Days_With_Trash_Penalty],  	
	adl.Days_Total_FromCreate [Loc_Days_Total_FromCreate],	
	adl.Days_Total_Scanned [Loc_Days_Total_Scanned],	
	adl.Days_Total_Salable_Priced [Loc_Days_Total_Salable_Priced],	
	adl.Days_Total_Salable_Scanned [Loc_Days_Total_Salable_Scanned],	
	adl.Days_Total_Salable_Online [Loc_Days_Total_Salable_Online],	
	adl.Total_Transfers [Loc_Total_Transfers],	
	adl.Total_Trash_Donate [Loc_Total_Trash_Donate],	
	adl.Total_Sold [Loc_Total_Sold],	
	adl.Total_Available [Loc_Total_Available],	
	adl.Total_Scan_Count [Loc_Total_Scan_Count],	
	adl.Avg_Price [Loc_Avg_Price],	
	adl.Avg_Sale_Price [Loc_Avg_Sale_Price],		
	adl.Avg_Days_Priced_To_Sold [Loc_Avg_Days_Priced_To_Sold],
	adl.Total_Accumulated_Days_With_Trash_Penalty/NULLIF(adl.Total_Item_Count, 0) [Loc_Avg_Days_Scanned_To_Sold]
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.LocationNo = bbi.LocationNo
		AND bbh.BuyBinNo = bbi.BuyBinNo
	INNER JOIN BUYS..BuyTypes bt
		ON bbi.BuyTypeID = bt.BuyTypeID
	INNER JOIN Sandbox..BuyAlgorithm_V1_R3 ba
		ON bbi.Scoring_ID = ba.OfferID
	INNER JOIN Catalog..titles t
		ON bbi.CatalogID = t.catalogId
	LEFT OUTER JOIN ReportsData..SipsProductMaster spm
		ON bbi.SipsID = spm.SipsID
	LEFT OUTER JOIN Sandbox..BuyAlgorithm_AggregateData_Chain adc
		ON bbi.CatalogID = adc.CatalogID
	LEFT OUTER JOIN Sandbox..BuyAlgorithm_AggregateData_Location adl
		ON bbi.CatalogID = adl.CatalogID
		AND bbi.LocationNo = adl.LocationNo
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R3 ot
		ON	ISNULL(	adl.Total_Accumulated_Days_With_Trash_Penalty/NULLIF(adl.Total_Item_Count, 0), 
					adc.Total_Accumulated_Days_With_Trash_Penalty/NULLIF(adc.Total_Item_Count, 0)) >= ot.AccDaysRangeFrom AND
			ISNULL(	adl.Total_Accumulated_Days_With_Trash_Penalty/NULLIF(adl.Total_Item_Count, 0), 
					adc.Total_Accumulated_Days_With_Trash_Penalty/NULLIF(adc.Total_Item_Count, 0)) <= ot.AccDaysRangeTo	
	INNER JOIN #AdjOfferTable aot
		ON	ISNULL(	adl.Total_Accumulated_Days_With_Trash_Penalty/NULLIF(adl.Total_Item_Count, 0), 
					adc.Total_Accumulated_Days_With_Trash_Penalty/NULLIF(adc.Total_Item_Count, 0)) >= aot.AccDaysRangeFrom AND
			ISNULL(	adl.Total_Accumulated_Days_With_Trash_Penalty/NULLIF(adl.Total_Item_Count, 0), 
					adc.Total_Accumulated_Days_With_Trash_Penalty/NULLIF(adc.Total_Item_Count, 0)) <= aot.AccDaysRangeTo AND
			bt.BuyTypeID = aot.BuyTypeID
WHERE 
	bbi.SuggestedOfferVersion = 'V1.R3' AND
	bbh.StatusCode = 1 AND
	bbi.StatusCode = 1 AND
	bbi.Quantity > 0 AND
	bbi.Quantity < 10000 AND
	bbi.Offer < 10000 
ORDER BY bbh.LocationNo, bbh.CreateTime

DROP TABLE #AdjOfferTable
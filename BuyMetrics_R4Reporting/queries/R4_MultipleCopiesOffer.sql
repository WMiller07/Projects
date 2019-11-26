DECLARE @LastAlgorithmUpdate DATE

SELECT 
	@LastAlgorithmUpdate = MAX(Date_Generated) 
FROM Buy_Analytics..BuyAlgorithm_V1_R4
GROUP BY CatalogID

--Get most recently generated buy offers for all R4 offers, first for location offers, then chain offers
SELECT 
	ba.CatalogID,
	ba.LocationNo,
	ba.Location_SuggestedOffer,
	ba.Location_Buy_Offer_Pct,
	ba.Date_Generated,
	ba.ListPrice
INTO #R4LastLocOffers 
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
WHERE ba.Date_Generated = @LastAlgorithmUpdate

SELECT 
	ba.CatalogID,
	ba.Date_Generated,
	MIN(ba.Chain_Buy_Offer_Pct) [Chain_BuyOfferPct],
	MIN(ba.ListPrice) [ListPrice],
	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer]
INTO #R4LastChainOffers 
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
WHERE ba.Date_Generated = @LastAlgorithmUpdate
GROUP BY ba.CatalogID, ba.Date_Generated

SELECT 
	lba.LocationNo,
	sik.CatalogId,
	t.title,
	t.author,
	CASE 
		WHEN t.binding IN ('Mass Market Paperback', 'CD', 'Audio CD')
		THEN t.binding
		ELSE 'General'
		END [CatalogBinding],
	sik.SipsItemCode [ItemCodeSips],
	spi.DateInStock,
	sis.ScannedOn [current_FirstScan],
	ISNULL(sish17.ScannedOn, sish.ScannedOn) [historic_FirstScan],
	ssh.RegisterPrice,
	ssh.BusinessDate [SaleDate]
INTO #ScannedItems
FROM MathLab..SipsItemKeys_test sik
	LEFT OUTER JOIN ReportsData..ShelfItemScan sis
		ON sik.first_ShelfItemScanID = sis.ShelfItemScanID
	LEFT OUTER JOIN ReportsData..ShelfItemScanHistory sish
		ON sik.first_ShelfItemScanID = sish.ShelfItemScanID
	LEFT OUTER JOIN archShelfScan..ShelfItemScanHistory_2017 sish17
		ON sik.first_ShelfItemScanID = sish17.ShelfItemScanID
	LEFT OUTER JOIN ReportsData..ShelfScan ss
		ON sik.first_ShelfScanID = ss.ShelfScanID
	LEFT OUTER JOIN ReportsData..Shelf s
		ON ss.ShelfID = s.ShelfID
	LEFT OUTER JOIN ReportsData..SipsSalesHistory ssh
		ON sik.SipsItemCode = ssh.SipsItemCode
	INNER JOIN ReportsData..SipsProductInventory spi
		ON sik.SipsItemCode = spi.ItemCode
	LEFT OUTER JOIN Catalog..titles t
		ON sik.CatalogId = t.catalogId
	--INNER JOIN ReportsView..StoreLocationMaster slm
	--	ON s.LocationID = slm.LocationId
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON sik.last_LocationNo = lba.LocationNo
		AND lba.VersionNo = 'v1.r4'
WHERE COALESCE(sis.ScannedOn, sish.ScannedOn, sish17.ScannedOn) < @LastAlgorithmUpdate


SELECT 
	si.LocationNo,
	si.CatalogId,
	si.CatalogBinding,
	COUNT(si.current_FirstScan) [qty_OnHand]
INTO #CurrentMultiples
FROM #ScannedItems si
GROUP BY si.LocationNo, si.CatalogId, si.CatalogBinding
HAVING COUNT(si.current_FirstScan) >= 5
		
--SELECT 
--	si.LocationNo,
--	si.CatalogId,
--	cm.qty_OnHand,
--	si.CatalogBinding,
--	si.current_FirstScan,
--	si.historic_FirstScan
--INTO #CurrentMultiplesHistory
--FROM #CurrentMultiples cm
--	INNER JOIN #ScannedItems si
--		ON cm.LocationNo = si.LocationNo
--		AND cm.CatalogId = si.CatalogId
		


SELECT
	r3o.LocationNo,
	r3o.CatalogId,
	r3o.qty_OnHand,
	r4co.Date_Generated,
	ISNULL(r4lo.Location_SuggestedOffer, r4co.Chain_SuggestedOffer) [SuggestedOffer_R4],
	CASE 
		WHEN adl.LocationNo IS NULL 
		THEN CAST((ot4.BuyOfferPct * adc.Avg_Sale_Price) AS decimal(19, 2)) 
		ELSE CAST((ot4.BuyOfferPct * adl.Avg_Sale_Price) AS decimal(19, 2))
		END [SuggestedOffer_R4Calc],
	CASE 
		WHEN adl.LocationNo IS NULL 
		THEN ot4.BuyOfferPct 
		END [Chain_BuyOfferPct],
	CASE 
		WHEN adl.LocationNo IS NOT NULL 
		THEN ot4.BuyOfferPct 
		END [Loc_BuyOfferPct],
	adc.Avg_Sale_Price [chain_AvgSalePrice],
	adc.Total_Accumulated_Days_With_Trash_Penalty/adc.Total_Item_Count [chain_DaysSalableScanned],
    adl.Avg_Sale_Price [loc_AvgSalePrice],
	adl.Total_Accumulated_Days_With_Trash_Penalty/adl.Total_Item_Count [loc_DaysSalableScanned]
INTO #Offers
FROM #CurrentMultiples r3o
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
	LEFT OUTER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 ot4
		ON RTRIM(LTRIM(r3o.CatalogBinding)) = RTRIM(LTRIM(ot4.CatalogBinding))
		AND ISNULL(adl.Total_Accumulated_Days_With_Trash_Penalty/adl.Total_Item_Count, adc.Total_Accumulated_Days_With_Trash_Penalty/adc.Total_Item_Count) >= ot4.AccDaysRangeFrom
		AND ISNULL(adl.Total_Accumulated_Days_With_Trash_Penalty/adl.Total_Item_Count, adc.Total_Accumulated_Days_With_Trash_Penalty/adc.Total_Item_Count) < ot4.AccDaysRangeTo
ORDER BY LocationNo, qty_OnHand DESC


SELECT 
	si.LocationNo,
	si.CatalogId,
	si.title,
	si.CatalogBinding,
	si.ItemCodeSips,
	si.DateInStock,
	si.current_FirstScan,
	si.historic_FirstScan,
	ISNULL(si.current_FirstScan, si.historic_FirstScan) [date_FirstScan],
	si.RegisterPrice,
	CASE WHEN si.RegisterPrice IS NULL THEN 0 ELSE 1 END [bool_Sold],
	si.SaleDate [date_Sale],
	mco.qty_OnHand,
	mco.SuggestedOffer_R4,
	mco.Date_Generated,
	mco.Chain_BuyOfferPct,
	mco.Loc_BuyOfferPct,
	mco.chain_DaysSalableScanned,
	mco.loc_DaysSalableScanned,
	ISNULL(DATEDIFF(DAY, ISNULL(si.historic_FirstScan, si.DateInStock), si.SaleDate),
		DATEDIFF(DAY, ISNULL(si.current_FirstScan, si.DateInStock), mco.Date_Generated)) [DaysOnShelf],
	DATEDIFF(DAY, ISNULL(si.historic_FirstScan, si.DateInStock), si.SaleDate) [DaysToSell]
FROM #ScannedItems si
	INNER JOIN #CurrentMultiples cm
		ON si.LocationNo = cm.LocationNo
		AND si.CatalogID = cm.CatalogId
	LEFT OUTER JOIN #Offers mco
		ON si.CatalogId = mco.CatalogId
		AND si.LocationNo = mco.LocationNo
		AND ISNULL(si.current_FirstScan, si.historic_FirstScan) < mco.Date_Generated
ORDER BY LocationNo, qty_OnHand DESC, CatalogId, ItemCodeSips

DROP TABLE #R4LastLocOffers
DROP TABLE #R4LastChainOffers
DROP TABLE #ScannedItems
DROP TABLE #CurrentMultiples
DROP TABLE #Offers





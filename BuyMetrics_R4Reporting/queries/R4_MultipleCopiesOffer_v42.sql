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
HAVING COUNT(si.current_FirstScan) >= 3
		

SELECT
	r3o.LocationNo,
	r3o.CatalogId,
	r3o.qty_OnHand,
	r4co.Date_Generated,
	r4co.Chain_BuyOfferPct [chain_BuyOfferPct_R40],
	ot4c.BuyOfferPct [chain_BuyOfferPct_R42],
	r4lo.Location_Buy_Offer_Pct [loc_BuyOfferPct_R40],
	ot4l.BuyOfferPct [loc_BuyOfferPct_R42],
	adc.Avg_Sale_Price [chain_AvgSalePrice],
	adl.Avg_Sale_Price [loc_AvgSalePrice],
	adc.Total_Accumulated_Days_With_Trash_Penalty [chain_AccumulatedDays],
	adl.Total_Accumulated_Days_With_Trash_Penalty [loc_AccumulatedDays],
	adc.Total_Sold [chain_TotalSold],
	adl.Total_Sold [loc_TotalSold],
	adc.Total_Item_Count [chain_TotalItemCount],
	adl.Total_Item_Count [loc_TotalItemCount]
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
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 ot4c
		ON RTRIM(LTRIM(r3o.CatalogBinding)) = RTRIM(LTRIM(ot4c.CatalogBinding))
		AND (adc.Total_Accumulated_Days_With_Trash_Penalty/(adc.Total_Sold + 1)) > ot4c.AccDaysRangeFrom
		AND (adc.Total_Accumulated_Days_With_Trash_Penalty/(adc.Total_Sold + 1)) <= ot4c.AccDaysRangeTo
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R42 ot4l
		ON RTRIM(LTRIM(r3o.CatalogBinding)) = RTRIM(LTRIM(ot4l.CatalogBinding))
		AND (adl.Total_Accumulated_Days_With_Trash_Penalty/(adl.Total_Sold + 1)) > ot4l.AccDaysRangeFrom
		AND (adl.Total_Accumulated_Days_With_Trash_Penalty/(adl.Total_Sold + 1)) <= ot4l.AccDaysRangeTo
ORDER BY LocationNo, qty_OnHand DESC


SELECT 
	si.LocationNo,
	si.CatalogId,
	si.title,
	si.CatalogBinding,
	AVG(si.RegisterPrice) [avg_SalePrice],
	CAST(COUNT(si.RegisterPrice) AS FLOAT)/
		CAST(COUNT(si.ItemCodeSips) AS FLOAT) [pct_SellThrough],
	MIN(DateInStock) [first_DateInStock]
INTO #SalesByLoc
FROM #ScannedItems si
WHERE ISNULL(si.current_FirstScan, si.historic_FirstScan) < @LastAlgorithmUpdate
GROUP BY 
	si.LocationNo,
	si.CatalogId,
	si.title,
	si.CatalogBinding

SELECT
	sbl.LocationNo,
	sbl.CatalogId,
	sbl.CatalogBinding,
	sbl.title,
	sbl.pct_SellThrough,
	sbl.avg_SalePrice,
	mco.qty_OnHand,
	--mco.chain_BuyOfferPct_R40,
	--mco.chain_BuyOfferPct_R42,
	mco.loc_BuyOfferPct_R40,
	mco.loc_BuyOfferPct_R42,
	--mco.chain_AvgSalePrice,
	mco.loc_AvgSalePrice,
	mco.loc_TotalItemCount,
	mco.loc_TotalSold,
	mco.loc_AccumulatedDays/mco.loc_TotalItemCount [Avg_Acc_Days_R40],
	mco.loc_AccumulatedDays/(mco.loc_TotalSold + 1) [Avg_Acc_Days_R42],
	sbl.first_DateInStock
INTO #OfferData
FROM #SalesByLoc sbl
	INNER JOIN #CurrentMultiples cm
		ON sbl.LocationNo = cm.LocationNo
		AND sbl.CatalogID = cm.CatalogId
	LEFT OUTER JOIN #Offers mco
		ON sbl.CatalogId = mco.CatalogId
		AND sbl.LocationNo = mco.LocationNo

SELECT *
FROM #OfferData
ORDER BY LocationNo, qty_OnHand DESC, CatalogId

SELECT
	loc_BuyOfferPct_R40,
	CAST(COUNT(
		CASE 
			WHEN loc_BuyOfferPct_R40 > loc_BuyOfferPct_R42
			THEN CatalogId
			END) AS FLOAT) / CAST(COUNT(CatalogID) AS FLOAT) [pct_OffersR42Decreased],
	CAST(COUNT(
		CASE 
			WHEN loc_BuyOfferPct_R40 < loc_BuyOfferPct_R42
			THEN CatalogId
			END) AS FLOAT) / CAST(COUNT(CatalogID) AS FLOAT) [pct_OffersR42Increased]
FROM #OfferData
GROUP BY loc_BuyOfferPct_R40 WITH ROLLUP
ORDER BY loc_BuyOfferPct_R40 DESC

DROP TABLE #R4LastLocOffers
DROP TABLE #R4LastChainOffers
DROP TABLE #ScannedItems
DROP TABLE #SalesByLoc
DROP TABLE #CurrentMultiples
DROP TABLE #Offers





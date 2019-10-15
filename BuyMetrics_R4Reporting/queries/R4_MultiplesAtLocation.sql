DECLARE @LocationNo VARCHAR = '00005'
DECLARE @StartDate DATE = '8/1/2016'
DECLARE @LastAlgorithmUpdate DATE


SELECT 
	@LastAlgorithmUpdate = MAX(Date_Generated) 
FROM Sandbox..BuyAlgorithm_V1_R4
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



--1 - Item Create Date
--2 - Shelf Scan Record Historical Record
--3 - Shelf Scan Current Record
--4 - Transfer
--5 – Sale

SELECT 
	spi.LocationNo,
	t.isbn10,
	t.isbn13,
	t.title,
	t.author,
	lc.CatalogID,
	lc.ItemCode [ItemCodeSips],
	lc.First_RecordDate [DateInStock],
	CASE
		WHEN lc.LifeCycle_Complete = 0
		AND lc.LastEventType IN (2,3)
		THEN lc.First_ScanDate
		END [current_FirstScan],
	CASE
		WHEN lc.LifeCycle_Complete = 1
		AND lc.LastEventType = 5
		THEN lc.First_ScanDate
		END [historic_FirstScan],
	CASE
		WHEN lc.LifeCycle_Complete = 1
		AND lc.LastEventType = 4
		THEN lc.Last_RecordDate
		END [historic_TrashDate],
	lc.Sale_Price [RegisterPrice],
	lc.Last_SaleDate [SaleDate]
INTO #ScannedItems
FROM Buy_Analytics..ItemCode_LifeCycle lc
	INNER JOIN ReportsData..SipsProductInventory spi
		ON lc.ItemCode = spi.ItemCode
	INNER JOIN Catalog..titles t
		ON lc.CatalogID = t.catalogId
WHERE lc.First_RecordDate > @StartDate

	


SELECT 
	si.LocationNo,
	si.CatalogId,
	si.ISBN13,
	si.title,
	si.author,
	--si.CatalogBinding,
	COUNT(si.current_FirstScan) [qty_OnHand]
INTO #CurrentMultiples
FROM #ScannedItems si
WHERE si.ISBN13 IN ('9781455586509', '9780142406113', '978160747307', '9780307079187')
	--OR	si.isbn10 IN('0312422156', '0810970687'))
GROUP BY si.LocationNo, si.CatalogId, si.ISBN13, si.title, si.author--, si.CatalogBinding
--HAVING COUNT(si.current_FirstScan) >= 5
		

SELECT
	r3o.LocationNo,
	r3o.CatalogId,
	r3o.qty_OnHand,
	r4co.Date_Generated,
	ISNULL(r4lo.Location_SuggestedOffer, r4co.Chain_SuggestedOffer) [SuggestedOffer_R4],
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
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Chain adc
		ON r3o.CatalogID = adc.CatalogID
	LEFT OUTER JOIN Buy_Analytics..BuyAlgorithm_AggregateData_Location adl
		ON r3o.CatalogID = adl.CatalogID
		AND r3o.LocationNo = adl.LocationNo
ORDER BY LocationNo, qty_OnHand DESC

SELECT 
	COUNT(DISTINCT CatalogID)
FROM #ScannedItems

SELECT 
	si.LocationNo,
	si.CatalogID,
	si.isbn13,
	si.title,
	si.author,
	si.ItemCodeSips,
	si.DateInStock,
	si.current_FirstScan,
	si.historic_FirstScan,
	si.historic_TrashDate,
	COALESCE(si.current_FirstScan, si.historic_FirstScan, si.DateInStock) [date_FirstScan],
	si.RegisterPrice,
	CASE WHEN si.RegisterPrice IS NULL THEN 0 ELSE 1 END [bool_Sold],
	si.SaleDate [date_Sale],
	mco.qty_OnHand,
	mco.SuggestedOffer_R4,
	mco.Date_Generated,
	mco.chain_DaysSalableScanned,
	mco.loc_DaysSalableScanned,
	ISNULL(DATEDIFF(DAY, ISNULL(si.historic_FirstScan, si.DateInStock), si.SaleDate),
		DATEDIFF(DAY, ISNULL(si.current_FirstScan, si.DateInStock), mco.Date_Generated)) [DaysOnShelf],
	DATEDIFF(DAY, ISNULL(si.historic_FirstScan, si.DateInStock), si.SaleDate)	[DaysToSell]
FROM #ScannedItems si
	INNER JOIN #CurrentMultiples cm
		ON si.LocationNo = cm.LocationNo
		AND si.CatalogID = cm.CatalogId
	LEFT OUTER JOIN #Offers mco
		ON si.CatalogId = mco.CatalogId
		AND si.LocationNo = mco.LocationNo
		AND COALESCE(si.current_FirstScan, si.historic_FirstScan, si.DateInStock) < mco.Date_Generated
--WHERE si.LocationNo = @LocationNo
ORDER BY LocationNo, qty_OnHand DESC, CatalogID, ItemCodeSips

DROP TABLE #R4LastLocOffers
DROP TABLE #R4LastChainOffers
DROP TABLE #ScannedItems
DROP TABLE #CurrentMultiples
DROP TABLE #Offers





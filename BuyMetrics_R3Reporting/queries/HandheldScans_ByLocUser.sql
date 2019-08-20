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
	CASE
		WHEN ot4.CatalogBinding IN ('Mass Market Paperback','CD', 'Audio CD')
			THEN ot4.CatalogBinding
		ELSE 'General'
		END [CatalogBinding],
	bbi.Scoring_ID,
	bbi.ItemEntryModeID,
	bbi.CatalogID,
	bbi.SipsID,
	bbi.ISBN,
	ba.ListPrice,
	bbi.SuggestedOffer,
	bbi.SuggestedOfferType,
	bbi.Quantity,
	CASE 
		WHEN bbi.CreateMachine LIKE 'CT50%'
			THEN 'CT50'
		WHEN bbi.CreateMachine LIKE 'CT60%'
			THEN 'CT60'
		ELSE 'Desktop'
		END [type_CreateMachine],
	bbi.SuggestedOfferVersion,
	bbi.CreateUser
INTO #R3Offers
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN BUYS..BuyTypes bt
		ON bbi.BuyTypeID = bt.BuyTypeID
	LEFT OUTER JOIN Sandbox..BuyAlgorithm_V1_R3 ba
		ON bbi.Scoring_ID = ba.OfferID
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON bbh.LocationNo = lba.LocationNo
	LEFT OUTER JOIN Catalog..Titles t
		ON bbi.CatalogID = t.catalogId
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 ot4
		ON LTRIM(RTRIM(t.binding)) = LTRIM(RTRIM(ot4.CatalogBinding))
		AND ot4.BuyGradeName = 'A'
WHERE 
	bbh.StatusCode = 1  AND
	bbi.StatusCode = 1 AND
	bbh.CreateTime >= '6/25/2019'

SELECT  
	LocationNo,
	CreateUser,
	SUM(Quantity) [total_Quantity],
	SUM(CASE 
		WHEN ItemEntryModeID IS NULL
		THEN Quantity
		END) [qty_Scanned],
	CAST(SUM(CASE 
		WHEN ItemEntryModeID IS NULL
		THEN Quantity
		END) AS FLOAT)/CAST(SUM(Quantity) AS FLOAT) [pct_Scanned],
	CAST(SUM(CASE 
		WHEN type_CreateMachine LIKE 'CT%'
		THEN Quantity
		END) AS FLOAT)/CAST(SUM(Quantity) AS FLOAT) [pct_HandheldScanned],
	CAST(SUM(CASE 
		WHEN type_CreateMachine LIKE 'CT%' 
		THEN Quantity
		END) AS FLOAT)/
		CAST(SUM(
		CASE 
		WHEN ItemEntryModeID IS NULL
		THEN Quantity 
		END)  AS FLOAT) [pct_ScannedHandheldScanned]
FROM #R3Offers
GROUP BY LocationNo
ORDER BY LocationNo
DECLARE @StartDate DATE = '6/25/2019'

SELECT 
	DATEADD(DAY, DATEDIFF(DAY, 0, bbh.CreateTime), 0) [BusinessDate],
	bt.BuyType [BuyType_User],
	CASE
	WHEN t.binding IN ('Mass Market Paperback')
		THEN 'PB'
	WHEN t.binding IN ('CD', 'Audio CD')
		THEN 'CDU'
	ELSE bt.BuyType
	END [BuyType_Catalog],
	bbh.BuyBinNo,
	bbi.CreateTime,
	bbi.Offer,
	bbi.SuggestedOffer,
	bbi.Quantity,
	bbi.Offer / bbi.Quantity [UserOffer],
	bbi.SuggestedOfferVersion,
	bbi.SuggestedOfferType,
	t.catalogId,
	t.isbn13,
	t.title, 
	t.author,
	t.listPrice,
	t.releaseDate
INTO #BuyMetrics
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.LocationNo = bbi.LocationNo
		AND bbh.BuyBinNo = bbi.BuyBinNo
	INNER JOIN BUYS..BuyTypes bt
		ON bbi.BuyTypeID = bt.BuyTypeID
	
	LEFT OUTER JOIN Catalog..titles t
		ON bbi.CatalogID = t.catalogId
WHERE 
	bbh.CreateTime >= @StartDate
	AND bbh.StatusCode = 1
	AND bbi.StatusCode = 1
	AND bbi.Quantity > 0
	AND bbi.SuggestedOfferVersion = 'v1.r3'

SELECT 
	bm.CatalogID,
	bm.isbn13,
	bm.title,
	bm.author,
	bm.BuyType_Catalog,
	COUNT(bm.CatalogID) [count_Items],
	CAST(COUNT(CASE 
			WHEN bm.BuyType_Catalog <> bm.BuyType_User
			THEN bm.catalogId
			END) AS FLOAT) / 
			CAST(COUNT(bm.CatalogID) AS FLOAT) [pct_TypeMismatch] 
FROM #BuyMetrics bm
GROUP BY bm.catalogId, bm.BuyType_Catalog, bm.isbn13, bm.title, bm.author
HAVING 
		COUNT(bm.CatalogID) > 5 AND 
		(CAST(COUNT(CASE 
			WHEN bm.BuyType_Catalog <> bm.BuyType_User
			THEN bm.catalogId
			END) AS FLOAT) / 
			NULLIF(CAST(COUNT(bm.CatalogID) AS FLOAT), 0)) > .5
ORDER BY count_Items DESC


DROP TABLE #BuyMetrics
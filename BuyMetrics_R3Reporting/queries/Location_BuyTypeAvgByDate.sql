DECLARE @StartDate DATE = '8/19/2019'
DECLARE @LocationNo CHAR(5) = '00116'

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
		bbh.LocationNo = @LocationNo
	AND bbh.CreateTime >= @StartDate
	AND bbh.StatusCode = 1
	AND bbi.StatusCode = 1

SELECT 
	BusinessDate,
	COUNT(DISTINCT bm.BuyBinNo) [count_BuyTransactions],
	SUM(bm.Offer) [total_BuyOffers],
	SUM(bm.Quantity) [total_BuyQuantity],
	SUM(bm.Offer) / SUM(bm.Quantity) [avg_ItemOffer]
FROM #BuyMetrics bm
GROUP BY BusinessDate

SELECT 
	bm.BusinessDate,
	bm.BuyType_Catalog,
	SUM(bm.Quantity) [qty_Purchased],
	SUM(bm.Offer)/SUM(bm.Quantity) [avg_Offer],
	SUM(CASE 
		WHEN bm.SuggestedOfferVersion IS NOT NULL
		THEN bm.Quantity
		END) [qty_SuggestedOffer],
	SUM(CASE 
		 WHEN bm.SuggestedOfferVersion IS NOT NULL
		 THEN bm.SuggestedOffer
		 END) / 
		SUM(CASE
				WHEN bm.SuggestedOfferVersion IS NOT NULL
				THEN bm.Quantity
				END) [avg_SuggestedOffer]
FROM #BuyMetrics bm
GROUP BY bm.BuyType_Catalog, bm.BusinessDate
ORDER BY bm.BuyType_Catalog, bm.BusinessDate

--SELECT *
--FROM #BuyMetrics
--ORDER BY BusinessDate, BuyBinNo
DROP TABLE #BuyMetrics

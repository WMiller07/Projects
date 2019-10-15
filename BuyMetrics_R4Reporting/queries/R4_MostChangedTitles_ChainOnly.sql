DECLARE @StartDate DATE = '6/25/2019'

SELECT TOP 1000
	t.catalogId,
	t.ISBN13,
	t.upc,
	t.title,
	t.author,
	COUNT(bbi.CatalogID) [count_QtyPurchased],
	COUNT(CASE
			WHEN (bbi.Offer / bbi.Quantity) <> bbi.SuggestedOffer
			THEN bbi.CatalogID
			END) [count_QtyChangedSO],
	CAST(COUNT(CASE
				WHEN (bbi.Offer / bbi.Quantity) <> bbi.SuggestedOffer
				THEN bbi.CatalogID
				END) AS FLOAT) / CAST(NULLIF(COUNT(bbi.CatalogID), 0) AS FLOAT) [pct_QtyChangedSO],
	CAST(SUM(CASE
				WHEN bbi.SuggestedOfferType = 1
				THEN bbi.SuggestedOffer
				END) AS FLOAT) / 
				CAST(SUM(CASE
							WHEN bbi.SuggestedOfferType = 1
							THEN bbi.Quantity
							END) AS FLOAT) [avg_ChainSOAmt],
	CAST(SUM(CASE
				WHEN (bbi.Offer / bbi.Quantity) <> bbi.SuggestedOffer
				THEN bbi.Offer
				END) AS FLOAT) / 
				CAST(SUM(CASE
							WHEN (bbi.Offer / bbi.Quantity) <> bbi.SuggestedOffer
							THEN bbi.Quantity
							END) AS FLOAT) [avg_PostChangeOfferAmt]

FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinitems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON bbh.LocationNo = lba.LocationNo
		AND lba.VersionNo = 'v1.r3'
	INNER JOIN Catalog..titles t
		ON bbi.CatalogID = t.CatalogID
WHERE 
		bbh.CreateTime >= @StartDate
	AND bbh.StatusCode = 1
	AND bbi.StatusCode = 1
	AND bbi.Quantity > 0
	AND bbi.SuggestedOfferVersion IN ('v1.r3', 'v1.r4')
	AND bbi.SuggestedOfferType = 1
GROUP BY t.CatalogID, t.isbn13, t.upc, t.title, t.author
HAVING 
		COUNT(bbi.CatalogID) > 5
	AND COUNT(CASE
			WHEN (bbi.Offer / bbi.Quantity) <> bbi.SuggestedOffer
			THEN bbi.CatalogID
			END) > 1
ORDER BY count_QtyChangedSO DESC
	
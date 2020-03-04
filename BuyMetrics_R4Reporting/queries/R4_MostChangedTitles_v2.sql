SELECT DISTINCT
	--bbi.SuggestedOfferVersion,
	t.isbn13,
	t.title,
	t.author,
	t.releaseDate,
	SUM(bbi.Quantity) [count_QtyPurchased_Scanned],
	COUNT(CASE 
			WHEN bbi.SuggestedOffer <> (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
			THEN bbi.CatalogID 
			END) [count_AdjustedTitles],
	CAST(COUNT(CASE 
			WHEN bbi.SuggestedOffer <> (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
			THEN bbi.CatalogID 
			END) AS FLOAT) /
			NULLIF(CAST(COUNT(bbi.CatalogID) AS FLOAT), 0) [pct_Adjusted],
	AVG(bbi.SuggestedOffer) [avg_SuggestedOffer],
	CAST(COUNT(CASE 
			WHEN bbi.SuggestedOffer < (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
			THEN bbi.CatalogID 
			END) AS FLOAT) /
		NULLIF(CAST(COUNT(CASE 
			WHEN bbi.SuggestedOffer <> (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
			THEN bbi.CatalogID 
			END) AS FLOAT), 0) [pct_Adjusted_Up],
	CAST(COUNT(CASE 
			WHEN bbi.SuggestedOffer > (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
			THEN bbi.CatalogID 
			END) AS FLOAT) /
		NULLIF(CAST(COUNT(CASE 
			WHEN bbi.SuggestedOffer <> (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
			THEN bbi.CatalogID 
			END) AS FLOAT), 0) [pct_Adjusted_Down],
	AVG(CASE 
			WHEN bbi.SuggestedOffer < (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
			THEN bbi.Offer 
			END)
			- AVG(CASE 
					WHEN bbi.SuggestedOffer < (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
					THEN bbi.SuggestedOffer
					END) [avg_Amt_Adjusted_Up],
	AVG(CASE 
		WHEN bbi.SuggestedOffer > (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
		THEN bbi.Offer 
		END)
			- AVG(CASE 
					WHEN bbi.SuggestedOffer > (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
					THEN bbi.SuggestedOffer
					END) [avg_Amt_Adjusted_Down]
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.LocationNo = bbi.LocationNo
		AND bbh.BuyBinNo = bbi.BuyBinNo
	INNER JOIN Catalog..titles t
		ON bbi.CatalogID = t.catalogId
	--LEFT OUTER JOIN ReportsData..SipsProductMaster spm
	--	ON bbi.SipsID = spm.SipsID
WHERE bbi.SuggestedOfferVersion IN ('V1.R4','V1.R4.2') --,'V1.R3')
	AND bbh.StatusCode = 1
	AND bbi.StatusCode = 1
GROUP BY 
	GROUPING 
		SETS(
			(t.isbn13,
			t.title,
			t.author,
			t.releaseDate), 
			())
ORDER BY count_AdjustedTitles DESC


DECLARE @StartDate DATE = '6/25/19'
DECLARE @LocationNo CHAR(5) = '00112'


SELECT 
	bbi.CreateUser,
	SUM(Quantity) [total_ItemsPurchased],
	CAST(SUM(CASE 
		WHEN bbi.ItemEntryModeID IS NULL 
		THEN bbi.Quantity 
		END) AS FLOAT)/CAST(SUM(bbi.Quantity) AS FLOAT)						[pct_QtyScanned],
	CAST(SUM(CASE 
		WHEN bbi.Scoring_ID IS NOT NULL
		THEN bbi.Quantity 
		END) AS FLOAT)/CAST(SUM(bbi.Quantity) AS FLOAT)						[pct_QtySuggestedOffer],
	CAST(SUM(CASE 
		WHEN bbi.SuggestedOffer <>  (bbi.Offer / NULLIF(bbi.Quantity, 0))
		AND bbi.Scoring_ID IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT)														[total_QtySuggestedOffersAdjusted],
	CAST(SUM(CASE 
		WHEN bbi.SuggestedOffer <>  (bbi.Offer / NULLIF(bbi.Quantity, 0))
		AND bbi.Scoring_ID IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT)/
		CAST(SUM(CASE 
			WHEN bbi.Scoring_ID IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT)													[pct_QtySuggestedOffersAdjusted]
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN BUYS..BuyTypes bt
		ON bbi.BuyTypeID = bt.BuyTypeID
WHERE 
	bbh.CreateTime >  @StartDate AND
	bbh.StatusCode = 1 AND
	bbi.StatusCode = 1 AND
	bbi.Quantity > 0 AND
	bbi.Quantity < 10000 AND
	bbi.Offer < 10000 AND
	bbh.LocationNo = @LocationNo
GROUP BY bbi.CreateUser
ORDER BY total_QtySuggestedOffersAdjusted DESC

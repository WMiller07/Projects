DECLARE @StartDate DATE = '7/1/2019'
DECLARE @EndDate DATE = '3/1/2020'

SELECT DISTINCT
	LocationNo
INTO #SOLocs
FROM BUYS..BuyBinItems bbi
WHERE bbi.SuggestedOfferVersion IS NOT NULL
	AND bbi.CreateTime >= @StartDate
	AND bbi.CreateTime < @EndDate
ORDER BY LocationNo


SELECT 
	ba.CatalogID,
	'V1.R4.2' [VersionNo],
	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer],
	MIN(ba.Chain_Buy_Offer_Pct) [Chain_Buy_Offer_Pct]
INTO #SO_Chain_R42
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R42 ba
INNER JOIN (
			SELECT 
				ba.CatalogID,	
				MAX(ba.InsertDate) last_InsertDate
			FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R42 ba
			GROUP BY ba.CatalogID
			) m
	ON ba.CatalogID = m.CatalogID
	AND ba.InsertDate = m.last_InsertDate
GROUP BY ba.CatalogID

SELECT 
	ba.CatalogID,
	'V1.R4.3' [VersionNo],
	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer],
	MIN(ba.Chain_Buy_Offer_Pct) [Chain_Buy_Offer_Pct]
INTO #SO_Chain_R43
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R43 ba
INNER JOIN (
			SELECT 
				ba.CatalogID,	
				MAX(ba.InsertDate) last_InsertDate
			FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R43 ba
			GROUP BY ba.CatalogID
			) m
	ON ba.CatalogID = m.CatalogID
	AND ba.InsertDate = m.last_InsertDate
GROUP BY ba.CatalogID


SELECT 
	ba.CatalogID,
	ba.LocationNo,
	'V1.R4.2' [VersionNo],
	MIN(ba.Location_SuggestedOffer) [Location_SuggestedOffer],
	MIN(ba.Location_Buy_Offer_Pct) [Location_Buy_Offer_Pct]
INTO #SO_Location_R42
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R42 ba
	INNER JOIN (
			SELECT 
				ba.CatalogID,	
				ba.LocationNo,
				MAX(ba.InsertDate) last_InsertDate
			FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R42 ba
			GROUP BY ba.CatalogID, ba.LocationNo
			) m
	ON ba.CatalogID = m.CatalogID
	AND ba.LocationNo = m.LocationNo
	AND ba.InsertDate = m.last_InsertDate
GROUP BY ba.CatalogID, ba.LocationNo

SELECT 
	ba.CatalogID,
	ba.LocationNo,
	'V1.R4.3' [VersionNo],
	MIN(ba.Location_SuggestedOffer) [Location_SuggestedOffer],
	MIN(ba.Location_Buy_Offer_Pct) [Location_Buy_Offer_Pct]
INTO #SO_Location_R43
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R43 ba
	INNER JOIN (
			SELECT 
				ba.CatalogID,	
				ba.LocationNo,
				MAX(ba.InsertDate) last_InsertDate
			FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R43 ba
			GROUP BY ba.CatalogID, ba.LocationNo
			) m
	ON ba.CatalogID = m.CatalogID
	AND ba.LocationNo = m.LocationNo
	AND ba.InsertDate = m.last_InsertDate
GROUP BY ba.CatalogID, ba.LocationNo



SELECT 
	SUM(CASE
		WHEN bbi.SearchResultSourceID IS NOT NULL
		THEN bbi.Quantity 
		END) [total_All_Quantity],
	SUM(CASE
		WHEN bbi.Scoring_ID IS NOT NULL
		THEN bbi.Quantity
		END) [total_SO_Quantity],
	SUM(CASE
		WHEN bac42.Chain_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) [total_R42_Quantity],
	SUM(CASE
		WHEN bac43.Chain_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) [total_R43_Quantity],

	CAST(SUM(CASE
		WHEN bbi.Scoring_ID IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.SearchResultSourceID IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [pct_SO_Quantity],
	CAST(SUM(CASE
		WHEN bac42.Chain_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.SearchResultSourceID IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [pct_R42Chain_Quantity],
	CAST(SUM(CASE
		WHEN bac43.Chain_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.SearchResultSourceID IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [pct_R43Chain_Quantity],

	CAST(SUM(CASE
		WHEN bal42.Location_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.SearchResultSourceID IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [pct_R42Location_Quantity],
	CAST(SUM(CASE
		WHEN bal43.Location_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.SearchResultSourceID IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [pct_R43Location_Quantity],

	CAST(SUM(CASE
		WHEN bbi.Scoring_ID IS NOT NULL
		THEN bbi.SuggestedOffer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.Scoring_ID  IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_SO_Offer],
	CAST(SUM(CASE
		WHEN bac42.Chain_SuggestedOffer IS NOT NULL
		THEN bac42.Chain_SuggestedOffer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bac42.Chain_SuggestedOffer IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R42_ChainOffer],
	CAST(SUM(CASE
		WHEN bac43.Chain_SuggestedOffer IS NOT NULL
		THEN bac43.Chain_SuggestedOffer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bac43.Chain_SuggestedOffer IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R43_ChainOffer],

	CAST(SUM(CASE
		WHEN bal42.Location_SuggestedOffer IS NOT NULL
		THEN bal42.Location_SuggestedOffer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bal42.Location_SuggestedOffer IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R42_LocationOffer],
	CAST(SUM(CASE
		WHEN bal43.Location_SuggestedOffer IS NOT NULL
		THEN bal43.Location_SuggestedOffer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bal43.Location_SuggestedOffer IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R43_LocationOffer],

	CAST(SUM(CASE
		WHEN ISNULL(bal42.Location_SuggestedOffer, bac42.Chain_SuggestedOffer) IS NOT NULL
		THEN ISNULL(bal42.Location_SuggestedOffer, bac42.Chain_SuggestedOffer)
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN ISNULL(bal42.Location_SuggestedOffer, bac42.Chain_SuggestedOffer) IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R42_Offer],
	CAST(SUM(CASE
		WHEN ISNULL(bal43.Location_SuggestedOffer, bac43.Chain_SuggestedOffer) IS NOT NULL
		THEN ISNULL(bal43.Location_SuggestedOffer, bac43.Chain_SuggestedOffer)
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN ISNULL(bal43.Location_SuggestedOffer, bac43.Chain_SuggestedOffer) IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R43_Offer],
	CAST(SUM(CASE
		WHEN ISNULL(bal42.Location_SuggestedOffer, bac42.Chain_SuggestedOffer) IS NOT NULL
		THEN bbi.Offer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN ISNULL(bal42.Location_SuggestedOffer, bac42.Chain_SuggestedOffer) IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_ActualR42_Offer],
	CAST(SUM(CASE
		WHEN ISNULL(bal43.Location_SuggestedOffer, bac43.Chain_SuggestedOffer) IS NOT NULL
		THEN bbi.Offer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN ISNULL(bal43.Location_SuggestedOffer, bac43.Chain_SuggestedOffer) IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_ActualR43_Offer]
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.LocationNo = bbi.LocationNo
		AND bbh.BuyBinNo = bbi.BuyBinNo
	INNER JOIN #SOLocs sol
		ON bbh.LocationNo = sol.LocationNo
	LEFT OUTER JOIN ReportsData..SipsProductMaster spm
		ON bbi.SipsID = spm.SipsID

	LEFT OUTER JOIN #SO_Chain_R42 bac42
		ON spm.CatalogID = bac42.CatalogID
	LEFT OUTER JOIN #SO_Chain_R43 bac43
		ON spm.CatalogID = bac43.CatalogID

	LEFT OUTER JOIN #SO_Location_R42 bal42
		ON spm.CatalogID = bal42.CatalogID
		AND bbi.LocationNo = bal42.LocationNo
	LEFT OUTER JOIN #SO_Location_R43 bal43
		ON spm.CatalogID = bal43.CatalogID
		AND bbi.LocationNo = bal43.LocationNo
WHERE bbh.StatusCode = 1
  AND bbi.StatusCode = 1
  AND bbh.CreateTime >= @StartDate
  AND bbh.CreateTime < @EndDate
  AND bbi.Offer < 100000
  AND bbi.Quantity < 100000

DROP TABLE #SOLocs
DROP TABLE #SO_Chain_R42
DROP TABLE #SO_Chain_R43
DROP TABLE #SO_Location_R42
DROP TABLE #SO_Location_R43
  
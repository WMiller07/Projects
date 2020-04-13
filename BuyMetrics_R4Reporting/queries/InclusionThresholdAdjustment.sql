DECLARE @StartDate DATE = '2/1/2020'
DECLARE @EndDate DATE = '3/1/2020'

SELECT DISTINCT
	LocationNo
INTO #SOLocs
FROM BUYS..BuyBinItems bbi
WHERE bbi.SuggestedOfferVersion IS NOT NULL
	AND bbi.CreateTime >= @StartDate
	AND bbi.CreateTime < @EndDate
	AND bbi.LocationNo NOT IN ('00001', '00303')
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
	'V1.R4.4' [VersionNo],
	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer],
	MIN(ba.Chain_Buy_Offer_Pct) [Chain_Buy_Offer_Pct]
INTO #SO_Chain_R44
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R44 ba
INNER JOIN (
			SELECT 
				ba.CatalogID,	
				MAX(ba.InsertDate) last_InsertDate
			FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R44 ba
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
	'V1.R4.4' [VersionNo],
	MIN(ba.Location_SuggestedOffer) [Location_SuggestedOffer],
	MIN(ba.Location_Buy_Offer_Pct) [Location_Buy_Offer_Pct]
INTO #SO_Location_R44
FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R44 ba
	INNER JOIN (
			SELECT 
				ba.CatalogID,	
				ba.LocationNo,
				MAX(ba.InsertDate) last_InsertDate
			FROM Buy_Analytics.dbo.BuyAlgorithm_V1_R44 ba
			GROUP BY ba.CatalogID, ba.LocationNo
			) m
	ON ba.CatalogID = m.CatalogID
	AND ba.LocationNo = m.LocationNo
	AND ba.InsertDate = m.last_InsertDate
GROUP BY ba.CatalogID, ba.LocationNo



SELECT 
	bbi.LocationNo,
	SUM(CASE
		WHEN bbi.ItemEntryModeID IS NULL
		THEN bbi.Quantity 
		END) [total_Scanned_Quantity],
	SUM(CASE
		WHEN bbi.Scoring_ID IS NOT NULL
		THEN bbi.Quantity
		END) [total_SO_Quantity],
	SUM(CASE
		WHEN bac42.Chain_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) [total_R42_Quantity],
	SUM(CASE
		WHEN bac44.Chain_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) [total_R44_Quantity],

	CAST(SUM(CASE
		WHEN bbi.Scoring_ID IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.ItemEntryModeID IS NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [pct_SO_Quantity],
	CAST(SUM(CASE
		WHEN bac42.Chain_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.ItemEntryModeID IS NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [pct_R42Chain_Quantity],
	CAST(SUM(CASE
		WHEN bac44.Chain_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.ItemEntryModeID IS NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [pct_R44Chain_Quantity],

	CAST(SUM(CASE
		WHEN bal42.Location_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.ItemEntryModeID IS NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [pct_R42Location_Quantity],
	CAST(SUM(CASE
		WHEN bal44.Location_SuggestedOffer IS NOT NULL
		THEN bbi.Quantity
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bbi.ItemEntryModeID IS NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [pct_R44Location_Quantity],

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
		WHEN bac44.Chain_SuggestedOffer IS NOT NULL
		THEN bac44.Chain_SuggestedOffer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bac44.Chain_SuggestedOffer IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R44_ChainOffer],

	CAST(SUM(CASE
		WHEN bal42.Location_SuggestedOffer IS NOT NULL
		THEN bal42.Location_SuggestedOffer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bal42.Location_SuggestedOffer IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R42_LocationOffer],
	CAST(SUM(CASE
		WHEN bal44.Location_SuggestedOffer IS NOT NULL
		THEN bal44.Location_SuggestedOffer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN bal44.Location_SuggestedOffer IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R44_LocationOffer],

	CAST(SUM(CASE
		WHEN ISNULL(bal42.Location_SuggestedOffer, bac42.Chain_SuggestedOffer) IS NOT NULL
		THEN ISNULL(bal42.Location_SuggestedOffer, bac42.Chain_SuggestedOffer)
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN ISNULL(bal42.Location_SuggestedOffer, bac42.Chain_SuggestedOffer) IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R42_Offer],
	CAST(SUM(CASE
		WHEN ISNULL(bal44.Location_SuggestedOffer, bac44.Chain_SuggestedOffer) IS NOT NULL
		THEN ISNULL(bal44.Location_SuggestedOffer, bac44.Chain_SuggestedOffer)
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN ISNULL(bal44.Location_SuggestedOffer, bac44.Chain_SuggestedOffer) IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_R44_Offer],
	CAST(SUM(CASE
		WHEN ISNULL(bal42.Location_SuggestedOffer, bac42.Chain_SuggestedOffer) IS NOT NULL
		THEN bbi.Offer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN ISNULL(bal42.Location_SuggestedOffer, bac42.Chain_SuggestedOffer) IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_ActualR42_Offer],
	CAST(SUM(CASE
		WHEN ISNULL(bal44.Location_SuggestedOffer, bac44.Chain_SuggestedOffer) IS NOT NULL
		THEN bbi.Offer
		END) AS FLOAT) /
		CAST(SUM(CASE
			WHEN ISNULL(bal44.Location_SuggestedOffer, bac44.Chain_SuggestedOffer) IS NOT NULL
			THEN bbi.Quantity 
			END) AS FLOAT) [avg_ActualR44_Offer],
	COUNT(bal42.Location_SuggestedOffer) [count_r42LocationOffers],
	COUNT(bal44.Location_SuggestedOffer) [count_r44LocationOffers]
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
	LEFT OUTER JOIN #SO_Chain_R44 bac44
		ON spm.CatalogID = bac44.CatalogID

	LEFT OUTER JOIN #SO_Location_R42 bal42
		ON spm.CatalogID = bal42.CatalogID
		AND bbi.LocationNo = bal42.LocationNo
	LEFT OUTER JOIN #SO_Location_R44 bal44
		ON spm.CatalogID = bal44.CatalogID
		AND bbi.LocationNo = bal44.LocationNo
WHERE bbh.StatusCode = 1
  AND bbi.StatusCode = 1
  AND bbh.CreateTime >= @StartDate
  AND bbh.CreateTime < @EndDate
  AND bbi.Offer < 100000
  AND bbi.Quantity < 100000
GROUP BY bbi.LocationNo
ORDER BY bbi.LocationNo

DROP TABLE #SOLocs
DROP TABLE #SO_Chain_R42
DROP TABLE #SO_Chain_R44
DROP TABLE #SO_Location_R42
DROP TABLE #SO_Location_R44
  
DECLARE @StartDate DATE = '11/1/2019'

SELECT 
	ba.CatalogID,
	MAX(ba.Date_Generated) [last_DateGenerated]
INTO #LatestAlgorithmChain
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
GROUP BY ba.CatalogID

SELECT 
	ba.CatalogID,
	ba.LocationNo,
	MAX(ba.Date_Generated) [last_DateGenerated]
INTO #LatestAlgorithmLoc
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
GROUP BY ba.CatalogID, ba.LocationNo

SELECT
	ba.CatalogID,
	MIN(ba.Chain_SuggestedOffer) [Chain_SuggestedOffer],
	ba.Date_Generated
INTO #ChainSuggestedOffers
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
	INNER JOIN #LatestAlgorithmChain la
		ON ba.CatalogID = la.CatalogID
		AND ba.Date_Generated = la.last_DateGenerated
GROUP BY ba.CatalogID, ba.Date_Generated

SELECT
	ba.CatalogID,
	ba.LocationNo,
	ba.Location_SuggestedOffer,
	ba.Date_Generated
INTO #LocSuggestedOffers
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
	INNER JOIN #LatestAlgorithmLoc la
		ON ba.CatalogID = la.CatalogID
		AND ba.Date_Generated = la.last_DateGenerated
		AND ba.LocationNo = la.LocationNo

DROP TABLE #LatestAlgorithmChain
DROP TABLE #LatestAlgorithmLoc

--SELECT 
--	cso.CatalogID,
--	cso.Chain_SuggestedOffer,
--	lso.LocationNo,
--	lso.Location_SuggestedOffer,
--	ISNULL(lso.Location_SuggestedOffer, Chain_SuggestedOffer) [SuggestedOffer],
--	cso.Date_Generated [Chain_DateGenerated],
--	lso.Date_Generated [Location_DateGenerated]
--FROM #ChainSuggestedOffers cso
--	LEFT OUTER JOIN #LocSuggestedOffers lso
--		ON cso.CatalogID = lso.CatalogID
--ORDER BY cso.CatalogID, lso.LocationNo

SELECT 
	spm.CatalogId,
	bbh.LocationNo,
	ISNULL(bbi.LastUpdateUser, bbi.CreateUser) [Buyer],
	SUM(bbi.Quantity) [total_Qty],
	SUM(bbi.Offer) [total_Offer],
	SUM(bbi.Offer)/SUM(bbi.Quantity) [avg_BuyOfferAmt],
	AVG(cso.Chain_SuggestedOffer) [Chain_SuggestedOffer],
	AVG(ISNULL(lso.Location_SuggestedOffer, cso.Chain_SuggestedOffer)) [avg_ChainLocSuggestedOffer],
	VARP(bbi.Offer/bbi.Quantity) [var_BuyOfferAmt],
	AVG(ABS((bbi.Offer/bbi.Quantity) - cso.Chain_SuggestedOffer)) [MAE_ChainSuggestedOffer],
	AVG(ABS((bbi.Offer/bbi.Quantity) - ISNULL(lso.Location_SuggestedOffer, cso.Chain_SuggestedOffer))) [MAE_LocChainSuggestedOffer]
INTO #BuyerOffers
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN ReportsData..SipsProductMaster spm
		ON bbi.SipsID = spm.SipsID
	INNER JOIN #ChainSuggestedOffers cso
		ON cso.CatalogID = spm.CatalogId
	LEFT OUTER JOIN #LocSuggestedOffers lso
		ON lso.CatalogID = spm.CatalogID
		AND lso.LocationNo = bbi.LocationNo
WHERE bbh.StatusCode = 1
	AND bbi.StatusCode = 1
	AND bbh.UpdateTime >= '12/2/2019'
	AND bbi.Quantity > 0
	AND bbi.Offer < 100000
	AND spm.CatalogId IS NOT NULL
	AND bbi.Scoring_ID IS NULL
GROUP BY spm.CatalogId, bbh.LocationNo, ISNULL(bbi.LastUpdateUser, bbi.CreateUser) 

--ORDER BY bbh.LocationNo, total_Qty


SELECT * 
FROM #BuyerOffers bo
WHERE bo.total_Qty >= 2
ORDER BY Buyer, total_Qty DESC, LocationNo 

SELECT 
	--bo.CatalogId,
	bo.LocationNo,
	bo.Buyer,
	SUM(bo.total_Qty) [total_Qty],
	SUM(bo.total_Offer)/SUM(bo.total_Qty) [avg_BuyerOffer],
	AVG(bo.var_BuyOfferAmt) [avg_VarBuyerOffer],
	AVG(cso.Chain_SuggestedOffer) [avg_ChainSuggestedOffer],
	AVG(ISNULL(lso.Location_SuggestedOffer, cso.Chain_SuggestedOffer)) [avg_LocChainSuggestedOffer],
	AVG(bo.MAE_ChainSuggestedOffer) [MAE_Chain],
	AVG(bo.MAE_LocChainSuggestedOffer) [MAE_LocChain]
	--SQRT(AVG(POWER(bo.avg_BuyOfferAmt - cso.Chain_SuggestedOffer, 2.0)))[RMSE_ChainSuggestedOffer],
	--SQRT(AVG(POWER(bo.avg_BuyOfferAmt - ISNULL(lso.Location_SuggestedOffer, cso.Chain_SuggestedOffer), 2.0))) [RMSE_LocChainSuggestedOffer]
FROM #BuyerOffers bo
	INNER JOIN #ChainSuggestedOffers cso
		ON cso.CatalogID = bo.CatalogId
	LEFT OUTER JOIN #LocSuggestedOffers lso
		ON lso.CatalogID = bo.CatalogID
		AND lso.LocationNo = bo.LocationNo
WHERE total_Qty >= 2
GROUP BY 	
	--bo.CatalogId,
	bo.LocationNo,
	bo.Buyer
	WITH CUBE
ORDER BY total_Qty DESC

DROP TABLE #ChainSuggestedOffers
DROP TABLE #LocSuggestedOffers
DROP TABLE #BuyerOffers
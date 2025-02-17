DECLARE @StartDate DATE = '1/1/2020'
DECLARE @EndDate DATE = '2/1/2020'

SELECT 
	bbi.CatalogID,
	bbi.Quantity,
	bbi.Offer / bbi.Quantity [BuyOffer],
	bbi.SuggestedOffer,
	bbi.Scoring_ID,
	cop.AmazonLowestPrice * obt.BuyOfferPct [OnlineOffer],
	obt.BuyOfferPct [OnlineBuyOfferPct],
	cop.AmazonLowestPrice,
	ccr.AmazonSalesRank
INTO #Buys
FROM BUYS.dbo.BuyBinHeader bbh
	INNER JOIN BUYS.dbo.BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	LEFT OUTER JOIN Buy_Analytics_Test.dbo.CatalogOnlinePrices cop
		ON bbi.CatalogID = cop.CatalogID
	LEFT OUTER JOIN Buy_Analytics_Test.dbo.CatalogCompiledRankings ccr
		ON bbi.CatalogID = ccr.CatalogID
	LEFT OUTER JOIN Buy_Analytics_Test.dbo.OnlineSalesRank_BuyTable_V0_R0 obt
		ON ccr.AmazonSalesRank >= obt.OnlineSalesRankRangeFrom
		AND ccr.AmazonSalesRank < obt.OnlineSalesRankRangeTo
WHERE 
		bbh.StatusCode = 1
	AND bbi.StatusCode = 1
	AND bbi.Quantity > 0
	AND bbh.CreateTime >= @StartDate
	AND bbh.CreateTime < @EndDate
	AND bbi.CatalogID IS NOT NULL

SELECT 
	b.CatalogID,
	SUM(b.Quantity) [totalQty],
	AVG(b.BuyOffer) [avgBuyOffer],
	AVG(CASE WHEN b.Scoring_ID IS NOT NULL THEN b.SuggestedOffer END) [avgSuggestedOffer],
	--CAST(SUM(b.SuggestedOffer) AS FLOAT)/ CAST(NULLIF(SUM(b.Quantity), 0) AS FLOAT) [avgSuggestedOffer],
	AVG(b.OnlineOffer) [OnlineOffer],
	AVG(b.OnlineBuyOfferPct) [OnlineBuyOfferPct],
	AVG(b.AmazonLowestPrice) [AmazonLowestPrice],
	MAX(b.AmazonSalesRank) [AmazonSalesRank]
	--CAST(COUNT(b.OnlineOffer) AS FLOAT) /NULLIF(CAST(SUM(b.Quantity) AS FLOAT), 0) [pct_OnlineOffer]
FROM #Buys b
WHERE b.OnlineOffer IS NOT NULL
GROUP BY b.CatalogID 
ORDER BY totalQty DESC

DROP TABLE #Buys
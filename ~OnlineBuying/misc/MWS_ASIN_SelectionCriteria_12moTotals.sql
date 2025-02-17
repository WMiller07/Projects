SELECT 
	sr.ASIN,
	AVG(CAST(sr.Sales_Rank AS FLOAT)) [Sales_Rank]
INTO #SalesRanks
FROM Azure_HPB1.dbo.cs_Amazon_SalesRanks sr
WHERE 
	sr.Product_Category_Name = 'Overall Sales Rank'
AND sr.Request_Date <= GETDATE()
AND sr.Request_Date >= DATEADD(YEAR, -1, GETDATE())
GROUP BY sr.ASIN

SELECT 
	sr.ASIN,
	ISNULL(ili.Identifier, ilu.Identifier) AS [Identifier]
INTO #Identifiers
FROM #SalesRanks sr
	LEFT OUTER JOIN Azure_HPB1.dbo.cs_Amazon_IdentifierLink ili
		ON sr.ASIN = ili.ASIN
		AND ili.IdentifierType = 'ISBN13'
	LEFT OUTER JOIN Azure_HPB1.dbo.cs_Amazon_IdentifierLink ilu
		ON sr.ASIN = ilu.ASIN
		AND ilu.IdentifierType = 'UPC'

SELECT 
	i.Identifier,
	i.ASIN
INTO #DuplicatedIdentifiers
FROM #Identifiers i
	INNER JOIN (
			SELECT 
				Identifier,
				COUNT(ASIN) [count]
			FROM #Identifiers
			GROUP BY Identifier
			HAVING COUNT(ASIN) > 1) d
		ON i.Identifier = d.Identifier


SELECT
	lol.ASIN,
	SUM(lol.Avg_SellerFeedbackCount) [Avg_SellerFeedbackCount],
	SUM(lol.Cnt_OffersConsidered)  [Cnt_OffersConsidered]
INTO #OfferListings
FROM Azure_HPB1.dbo.cs_Amazon_LowestOfferListings lol
WHERE
	lol.Request_Date <= GETDATE()
AND	lol.Request_Date >= DATEADD(YEAR, -1, GETDATE())
GROUP BY lol.ASIN


SELECT 
	oc.ASIN,
	SUM(oc.Offer_Count_Used) [Offer_Count_Used],
	SUM(oc.Offer_Count_New) [Offer_Count_New]
INTO #OfferCounts
FROM Azure_HPB1.dbo.cs_Amazon_TotalOfferCounts oc
WHERE 
	oc.Request_Date <= GETDATE()
AND	oc.Request_Date >= DATEADD(YEAR, -1, GETDATE())
GROUP BY oc.ASIN


SELECT
	di.Identifier,
	di.ASIN,
	sr.Sales_Rank,
	ol.Avg_SellerFeedbackCount,
	ol.Cnt_OffersConsidered,
	oc.Offer_Count_Used,
	oc.Offer_Count_New,
	aa.Format,
	aa.Binding,
	aa.Weight
FROM #DuplicatedIdentifiers di
	LEFT OUTER JOIN #OfferListings ol
		ON di.ASIN = ol.ASIN
	LEFT OUTER JOIN #OfferCounts oc
		ON di.ASIN = oc.ASIN
	LEFT OUTER JOIN #SalesRanks sr
		ON di.ASIN = sr.ASIN
	LEFT OUTER JOIN Azure_HPB1.dbo.cs_Amazon_Attributes aa
		ON di.ASIN = aa.ASIN
ORDER BY di.Identifier

DROP TABLE #OfferListings
DROP TABLE #SalesRanks
DROP TABLE #OfferCounts
DROP TABLE #DuplicatedIdentifiers
DROP TABLE #Identifiers
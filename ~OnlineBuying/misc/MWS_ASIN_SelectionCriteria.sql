
SELECT 
	sr.ASIN,
	sr.Sales_Rank
INTO #SalesRanks
FROM Azure_HPB1.dbo.cs_Amazon_SalesRanks sr
	INNER JOIN (
			SELECT 
				sr.ASIN,
				MAX(sr.Request_Date) [last_Request_Date]
			FROM Azure_HPB1.dbo.cs_Amazon_SalesRanks sr
			WHERE sr.Product_Category_Name = 'Overall Sales Rank'
			GROUP BY sr.ASIN) srs
				ON sr.ASIN = srs.ASIN
				AND sr.Request_Date = srs.last_Request_Date
WHERE
	sr.Product_Category_Name = 'Overall Sales Rank'

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
	lol.Avg_SellerFeedbackCount,
	lol.Cnt_OffersConsidered
INTO #OfferListings
FROM Azure_HPB1.dbo.cs_Amazon_LowestOfferListings lol
	INNER JOIN (
			SELECT 
				lol.ASIN,
				MAX(lol.Request_Date) [last_RequestDate]
			FROM Azure_HPB1.dbo.cs_Amazon_LowestOfferListings lol
			GROUP BY lol.ASIN
			) lols
		ON lol.ASIN = lols.ASIN
		AND lol.Request_Date = lols.last_RequestDate


SELECT 
	oc.ASIN,
	oc.Offer_Count_Used,
	oc.Offer_Count_New
INTO #OrderCounts
FROM Azure_HPB1.dbo.cs_Amazon_TotalOfferCounts oc
	INNER JOIN (
			SELECT 
				oc.ASIN,
				MAX(oc.Request_Date) [last_RequestDate]
			FROM Azure_HPB1.dbo.cs_Amazon_TotalOfferCounts oc
			GROUP BY oc.ASIN
			) ocs
		ON oc.ASIN = ocs.ASIN
		AND oc.Request_Date = ocs.last_RequestDate


SELECT 
	di.Identifier,
	di.ASIN,
	sr.Sales_Rank,
	ol.Avg_SellerFeedbackCount,
	ol.Cnt_OffersConsidered,
	oc.Offer_Count_Used,
	oc.Offer_Count_New,
	aa.Format,
	aa.Weight
FROM #DuplicatedIdentifiers di
	LEFT OUTER JOIN #SalesRanks sr
		ON di.ASIN = sr.ASIN
	LEFT OUTER JOIN #OfferListings ol
		ON di.ASIN = ol.ASIN
	LEFT OUTER JOIN #OrderCounts oc
		ON di.ASIN = oc.ASIN
	LEFT OUTER JOIN Azure_HPB1.dbo.cs_Amazon_Attributes aa
		ON di.ASIN = aa.ASIN
ORDER BY di.Identifier

DROP TABLE #OfferListings
DROP TABLE #SalesRanks
DROP TABLE #OrderCounts
DROP TABLE #DuplicatedIdentifiers
DROP TABLE #Identifiers

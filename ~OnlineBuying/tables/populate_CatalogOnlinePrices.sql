USE [Buy_Analytics_Test]

--MIN is used to select the lowest of the lowest Amazon prices in cases where there are more than one ASIN for an ISBN/UPC

INSERT INTO Buy_Analytics_Test.dbo.CatalogOnlinePrices
SELECT 
	c.CatalogID,
	MIN(im.AmazonLowestPrice) [AmazonLowestPrice],
	MAX(im.LastUpdated) [LastUpdated]
FROM ISIS.dbo.Inventory_Monsoon im
	INNER JOIN (
			SELECT 
				im.[ASIN],
				MAX(im.LastUpdated) [last_ASINUpdate]
			FROM ISIS.dbo.Inventory_Monsoon im
			WHERE im.SKU NOT LIKE 'D_%'
				AND im.SKU NOT LIKE 'mon%'
				AND im.AmazonLowestPrice > 0
				AND im.Condition = 'Good'
			GROUP BY im.[ASIN]
			) u
		ON im.[ASIN] = u.[ASIN]
		AND im.LastUpdated = u.last_ASINUpdate
	INNER JOIN Base_Analytics_Cashew.dbo.IdentifierToCatalogIdMapping c
		ON ISNULL(im.ISBN, im.UPC) = ISNULL(c.ISBN, c.UPC)
WHERE c.CatalogID IS NOT NULL
GROUP BY c.CatalogID
ORDER BY c.CatalogID
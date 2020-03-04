SELECT 
	spi.LocationNo,
	spi.ProductType,
	spi.ItemCode,
	spi.SipsID,
	spi.Price,
	spi.DateInStock
INTO #SipsProductInventory
FROM ReportsData..SipsProductInventory spi
UNION
SELECT 
	spi.LocationNo,
	spi.ProductType,
	spi.ItemCode,
	spi.SipsID,
	spi.Price,
	spi.DateInStock
FROM archSIPS..archSipsProductInventory spi
UNION
SELECT 
	spi.LocationNo,
	spi.ProductType,
	spi.ItemCode,
	spi.SipsID,
	spi.Price,
	spi.DateInStock
FROM archSIPS..archSipsProductInventory2 spi
UNION
SELECT 
	spi.LocationNo,
	spi.ProductType,
	spi.ItemCode,
	spi.SipsID,
	spi.Price,
	spi.DateInStock
FROM archSIPS..archSipsProductInventory3 spi


SELECT
	DATEPART(YEAR, spi.DateInStock) [BusinessYear],
	spm.CatalogID,
	COUNT(spi.ItemCode) [count_SipsItems]
INTO #TitleItemCount
FROM #SipsProductInventory spi
	INNER JOIN ReportsData..SipsProductMaster spm
		ON spi.SipsID = spm.SipsID
GROUP BY 
	DATEPART(YEAR, spi.DateInStock),
	spm.CatalogID

SELECT 
	tic.BusinessYear,
	COUNT(tic.CatalogID) [count_Titles],
	SUM(tic.count_SipsItems) [count_Items],
	COUNT(CASE
			WHEN tic.count_SipsItems = 1
			THEN tic.CatalogID
			END) [count_Titles_1],
	COUNT(CASE
			WHEN tic.count_SipsItems >= 1
			AND tic.count_SipsItems < 10
			THEN tic.CatalogID
			END) [count_Titles_1to10],
	COUNT(CASE
			WHEN tic.count_SipsItems >= 10
			AND tic.count_SipsItems < 100
			THEN tic.CatalogID
			END) [count_Titles_10to100],
	COUNT(CASE
			WHEN tic.count_SipsItems >= 100
			THEN tic.CatalogID
			END) [count_Titles_100plus],

	SUM(CASE
			WHEN tic.count_SipsItems = 1
			THEN tic.count_SipsItems
			END) [count_TitleItems_1],
	SUM(CASE
			WHEN tic.count_SipsItems >= 1
			AND tic.count_SipsItems < 10
			THEN tic.count_SipsItems
			END) [count_TitleItems_1to10],
	SUM(CASE
			WHEN tic.count_SipsItems >= 10
			AND tic.count_SipsItems < 100
			THEN tic.count_SipsItems
			END) [count_TitleItems_10to100],
	SUM(CASE
			WHEN tic.count_SipsItems >= 100
			THEN tic.count_SipsItems
			END) [count_TitleItems_100plus]
FROM #TitleItemCount tic
GROUP BY tic.BusinessYear
ORDER BY tic.BusinessYear
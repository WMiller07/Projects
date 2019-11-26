DECLARE @EndDate DATE = '11/1/2019'
DECLARE @StartDate DATE

SELECT
	@StartDate = DATEADD(MONTH, -13, @EndDate)

SELECT 
	lc.CatalogID,
	COUNT(lc.ItemCode) [count_ActiveItems]
INTO #TitlesIncluded
FROM Buy_Analytics..ItemCode_LifeCycle lc
WHERE 
	ISNULL(lc.Last_ScanDate, lc.First_RecordDate) >= @StartDate AND
	ISNULL(lc.Last_ScanDate, lc.First_RecordDate) < @EndDate
GROUP BY lc.CatalogID

SELECT 
	SUM(ti.count_ActiveItems) [count_AllIncludedItems],
	SUM(CASE
		WHEN ti.count_ActiveItems >= 5
		THEN ti.count_ActiveItems
		END) [count_T5IncludedItems],
	SUM(CASE
		WHEN ti.count_ActiveItems >= 3
		THEN ti.count_ActiveItems
		END) [count_T3IncludedItems],
	CAST(SUM(CASE
		WHEN ti.count_ActiveItems >= 5
		THEN ti.count_ActiveItems
		END) AS FLOAT)/
			CAST(SUM(ti.count_ActiveItems) AS FLOAT)	 [pct_T5IncludedItems],
	CAST(SUM(CASE
		WHEN ti.count_ActiveItems >= 3
		THEN ti.count_ActiveItems
		END) AS FLOAT)/
			CAST(SUM(ti.count_ActiveItems) AS FLOAT)	 [pct_T3IncludedItems]
FROM #TitlesIncluded ti


SELECT 
	COUNT(spi.ItemCode) [count_ItemsPriced],
	COUNT(CASE
			WHEN ti5.CatalogID IS NOT NULL
			THEN spi.ItemCode
			END) [count_T5ItemsPriced],
	COUNT(CASE
			WHEN ti3.CatalogID IS NOT NULL
			THEN spi.ItemCode
			END) [count_T3ItemsPriced],
	CAST(COUNT(CASE
			WHEN ti5.CatalogID IS NOT NULL
			THEN spi.ItemCode
			END) AS FLOAT) /  
			CAST(COUNT(spi.ItemCode) AS FLOAT) [pct_T5ItemsPriced],
	CAST(COUNT(CASE
			WHEN ti3.CatalogID IS NOT NULL
			THEN spi.ItemCode
			END) AS FLOAT) /  
				CAST(COUNT(spi.ItemCode) AS FLOAT) [pct_T3ItemsPriced]
FROM ReportsData..SipsProductInventory spi
	INNER JOIN ReportsData..SipsProductMaster spm
		ON spi.SipsID = spm.SipsID
	LEFT OUTER JOIN #TitlesIncluded ti3
		ON spm.CatalogId = ti3.CatalogID
		AND ti3.count_ActiveItems >= 3
	LEFT OUTER JOIN #TitlesIncluded ti5
		ON spm.CatalogId = ti5.CatalogID
		AND ti5.count_ActiveItems >= 5
WHERE spi.DateInStock >= @StartDate
	AND spi.DateInStock < @EndDate

--DROP TABLE #TitlesIncluded

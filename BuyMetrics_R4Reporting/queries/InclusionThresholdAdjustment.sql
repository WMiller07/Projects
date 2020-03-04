SELECT
	lc.CatalogID,
	spi.LocationNo,
	COUNT(lc.ItemCode) [count_Items]
INTO #CatalogTitles
FROM Buy_Analytics..ItemCode_LifeCycle lc
	INNER JOIN ReportsData..SipsProductInventory spi
		ON lc.ItemCode = spi.ItemCode
where coalesce(lc.Last_ScanDate, lc.First_RecordDate) > dateadd(Month, -13, current_timestamp) and CatalogID IS NOT NULL
GROUP BY lc.CatalogID, spi.LocationNo WITH ROLLUP

SELECT 
	COUNT(DISTINCT 
			CASE 
				WHEN ct.count_Items >= 5
				AND ct.LocationNo IS NULL
				THEN ct.CatalogID
				END) [chain_TitleCount_5Thresh],
	SUM(CASE 
			WHEN ct.count_Items >= 5
			AND ct.LocationNo IS NULL
			THEN count_Items
			END)  [chain_ItemCount_5Thresh],
	COUNT(DISTINCT 
			CASE 
				WHEN ct.count_Items >= 3
				AND ct.LocationNo IS NULL
				THEN ct.CatalogID
				END) [chain_TitleCount_3Thresh],
	SUM(CASE 
			WHEN ct.count_Items >= 3
			AND ct.LocationNo IS NULL
			THEN count_Items
			END)  [chain_ItemCount_3Thresh],

	COUNT(DISTINCT 
			CASE 
				WHEN ct.count_Items >= 5
				AND ct.LocationNo IS NOT NULL
				THEN ct.CatalogID
				END) [location_TitleCount_5Thresh],
	SUM(CASE 
			WHEN ct.count_Items >= 5
			AND ct.LocationNo IS NOT NULL
			THEN count_Items
			END)  [location_ItemCount_5Thresh],
	COUNT(DISTINCT 
			CASE 
				WHEN ct.count_Items >= 3
				AND ct.LocationNo IS NOT NULL
				THEN ct.CatalogID
				END) [location_TitleCount_3Thresh],
	SUM(CASE 
			WHEN ct.count_Items >= 3
			AND ct.LocationNo IS NOT NULL
			THEN count_Items
			END)  [location_ItemCount_3Thresh]
FROM #CatalogTitles ct
WHERE ct.CatalogID IS NOT NULL

DROP TABLE #CatalogTitles
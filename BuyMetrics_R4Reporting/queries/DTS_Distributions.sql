SELECT 
	CatalogID,
	Total_Item_Count,
	CAST((Total_Accumulated_Days_With_Trash_Penalty / Total_Item_Count) AS INT) [AccDays]
INTO #AccDays
FROM [Sandbox].[dbo].[BuyAlgorithm_AggregateData_Chain]

SELECT
	AccDays,
	SUM(Total_Item_Count) [count_Items]
FROM #AccDays
GROUP BY AccDays
ORDER BY AccDays


SELECT 
	bt.BuyGradeName,
	SUM(ad.Total_Item_Count) [count_Items]
INTO #GradeAccDays
FROM #AccDays ad
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R3 bt
		ON ad.AccDays > bt.AccDaysRangeFrom
		AND ad.AccDays <= bt.AccDaysRangeTo
GROUP BY bt.BuyGradeName

SELECT
	gad.BuyGradeName,
	gad.count_Items,
	CAST(gad.count_Items AS FLOAT) /
		 CAST(sad.total_Items AS FLOAT) [pct_Items]
FROM #GradeAccDays gad
	CROSS JOIN (SELECT SUM(count_Items) [total_Items] FROM #GradeAccDays) sad
ORDER BY gad.BuyGradeName


SELECT 
	bt.BuyGradeName,
	ad.AccDays,
	SUM(ad.Total_Item_Count) [count_Items]
FROM #AccDays ad
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R3 bt
		ON ad.AccDays > bt.AccDaysRangeFrom
		AND ad.AccDays <= bt.AccDaysRangeTo
GROUP BY bt.BuyGradeName,ad. AccDays
ORDER BY AccDays

DROP TABLE #AccDays
DROP TABLE #GradeAccDays

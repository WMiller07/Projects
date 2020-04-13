SELECT 
	CASE WHEN GROUPING(t.binding) = 1 THEN 'All' ELSE t.binding END [catalogBinding],
	COUNT(t.CatalogID) [countTitles],
	COUNT(t.weight) [countHaveWeightData],
	CAST(COUNT(t.weight) AS FLOAT) / CAST(COUNT(t.CatalogID) AS FLOAT) [pctHaveWeightData],
	AVG(t.weight) [avgWeight]
FROM Catalog.dbo.titles t
GROUP BY t.binding WITH ROLLUP
HAVING COUNT(t.CatalogID) > 10000
ORDER BY countTitles DESC
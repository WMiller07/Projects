SELECT 
	t.catalogId,
	t.title,
	t.author,
	t.isbn13,
	t.binding [CatalogBinding],
	LOWER(sbj.subjectName) [CatalogSubject],
	COUNT(DISTINCT slm.LocationNo) [RetailLocationCount],
	COUNT(
		CASE
			WHEN slm.StoreType = 'S'
			THEN sis.ItemCodeSips
			END) [SipsItemCount_RetailStore],
	COUNT(
		CASE 
			WHEN spi.LocationNo = '00275'
			AND s.ShelfDescription LIKE 'RL%'
		THEN sis.ItemCodeSips
		END) [SipsItemCount_Boomerang],
	AVG(spi.Price) [AvgPrice],
	MIN(spi.Price) [MinPrice],
	MAX(spi.Price) [MaxPrice]
--INTO #ItemCounts
FROM ReportsData..SipsProductInventory spi
	INNER JOIN ReportsData..SipsProductMaster spm
		ON spi.SipsID = spm.SipsID
	INNER JOIN Catalog..titles t
		ON spm.CatalogId = t.catalogId
	INNER JOIN ReportsData..ShelfItemScan sis
		ON spi.ItemCode = sis.ItemCodeSips
	INNER JOIN ReportsData..ShelfScan ss
		ON sis.ShelfScanID = ss.ShelfScanID
	INNER JOIN ReportsData..Shelf s
		ON ss.ShelfID = s.ShelfID
	LEFT OUTER JOIN Catalog..subjects sbj
		ON t.subjectId = sbj.subjectId
	LEFT OUTER JOIN ReportsData..StoreLocationMaster slm
		ON s.LocationID = slm.LocationId
		AND slm.StoreType = 'S'
WHERE t.binding NOT IN ('Mass Market Paperback', 'Paperback')
	AND ((t.isbn13 IS NOT NULL) OR
		(t.binding NOT IN ('Hardcover', 'Trade Paperback')))
GROUP BY 	
	t.catalogId,
	t.title,
	t.author,
	t.binding,
	t.isbn13,
	sbj.subjectName
HAVING COUNT(sis.ItemCodeSips) >= 300
ORDER BY SipsItemCount_RetailStore DESC


----Detailed list of all SipsItemRecords aggregated above
--SELECT 
--	t.catalogId,
--	t.title,
--	t.author,
--	t.binding [CatalogBinding],
--	sbj.subjectName,
--	slm.LocationNo [RetailLocation],
--	CASE
--		WHEN slm.StoreType = 'S'
--		THEN sis.ItemCodeSips 
--		END	 [SipsItem_RetailStore],
--		CASE 
--			WHEN spi.LocationNo = '00275'
--			AND s.ShelfDescription LIKE 'RL%'
--		THEN sis.ItemCodeSips
--		END [SipsItem_Boomerang],
--	spi.Price,
--	ic.SipsItemCount_RetailStore,
--	ic.SipsItemCount_Boomerang
--FROM ReportsData..SipsProductInventory spi
--	INNER JOIN ReportsData..SipsProductMaster spm
--		ON spi.SipsID = spm.SipsID
--	INNER JOIN Catalog..titles t
--		ON spm.CatalogId = t.catalogId
--	INNER JOIN ReportsData..ShelfItemScan sis
--		ON spi.ItemCode = sis.ItemCodeSips
--	INNER JOIN ReportsData..ShelfScan ss
--		ON sis.ShelfScanID = ss.ShelfScanID
--	INNER JOIN ReportsData..Shelf s
--		ON ss.ShelfID = s.ShelfID
--	INNER JOIN #ItemCounts ic
--		ON t.catalogId = ic.catalogId
--	LEFT OUTER JOIN Catalog..subjects sbj
--		ON t.subjectId = sbj.subjectId
--	LEFT OUTER JOIN ReportsData..StoreLocationMaster slm
--		ON s.LocationID = slm.LocationId
--		AND slm.StoreType = 'S'
--ORDER BY ic.SipsItemCount_RetailStore DESC, RetailLocation, CatalogID, SipsItem_RetailStore, SipsItem_Boomerang 

--DROP TABLE #ItemCounts

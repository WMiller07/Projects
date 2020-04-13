DECLARE @EndDate DATE = '3/9/2020'	
DECLARE @StartDate DATE = DATEADD(MONTH, -13, @EndDate)			
			
SELECT 			
	tbd.SipsItemCode,
	tbh.UpdateTime [date_Disposed],		
	1 [Disposed]		
INTO #Disposed			
FROM [ReportsData].[dbo].[SipsTransferBinHeader] tbh			
	INNER JOIN ReportsData..SipsTransferBinDetail tbd		
		ON tbh.TransferBinNo = tbd.TransferBinNo	
WHERE 			
		tbh.TransferType IN (1, 2, 6, 7)	
	AND tbh.CreateTime >= @StartDate		
	AND tbh.CreateTime <= @EndDate	
	
	
SELECT
	spc.ItemCode,
	spc.ModifiedTime [date_FirstPriceChange],
	spc.OldPrice,
	spc.NewPrice 
INTO #Pricing_OriginalPrice
FROM ReportsData..SipsPriceChanges spc
	INNER JOIN (
		SELECT 
			spc.ItemCode,
			MIN(spc.ModifiedTime) [first_ModifiedTime]
		FROM ReportsData..SipsPriceChanges spc
			INNER JOIN ReportsData..SipsProductInventory spi
				ON spc.ItemCode = spi.ItemCode
		WHERE spc.OldPrice < 100000
		GROUP BY spc.ItemCode
				) f
			ON spc.ItemCode = f.ItemCode
			AND spc.ModifiedTime = f.first_ModifiedTime	
			
SELECT 			
	slm.LocationNo,		
	spi.ItemCode,	
	spi.SipsID,	
	spi.DateInStock,		
	spi.ProductType,		
	sc.[Subject],
	t.CatalogId,		
	t.author [Author],		
	t.artist [Artist],		
	t.title [Title],			
	CONVERT(VARCHAR, t.releaseDate, 10) [PublicationDate],		
	t.[binding] [Binding],		
	t.isbn13 [ISBN],		
	ISNULL(d.Disposed, 0) [Disposed],
	t.listPrice,
	spi.Price [CurrentPrice],
	pop.OldPrice [OriginalPrice],	
	ssh.RegisterPrice,
	DATEDIFF(DAY, spi.DateInStock, GETDATE()) [DaysInHistory],
	CASE	
		WHEN iss.first_ScanDate <= ssh.BusinessDate 	
		THEN DATEDIFF(ss, ISNULL(iss.first_ScanDate, spi.DateInStock), ssh.BusinessDate) / 60 / 60 / 24	
		ELSE DATEDIFF(ss, spi.DateInStock, ssh.BusinessDate) / 60 / 60 / 24
		END [DaysToSell],
	CASE	
		WHEN (DATEDIFF(ss, ISNULL(iss.first_ScanDate, spi.DateInStock), COALESCE(ssh.BusinessDate, d.date_Disposed, GETDATE())) / 60 / 60 / 24) < 1000
			THEN (DATEDIFF(ss, ISNULL(iss.first_ScanDate, spi.DateInStock), COALESCE(ssh.BusinessDate, d.date_Disposed, GETDATE())) / 60 / 60 / 24)
		END [DaysOnShelf]			
INTO #Included
FROM ReportsData..SipsProductInventory spi			
	INNER JOIN ReportsData..SipsProductMaster spm		
		ON spi.SipsID = spm.SipsID	
	INNER JOIN [Catalog]..titles t		
		ON spm.CatalogId = t.catalogId	
	INNER JOIN ReportsView..StoreLocationMaster slm		
		ON spi.LocationID = slm.LocationId	
		AND slm.StoreStatus = 'O'	
		AND slm.StoreType = 'S'	
	INNER JOIN ReportsData..SubjectSummary ss
		ON spi.SubjectKey = ss.SubjectKey
	LEFT OUTER JOIN #Disposed d		
		ON spi.ItemCode = d.SipsItemCode	
	LEFT OUTER JOIN ReportsData..SipsSalesHistory ssh		
		ON	spi.ItemCode = ssh.SipsItemCode
		AND ssh.IsReturn = 'N'	
		AND ssh.BusinessDate >= @StartDate	
		AND ssh.BusinessDate < @EndDate	
	LEFT OUTER JOIN MathLab..FirstScans_Sips iss
		ON spi.ItemCode = iss.ItemCode
	LEFT OUTER JOIN MathLab..SubjectClassifier_ShelfScan sc
		ON spi.SipsID = sc.SipsID
		AND sc.rank_Section = 1
	LEFT OUTER JOIN #Pricing_OriginalPrice pop
		ON spi.ItemCode = pop.ItemCode
WHERE 			
		spi.DateInStock >= @startdate	
	AND spi.DateInStock < @enddate		
	
			

SELECT 				
	i.CatalogId,
	i.Subject [Section],
	COUNT(i.ItemCode) [TotalItemCount],
	ROW_NUMBER () OVER (ORDER BY COUNT(i.ItemCode) DESC) [PriceRank]
INTO #LocRanks			
FROM #Included i 			
GROUP BY				
	i.catalogId,	
	i.Subject
	
			
SELECT 
	lr.PriceRank,
	lr.CatalogId,
	i.Binding,
	lr.TotalItemCount,
	i.LocationNo,
	i.Subject [Section],
	i.DateInStock,
	i.Disposed,
	i.DaysInHistory,
	i.DaysToSell,
	i.DaysOnShelf,
	i.listPrice,
	ISNULL(i.OriginalPrice, i.CurrentPrice) [OriginalPrice],
	i.CurrentPrice,
	i.RegisterPrice
FROM #LocRanks lr		
	INNER JOIN #Included i
		ON lr.catalogId = i.catalogId	
WHERE lr.TotalItemCount >= 500
ORDER BY lr.PriceRank ASC
			
			
DROP TABLE #Disposed			
DROP TABLE #Included
DROP TABLE #LocRanks
DROP TABLE #Pricing_OriginalPrice		

DECLARE @startdate DATE = '1/1/2019'			
DECLARE @enddate DATE = '3/9/2020'				
			
SELECT 			
	tbd.SipsItemCode,		
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
	t.catalogId,		
	t.author [Author],		
	t.artist [Artist],		
	t.title [Title],			
	CONVERT(VARCHAR, t.releaseDate, 10) [PublicationDate],		
	t.[binding] [Binding],		
	t.isbn13 [ISBN],		
	d.Disposed,
	t.listPrice,
	spi.Price [CurrentPrice],
	pop.OldPrice [OriginalPrice],	
	ssh.RegisterPrice,
	CASE	
		WHEN iss.first_ScanDate <= ssh.BusinessDate 	
		THEN DATEDIFF(DAY, ISNULL(iss.first_ScanDate, spi.DateInStock), ssh.BusinessDate)	
		ELSE DATEDIFF(DAY, spi.DateInStock, ssh.BusinessDate)
		END [ScannedDtS]			
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
	ROW_NUMBER () OVER (ORDER BY COUNT(i.ItemCode) DESC) [PriceRank],		
	i.catalogId,		
	i.[Binding],		
	i.ProductType,	
	sc.Subject [Subject_ShelfScan], 
	i.Subject [Subject_Sips],	
	i.Author,		
	i.Artist,		
	i.Title,		
	i.PublicationDate,		
	i.[ISBN],		
	AVG(		
		CASE	
		WHEN iss.first_ScanDate <= ssh.BusinessDate 	
		THEN DATEDIFF(DAY, iss.first_ScanDate, ssh.BusinessDate)	
		END) [AvgScannedDtS],	
	AVG(DATEDIFF(DAY, i.DateInStock, ssh.BusinessDate) -		
		DATEDIFF(DAY, iss.first_ScanDate, ssh.BusinessDate)) [AvgShelvingDelay],	
	COUNT(i.ItemCode) [QtyPriced],		
	COUNT(i.Disposed) [QtyTrashed],		
	COUNT(ssh.SipsItemCode) [QtySold],	
	CAST(COUNT(ssh.ItemCode) AS FLOAT) / CAST(COUNT(i.ItemCode) AS FLOAT) [PctSellThrough], 	
	ROUND(CAST(AVG(ssh.RegisterPrice) AS MONEY), 2) [AvgSalesPrice],		
	COUNT(		
		CASE	
		WHEN ssh.RegisterPrice >= (i.listPrice * 0.40)	
		THEN 1	
		END) [QtySoldHalfList],	
	ROUND(CAST(COUNT(		
		CASE 	
		WHEN ssh.RegisterPrice >= (i.listPrice * 0.40)	
		THEN 1	
		END) AS FLOAT)/	
			NULLIF(CAST(COUNT(ssh.SipsItemCode) AS FLOAT), 0), 2) [PctHalfList],
	COUNT(		
		CASE	
		WHEN ssh.RegisterPrice = ROUND(ssh.RegisterPrice,0)	
		AND ssh.RegisterPrice <= 3.00	
		THEN 1	
		END) [QtySoldClearance],	
	ROUND(CAST(COUNT(		
		CASE	
		WHEN ssh.RegisterPrice = ROUND(ssh.RegisterPrice,0)	
		AND ssh.RegisterPrice <= 3.00	
		THEN 1	
		END) AS FLOAT)/	
			NULLIF(CAST(COUNT(ssh.SipsItemCode) AS FLOAT), 0), 2) [PctClearanced],
	SUM(ssh.RegisterPrice) [TotalSales]		
INTO #LocRanks			
FROM #Included i 			
	LEFT OUTER JOIN ReportsData..SipsSalesHistory ssh		
		ON	i.ItemCode = ssh.SipsItemCode
		AND ssh.IsReturn = 'N'	
		AND ssh.BusinessDate >= @StartDate	
		AND ssh.BusinessDate < @EndDate	
	LEFT OUTER JOIN MathLab..FirstScans_Sips iss
		ON i.ItemCode = iss.ItemCode
	LEFT OUTER JOIN MathLab..SubjectClassifier_ShelfScan sc
		ON i.SipsID = sc.SipsID
		AND sc.rank_Section = 1
GROUP BY				
	i.catalogId,	
	i.Binding,	
	i.author,		
	i.Artist,		
	i.title,		
	i.PublicationDate,		
	i.ProductType,	
	i.[ISBN],
	sc.Subject,
	i.Subject
	
			
SELECT 
	lr.PriceRank,
	lr.catalogId,
	lr.Binding,
	lr.ProductType,
	lr.Subject_ShelfScan,
	--lr.Title,
	lr.PublicationDate,
	--lr.ISBN,
	lr.AvgScannedDtS,
	lr.AvgShelvingDelay,
	lr.QtyPriced,
	lr.QtyTrashed,
	lr.QtySold,
	lr.PctSellThrough,
	lr.AvgSalesPrice,
	lr.PctHalfList,
	lr.PctClearanced,
	lr.TotalSales,
	i.LocationNo,
	i.DateInStock,
	i.Disposed,
	i.ScannedDtS,
	i.Subject [item_SubjectShelfScan],
	i.listPrice,
	ISNULL(i.OriginalPrice, i.CurrentPrice) [OriginalPrice],
	i.CurrentPrice,
	i.RegisterPrice
FROM #LocRanks lr		
	INNER JOIN #Included i
		ON lr.catalogId = i.catalogId	
WHERE lr.PriceRank <=500
ORDER BY lr.PriceRank ASC
			
			
DROP TABLE #Disposed			
DROP TABLE #Included
DROP TABLE #LocRanks
DROP TABLE #Pricing_OriginalPrice		

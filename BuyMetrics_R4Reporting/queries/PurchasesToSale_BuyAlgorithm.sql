DECLARE @StartDate DATE = '1/1/2014'
DECLARE @EndDate DATE = '7/31/2019'

--Get all item extended amounts from HPB_Sales for 2018 and 2019 with product types
SELECT
	slm.LocationNo,
	shh.EndDate,
	shh.SalesXactionID,
	LTRIM(RTRIM(ISNULL(pm.ProductType, spi.ProductType))) [ProductType],
	ISNULL(pm.ItemCode, spi.ItemCode) [ItemCode],
	sih.ExtendedAmt [Sales]
INTO #AllSales
FROM HPB_SALES..SHH2019 shh
	INNER JOIN HPB_SALES..SIH2019 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'
		AND sih.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.StoreType = 'S'
		AND slm.OpenDate <= DATEADD(YEAR, -1, @StartDate)
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = '0'							--Distro items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih.ItemCode, 1) <> '0'						--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'							
	AND shh.EndDate <= @EndDate
UNION ALL
SELECT
	slm.LocationNo,
	shh.EndDate,
	shh.SalesXactionID,
	LTRIM(RTRIM(ISNULL(pm.ProductType, spi.ProductType))) [ProductType],
	ISNULL(pm.ItemCode, spi.ItemCode) [ItemCode],
	sih.ExtendedAmt [Sales]
FROM HPB_SALES..SHH2018 shh
	INNER JOIN HPB_SALES..SIH2018 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
		AND sih.[Status] = 'A'
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.StoreType = 'S'
		AND slm.OpenDate <= DATEADD(YEAR, -1, @StartDate)
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = '0'								--Distro/base items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro/base item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi			
		ON	LEFT(sih.ItemCode, 1) <> '0'							--SIPS items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables ARE NOT stored in the same format as the inventory tables, necessitating conversion.
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'							--Some non-numeric item codes exist in our sales tables. Failing to exclude these results in overflow errors.
	AND shh.EndDate >= @StartDate
UNION ALL
SELECT
	slm.LocationNo,
	shh.EndDate,
	shh.SalesXactionID,
	LTRIM(RTRIM(ISNULL(pm.ProductType, spi.ProductType))) [ProductType],
	ISNULL(pm.ItemCode, spi.ItemCode) [ItemCode],
	sih.ExtendedAmt [Sales]
FROM HPB_SALES..SHH2017 shh
	INNER JOIN HPB_SALES..SIH2017 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
		AND sih.[Status] = 'A'
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.StoreType = 'S'
		AND slm.OpenDate <= DATEADD(YEAR, -1, @StartDate)
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = '0'								--Distro/base items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro/base item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi			
		ON	LEFT(sih.ItemCode, 1) <> '0'							--SIPS items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables ARE NOT stored in the same format as the inventory tables, necessitating conversion.
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'							--Some non-numeric item codes exist in our sales tables. Failing to exclude these results in overflow errors.
	AND shh.EndDate >= @StartDate
UNION ALL
SELECT
	slm.LocationNo,
	shh.EndDate,
	shh.SalesXactionID,
	LTRIM(RTRIM(ISNULL(pm.ProductType, spi.ProductType))) [ProductType],
	ISNULL(pm.ItemCode, spi.ItemCode) [ItemCode],
	sih.ExtendedAmt [Sales]
FROM HPB_SALES..SHH2016 shh
	INNER JOIN HPB_SALES..SIH2016 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
		AND sih.[Status] = 'A'
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.StoreType = 'S'
		AND slm.OpenDate <= DATEADD(YEAR, -1, @StartDate)
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = '0'								--Distro/base items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro/base item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi			
		ON	LEFT(sih.ItemCode, 1) <> '0'							--SIPS items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables ARE NOT stored in the same format as the inventory tables, necessitating conversion.
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'							--Some non-numeric item codes exist in our sales tables. Failing to exclude these results in overflow errors.
	AND shh.EndDate >= @StartDate
UNION ALL
SELECT
	slm.LocationNo,
	shh.EndDate,
	shh.SalesXactionID,
	LTRIM(RTRIM(ISNULL(pm.ProductType, spi.ProductType))) [ProductType],
	ISNULL(pm.ItemCode, spi.ItemCode) [ItemCode],
	sih.ExtendedAmt [Sales]
FROM HPB_SALES..SHH2015 shh
	INNER JOIN HPB_SALES..SIH2015 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
		AND sih.[Status] = 'A'
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.StoreType = 'S'
		AND slm.OpenDate <= DATEADD(YEAR, -1, @StartDate)
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = '0'								--Distro/base items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro/base item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi			
		ON	LEFT(sih.ItemCode, 1) <> '0'							--SIPS items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables ARE NOT stored in the same format as the inventory tables, necessitating conversion.
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'							--Some non-numeric item codes exist in our sales tables. Failing to exclude these results in overflow errors.
	AND shh.EndDate >= @StartDate
UNION ALL
SELECT
	slm.LocationNo,
	shh.EndDate,
	shh.SalesXactionID,
	LTRIM(RTRIM(ISNULL(pm.ProductType, spi.ProductType))) [ProductType],
	ISNULL(pm.ItemCode, spi.ItemCode) [ItemCode],
	sih.ExtendedAmt [Sales]
FROM HPB_SALES..SHH2014 shh
	INNER JOIN HPB_SALES..SIH2014 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
		AND sih.[Status] = 'A'
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationID
		AND slm.StoreType = 'S'
		AND slm.OpenDate <= DATEADD(YEAR, -1, @StartDate)
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = '0'								--Distro/base items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro/base item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi			
		ON	LEFT(sih.ItemCode, 1) <> '0'							--SIPS items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables ARE NOT stored in the same format as the inventory tables, necessitating conversion.
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'							--Some non-numeric item codes exist in our sales tables. Failing to exclude these results in overflow errors.
	AND shh.EndDate >= @StartDate

SELECT 
	slm.LocationNo,	
	DATEADD(MONTH, DATEDIFF(MONTH, 0, bbh.EndDate), 0) [BusinessMonth],
	COUNT(DISTINCT bbh.BuyXactionID) [count_BuyTransactions],
	SUM(bbi.LineOffer) [Purchases],
	SUM(bbi.Quantity) [qty_Purchased]
INTO #Purchases
FROM rHPB_Historical..BuyHeaderHistory bbh
	INNER JOIN rHPB_Historical..BuyItemHistory bbi
		ON bbh.BuyXactionID = bbi.BuyXactionID
		AND bbh.LocationID = bbi.LocationID
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON bbh.LocationID = slm.LocationID
		AND slm.StoreType = 'S'
		AND slm.OpenDate <= DATEADD(YEAR, -1, @StartDate)
WHERE 
		bbh.EndDate >= @StartDate
	AND bbh.EndDate <= @EndDate
	AND bbh.Status = 'A'
	AND bbi.LineOffer <= 10000
GROUP BY slm.LocationNo, DATEADD(MONTH, DATEDIFF(MONTH, 0, bbh.EndDate), 0)--, bbi.BuyType WITH ROLLUP


SELECT
	s.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, s.EndDate), 0) [BusinessMonth],
	COUNT(DISTINCT s.SalesXactionID) [count_SalesTransactions],
	COUNT(s.ItemCode) [qty_Sold],
	SUM(s.Sales) [Sales]
INTO #Sales
FROM #AllSales s
	LEFT OUTER JOIN Sandbox..ProductTypeMap ptm
		ON s.ProductType = ptm.ProductType
GROUP BY s.LocationNo, DATEADD(MONTH, DATEDIFF(MONTH, 0, s.EndDate), 0)--, ptm.BuyType
ORDER BY s.LocationNo, BusinessMonth--, ptm.BuyType

SELECT
	spi.LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, spi.DateInStock), 0) [BusinessMonth],
	COUNT(spi.ItemCode) [count_ItemsPriced]
INTO #Pricing
FROM ReportsData..SipsProductInventory spi
GROUP BY spi.LocationNo, DATEADD(MONTH, DATEDIFF(MONTH, 0, spi.DateInStock), 0)

SELECT 
	s.LocationNo,
	s.BusinessMonth,
	--s.count_SalesTransactions,
	--p.count_BuyTransactions,
	--s.qty_Sold,
	--p.qty_Purchased,
	--s.Sales,
	--p.Purchases,
	--p.Purchases/s.Sales [PSRatio],
	AVG(SUM(s.count_SalesTransactions)) OVER (PARTITION BY s.LocationNo ORDER BY s.BusinessMonth  ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [count_SalesTransactions_12mo],
	AVG(SUM(p.count_BuyTransactions)) OVER (PARTITION BY s.LocationNo ORDER BY s.BusinessMonth  ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [count_BuyTransactions_12mo],
	AVG(SUM(s.qty_Sold)) OVER (PARTITION BY s.LocationNo ORDER BY s.BusinessMonth  ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [qty_Sold_12mo],
	AVG(SUM(p.qty_Purchased)) OVER (PARTITION BY s.LocationNo ORDER BY s.BusinessMonth  ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [qty_Purchased_12mo],
	AVG(SUM(pr.count_ItemsPriced)) OVER (PARTITION BY s.LocationNo ORDER BY s.BusinessMonth  ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [qty_Priced_12mo],
	AVG(SUM(s.Sales)) OVER (PARTITION BY s.LocationNo ORDER BY s.BusinessMonth  ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [Sales_12mo],
	AVG(SUM(p.Purchases)) OVER (PARTITION BY s.LocationNo ORDER BY s.BusinessMonth  ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) [Purchases_12mo],
	AVG(SUM(p.Purchases)) OVER (PARTITION BY s.LocationNo ORDER BY s.BusinessMonth  ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) /
		NULLIF(AVG(SUM(s.Sales)) OVER (PARTITION BY s.LocationNo ORDER BY s.BusinessMonth  ROWS BETWEEN 11 PRECEDING AND CURRENT ROW), 0) [PSRatio_12mo]
INTO #PSRatio
FROM #Purchases p
	INNER JOIN #Sales s
		ON p.LocationNo = s.LocationNo
		AND p.BusinessMonth = s.BusinessMonth
		AND p.LocationNo IS NOT NULL
	INNER JOIN #Pricing pr
		ON p.LocationNo = pr.LocationNo
		AND p.BusinessMonth = pr.BusinessMonth
	--INNER JOIN Sandbox..LocBuyAlgorithms lba
	--	ON s.LocationNo = lba.LocationNo
	--	AND lba.VersionNo = 'v1.r3'
GROUP BY s.LocationNo, s.BusinessMonth
ORDER BY LocationNo, BusinessMonth

SELECT
	ps.LocationNo,
	ps.BusinessMonth,
	ps.count_SalesTransactions_12mo,
	ps.count_BuyTransactions_12mo,
	ps.qty_Purchased_12mo,
	ps.qty_Sold_12mo,
	ps.Sales_12mo,
	ps.Purchases_12mo,
	CAST(ps.qty_Purchased_12mo AS FLOAT)/CAST(ps.count_BuyTransactions_12mo AS FLOAT) [avg_QtyPerBuy],
	CAST(ps.Purchases_12mo AS FLOAT)/CAST(ps.count_BuyTransactions_12mo AS FLOAT) [avg_CostPerBuy],
	CAST(ps.Purchases_12mo AS FLOAT)/CAST(ps.qty_Purchased_12mo AS FLOAT) [avg_ItemCost],
	ps.PSRatio_12mo,
	ps.count_BuyTransactions_12mo - LAG(ps.count_BuyTransactions_12mo, 6, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [6moChange_CountBuyTransactions],
	ps.count_BuyTransactions_12mo - LAG(ps.count_BuyTransactions_12mo, 12, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [12moChange_CountBuyTransactions],
	ps.count_SalesTransactions_12mo - LAG(ps.count_SalesTransactions_12mo, 6, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [6moChange_CountSalesTransactions],
	ps.count_SalesTransactions_12mo - LAG(ps.count_SalesTransactions_12mo, 12, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [12moChange_CountSalesTransactions],
	ps.qty_Purchased_12mo - LAG(ps.qty_Purchased_12mo, 6, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [6moChange_QtyPurchased],
	ps.qty_Purchased_12mo - LAG(ps.qty_Purchased_12mo, 12, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [12moChange_QtyPurchased],
	ps.qty_Priced_12mo - LAG(ps.qty_Priced_12mo, 6, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [6moChange_QtyPriced],
	ps.qty_Priced_12mo - LAG(ps.qty_Priced_12mo, 12, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [12moChange_QtyPriced],
	(CAST(ps.Purchases_12mo AS FLOAT)/CAST(ps.count_BuyTransactions_12mo AS FLOAT)) - 
		LAG((CAST(ps.Purchases_12mo AS FLOAT)/CAST(ps.count_BuyTransactions_12mo AS FLOAT)), 6, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [6moChange_AvgCostPerBuy],
	(CAST(ps.Purchases_12mo AS FLOAT)/CAST(ps.count_BuyTransactions_12mo AS FLOAT)) - 
		LAG((CAST(ps.Purchases_12mo AS FLOAT)/CAST(ps.count_BuyTransactions_12mo AS FLOAT)), 12, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [12moChange_AvgCostPerBuy],
	ps.PSRatio_12mo - LAG(ps.PSRatio_12mo, 6, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [6moChange_PSRatio],
	ps.PSRatio_12mo - LAG(ps.PSRatio_12mo, 12, NULL) OVER (PARTITION BY ps.LocationNo ORDER BY ps.BusinessMonth) [12moChange_PSRatio],
	lba.VersionNo,
	ROW_NUMBER() OVER (PARTITION BY ps.LocationNo, lba.VersionNo ORDER BY ps.BusinessMonth) [count_VersionNoMonths]
FROM #PSRatio ps
	LEFT OUTER JOIN Sandbox..LocBuyAlgorithms lba
		ON ps.LocationNo = lba.LocationNo
		AND lba.StartDate <= ps.BusinessMonth
		AND (lba.EndDate > ps.BusinessMonth
			OR lba.EndDate IS NULL)
ORDER BY LocationNo, BusinessMonth

DROP TABLE #AllSales

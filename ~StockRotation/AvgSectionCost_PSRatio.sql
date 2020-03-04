DECLARE @StartDate DATE = '1/1/2018'
DECLARE @EndDate DATE = '12/31/2018'

--Get all item extended amounts from HPB_Sales for 2018 and 2019 with product types
SELECT
	slm.LocationNo,
	LTRIM(RTRIM(ISNULL(pm.ProductType, spi.ProductType))) [ProductType],
	ISNULL(pm.ItemCode, spi.ItemCode) [ItemCode],
	sih19.ExtendedAmt [Sales]
INTO #AllSales
FROM HPB_SALES..SHH2019 shh19
	INNER JOIN HPB_SALES..SIH2019 sih19
		ON shh19.SalesXactionID = sih19.SalesXactionId
		AND shh19.LocationID = sih19.LocationID
		AND shh19.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh19.LocationID = slm.LocationID
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih19.ItemCode, 1) = 0								--Distro items start with 0 in the sales tables
		AND sih19.ItemCode = pm.ItemCode							--Distro item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi
		ON	LEFT(sih19.ItemCode, 1) <> 0							--Used items start non-zero values in the sales tables
		AND CAST(RIGHT(sih19.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables are not stored in the same format as the inventory tables
WHERE sih19.ItemCode NOT LIKE '%[^0-9]%'							
	AND shh19.EndDate <= @EndDate
UNION ALL
SELECT
	slm.LocationNo,
	LTRIM(RTRIM(ISNULL(pm.ProductType, spi.ProductType))) [ProductType],
	ISNULL(pm.ItemCode, spi.ItemCode) [ItemCode],
	sih18.ExtendedAmt [Sales]
FROM HPB_SALES..SHH2018 shh18
	INNER JOIN HPB_SALES..SIH2018 sih18
		ON shh18.SalesXactionID = sih18.SalesXactionId
		AND shh18.LocationID = sih18.LocationID
		AND shh18.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh18.LocationID = slm.LocationId
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih18.ItemCode, 1) = 0								--Distro/base items start with 0 in the sales tables
		AND sih18.ItemCode = pm.ItemCode							--Distro/base item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi			
		ON	LEFT(sih18.ItemCode, 1) <> 0							--SIPS items start non-zero values in the sales tables
		AND CAST(RIGHT(sih18.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables ARE NOT stored in the same format as the inventory tables, necessitating conversion.
WHERE sih18.ItemCode NOT LIKE '%[^0-9]%'							--Some non-numeric item codes exist in our sales tables. Failing to exclude these results in overflow errors.
	AND shh18.EndDate >= @StartDate


SELECT 
	bt.BuyType,
	SUM(bbi.Offer) [amt_Purchased],
	SUM(bbi.Quantity) [qty_Purchased]
INTO #Purchases
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinitems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN BUYS..BuyTypes bt
		ON bbi.BuyTypeID = bt.BuyTypeID
WHERE 
		bbh.CreateTime >= @StartDate
	AND bbh.CreateTime <= @EndDate
	AND bbh.StatusCode = 1
	AND bbi.StatusCode = 1
	AND bbi.Offer <= 10000
GROUP BY bt.BuyType


SELECT
	ptm.BuyType,
	SUM(s.Sales) [amt_Sales],
	COUNT(s.ItemCode) [qty_Sales]
INTO #Sales
FROM #AllSales s
	LEFT OUTER JOIN Sandbox..ProductTypeMap ptm
		ON s.ProductType = ptm.ProductType
GROUP BY ptm.BuyType

SELECT 
	s.BuyType,
	s.amt_Sales,
	p.amt_Purchased,
	p.amt_Purchased/NULLIF(s.amt_Sales, 0) [CostSalesRatio],
	p.amt_Purchased/p.qty_Purchased [avg_ItemCost],
	s.amt_Sales/s.qty_Sales [avg_Sale],
	s.amt_Sales/s.qty_Sales * p.amt_Purchased/NULLIF(s.amt_Sales, 0) [PSAvgSale_ItemCost]
INTO #PurchaseSalesRatio
FROM #Purchases p
	LEFT OUTER JOIN #Sales s
		ON p.BuyType = s.BuyType
WHERE s.BuyType IS NOT NULL 
ORDER BY BuyType

SELECT * FROM #PurchaseSalesRatio

DROP TABLE #Purchases
DROP TABLE #AllSales
DROP TABLE #Sales
--DROP TABLE #PurchaseSalesRatio
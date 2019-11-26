
DECLARE	@StartDate DATE = '9/1/2019'
DECLARE @EndDate DATE = '10/31/2019'

SELECT
	lba.LocationNo
INTO #SuggestedOfferStores
FROM Sandbox..LocBuyAlgorithms lba
WHERE lba.VersionNo = 'v1.r4'


	--Create table of locations and districs (performed on report load, instead of in roll-up) to allow for future redefinition of districts and regions).

	SELECT
		slm.LocationNo,
		slm.LocationNo + '   ' + slm.[StoreName] [LocationName],
		slm.DistrictName,
		slm.RegionName,
		CASE 
			WHEN slm.OpenDate < DATEADD(YEAR, -1, @StartDate)
			AND slm.StoreType = 'S'
			THEN 1
			ELSE 0
			END [bool_CompStore]
	INTO #Locations
	FROM ReportsData..StoreLocationMaster slm
	WHERE 
			slm.StoreType IN ('S', 'O')
		AND slm.ClosedDate IS NULL

UPDATE #Locations 
	SET RegionName = 'v1.r4'
FROM #SuggestedOfferStores sos
	INNER JOIN #Locations loc
		ON sos.LocationNo = loc.LocationNo

	--SELECT 
	--	loc.LocationNo,
	--	loc.LocationNo + '   ' + loc.[Name] [LocationName],
	--	CASE	--This is hardcoded until such a time as ReportLocations is updated to reflect this district change.
	--		WHEN loc.DistrictCode IN ('Tarrant County', 'Dallas North')
	--		THEN 'North Texas'
	--		ELSE loc.DistrictCode
	--		END [DistrictCode],
	--	rl.Region
	--INTO #Locations
	--FROM ReportsData..Locations loc
	--	INNER JOIN ReportsData..ReportLocations rl
	--		ON loc.LocationID = rl.LocationID
	--WHERE 	
	--	loc.RetailStore  = 'Y'
	--	AND loc.[Status] = 'A'	
	--	AND loc.DistrictCode <> ''
	--ORDER BY LocationNo

	SELECT
		eom.BusinessMonth,
		loc.RegionName,
		loc.DistrictName,
		loc.LocationName,
		loc.LocationNo,
		--ISNULL(x,0) is used for each part of the sum below, else any of the three being NULL causes the result of the sum to be NULL
		ISNULL(eom.total_NetSales, 0) + ISNULL(eom.total_iStoreSales, 0) + ISNULL(eom.total_BookSmarterSales, 0)		[total_TotalSales], 
		ISNULL(eom.count_SalesTrans, 0) + ISNULL(eom.count_iStoreOrders, 0) + ISNULL(eom.count_BookSmarterOrders, 0)	[count_TotalSalesTrans],
		ISNULL(eom.count_ItemsSold, 0) + ISNULL(eom.total_iStoreQty, 0) + ISNULL(eom.total_BookSmarterQty, 0)			[count_TotalItemsSold],
		ISNULL(eom.total_NetSales, 0)			[total_RetailSales], 
		ISNULL(eom.count_SalesTrans, 0)			[count_RetailSalesTrans],
		ISNULL(eom.count_ItemsSold, 0)			[count_RetailItemsSold],
		ISNULL(eom.total_BuyOffers, 0)			[total_BuyOffers],
		ISNULL(eom.count_BuyTrans, 0)			[count_BuyTrans],
		ISNULL(eom.total_BuyQty, 0)				[total_BuyQty],
		ISNULL(eom.total_iStoreSales, 0)		[total_iStoreSales],
		ISNULL(eom.count_iStoreOrders, 0)		[count_iStoreOrders],
		ISNULL(eom.total_iStoreQty, 0)			[total_iStoreQty],
		ISNULL(eom.total_BookSmarterSales, 0)	[total_BookSmarterSales],
		ISNULL(eom.count_BookSmarterOrders, 0)	[count_BookSmarterOrders],
		ISNULL(eom.total_BookSmarterQty, 0)		[total_BookSmarterQty]
	INTO #TYeom
	FROM RDA_RU_StarMetrics eom
		INNER JOIN #Locations loc
			ON eom.LocationNo = loc.LocationNo
			AND eom.BusinessMonth >= @StartDate
			AND eom.BusinessMonth < DATEADD(DAY, 1, @EndDate)

	--All ISNULL statements in the following are in case a location did not exist last year, or did not perform some aspect of operations,
	--in which case the resulting NULL value will be replaced with the appropriate value (in most cases 0).
	SELECT
		eom.BusinessMonth, 
		loc.RegionName,
		loc.DistrictName,
		loc.LocationName,
		loc.LocationNo,
		ISNULL(eom.total_NetSales, 0) + ISNULL(eom.total_iStoreSales, 0) + ISNULL(eom.total_BookSmarterSales, 0)		[total_TotalSales], 
		ISNULL(eom.count_SalesTrans, 0) + ISNULL(eom.count_iStoreOrders, 0) + ISNULL(eom.count_BookSmarterOrders, 0)	[count_TotalSalesTrans],
		ISNULL(eom.count_ItemsSold, 0) + ISNULL(eom.total_iStoreQty, 0) + ISNULL(eom.total_BookSmarterQty, 0)			[count_TotalItemsSold],
		ISNULL(eom.total_NetSales, 0)			[total_RetailSales], 
		ISNULL(eom.count_SalesTrans, 0)			[count_RetailSalesTrans],
		ISNULL(eom.count_ItemsSold, 0)			[count_RetailItemsSold],
		ISNULL(eom.total_BuyOffers, 0)			[total_BuyOffers],
		ISNULL(eom.count_BuyTrans, 0)			[count_BuyTrans],
		ISNULL(eom.total_BuyQty, 0)				[total_BuyQty],
		ISNULL(eom.total_iStoreSales, 0)		[total_iStoreSales],
		ISNULL(eom.count_iStoreOrders, 0)		[count_iStoreOrders],
		ISNULL(eom.total_iStoreQty, 0)			[total_iStoreQty],
		ISNULL(eom.total_BookSmarterSales, 0)	[total_BookSmarterSales],
		ISNULL(eom.count_BookSmarterOrders, 0)	[count_BookSmarterOrders],
		ISNULL(eom.total_BookSmarterQty, 0)		[total_BookSmarterQty]
	INTO #LYeom
	FROM #Locations loc
		LEFT OUTER JOIN RDA_RU_StarMetrics eom
			ON eom.LocationNo = loc.LocationNo
			AND eom.BusinessMonth >= DATEADD(YEAR, -1, @StartDate)
			AND eom.BusinessMonth < DATEADD(YEAR,  -1, DATEADD(DAY, 1, @EndDate))
	
	DROP TABLE #Locations --This table is no longer needed

	SELECT 
		CASE
			WHEN GROUPING(ty.RegionName) = 1
				THEN 'Chain'
			ELSE ty.RegionName
			END [Region],
		CASE
			WHEN GROUPING(ty.RegionName) = 1
				THEN 'Chain'
			WHEN GROUPING(ty.DistrictName) = 1
				THEN ty.RegionName
			ELSE ty.DistrictName
			END [DistrictName],
		CASE
			WHEN GROUPING(ty.RegionName) = 1
				THEN 'Chain'
			WHEN GROUPING(ty.DistrictName) = 1
				THEN ty.RegionName
			WHEN GROUPING(ty.LocationName) = 1
				THEN ty.DistrictName
			ELSE ty.LocationName
			END [LocationName],
		CASE
			WHEN GROUPING(ty.RegionName) = 1
				THEN 'Chain'
			WHEN GROUPING(ty.DistrictName) = 1
				THEN ty.RegionName
			WHEN GROUPING(ty.LocationName) = 1
				THEN ty.DistrictName
			ELSE ty.LocationNo
			END [LocationNo], 
		--Sales amounts ordered by (Total, Retail, iStore, BookSmarter)
		SUM(ty.total_TotalSales)											[total_TotalSales_ty],
		SUM(ly.total_TotalSales)											[total_TotalSales_ly],
		SUM(ty.total_RetailSales)											[total_RetailSales_ty],
		SUM(ly.total_RetailSales)											[total_RetailSales_ly],
		SUM(ty.total_iStoreSales)											[total_iStoreSales_ty],
		SUM(ly.total_iStoreSales)											[total_iStoreSales_ly],
		SUM(ty.total_BookSmarterSales)										[total_BookSmarterSales_ty],
		SUM(ly.total_BookSmarterSales)										[total_BookSmarterSales_ly],
		--Transaction counts, same order
		SUM(ty.count_TotalSalesTrans)										[count_TotalSalesTrans_ty],
		SUM(ly.count_TotalSalesTrans)										[count_TotalSalesTrans_ly],
		SUM(ty.count_RetailSalesTrans)										[count_RetailSalesTrans_ty],
		SUM(ly.count_RetailSalesTrans)										[count_RetailSalesTrans_ly],
		SUM(ty.count_iStoreOrders)											[count_iStoreOrders_ty],
		SUM(ly.count_iStoreOrders)											[count_iStoreOrders_ly],	
		SUM(ty.count_BookSmarterOrders)                                     [count_BookSmarterOrders_ty],	
		SUM(ly.count_BookSmarterOrders)                                     [count_BookSmarterOrders_ly],	
		--Item qty sold
		SUM(ty.count_TotalItemsSold)										[count_TotalItemsSold_ty],
		SUM(ly.count_TotalItemsSold)										[count_TotalItemsSold_ly],
		SUM(ty.count_RetailItemsSold)										[count_RetailItemsSold_ty],
		SUM(ly.count_RetailItemsSold)										[count_RetailItemsSold_ly],
		SUM(ty.total_iStoreQty)												[total_iStoreQty_ty],
		SUM(ly.total_iStoreQty)												[total_iStoreQty_ly],
		SUM(ty.total_BookSmarterQty)                                        [total_BookSmarterQty_ty],
		SUM(ly.total_BookSmarterQty)                                        [total_BookSmarterQty_ly],
		--Transaction sales amount averages
		SUM(CAST(ty.total_TotalSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_TotalSalesTrans AS FLOAT)), 0)		[avg_TotalSalesTransAmt_ty],
		SUM(CAST(ly.total_TotalSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_TotalSalesTrans AS FLOAT)), 0)		[avg_TotalSalesTransAmt_ly],
		SUM(CAST(ty.total_RetailSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_RetailSalesTrans AS FLOAT)), 0)	[avg_RetailSalesTransAmt_ty],
		SUM(CAST(ly.total_RetailSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_RetailSalesTrans AS FLOAT)), 0)	[avg_RetailSalesTransAmt_ly],
		SUM(CAST(ty.total_iStoreSales AS FLOAT))/
			NULLIF(SUM(CAST(ty.count_iStoreOrders AS FLOAT)), 0)			[avg_iStoreOrderSale_ty],
		SUM(CAST(ly.total_iStoreSales AS FLOAT))/
			NULLIF(SUM(CAST(ly.count_iStoreOrders AS FLOAT)), 0)			[avg_iStoreOrderSale_ly],
		SUM(CAST(ty.total_BookSmarterSales AS FLOAT))/
			NULLIF(SUM(CAST(ty.total_BookSmarterQty AS FLOAT)), 0)			[avg_BookSmarterSale_ty],	
		SUM(CAST(ly.total_BookSmarterSales AS FLOAT))/
			NULLIF(SUM(CAST(ly.total_BookSmarterQty AS FLOAT)), 0)			[avg_BookSmarterSale_ly],		
		--
		SUM(CAST(ty.count_TotalItemsSold AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_TotalSalesTrans AS FLOAT)), 0)		[avg_TotalSalesTransQty_ty],
		SUM(CAST(ly.count_TotalItemsSold AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_TotalSalesTrans AS FLOAT)), 0)		[avg_TotalSalesTransQty_ly],
		SUM(CAST(ty.count_RetailItemsSold AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_RetailSalesTrans AS FLOAT)), 0)	[avg_RetailSalesTransQty_ty],
		SUM(CAST(ly.count_RetailItemsSold AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_RetailSalesTrans AS FLOAT)), 0)	[avg_RetailSalesTransQty_ly],
		SUM(CAST(ty.total_iStoreQty AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_iStoreOrders AS FLOAT)), 0)		[avg_iStoreSalesTransQty_ty],
		SUM(CAST(ly.total_iStoreQty AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_iStoreOrders AS FLOAT)), 0)		[avg_iStoreSalesTransQty_ly],
		SUM(CAST(ty.total_BookSmarterQty AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_BookSmarterOrders AS FLOAT)), 0)	[avg_BookSmarterSalesTransQty_ty],
		SUM(CAST(ly.total_BookSmarterQty AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_BookSmarterOrders AS FLOAT)), 0)	[avg_BookSmarterSalesTransQty_ly],
			--
		SUM(CAST(ty.total_TotalSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_TotalItemsSold AS FLOAT)), 0)		[avg_TotalSalesItemAmt_ty],
		SUM(CAST(ly.total_TotalSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_TotalItemsSold AS FLOAT)), 0)		[avg_TotalSalesItemAmt_ly],
		SUM(CAST(ty.total_RetailSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_RetailItemsSold AS FLOAT)), 0)		[avg_RetailSalesItemAmt_ty],
		SUM(CAST(ly.total_RetailSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_RetailItemsSold AS FLOAT)), 0)		[avg_RetailSalesItemAmt_ly],
		SUM(CAST(ty.total_iStoreSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.total_iStoreQty AS FLOAT)), 0)			[avg_iStoreSalesItemAmt_ty],
		SUM(CAST(ly.total_iStoreSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.total_iStoreQty AS FLOAT)), 0)			[avg_iStoreSalesItemAmt_ly],
		SUM(CAST(ty.total_BookSmarterSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.total_BookSmarterQty AS FLOAT)), 0)		[avg_BookSmarterSalesItemAmt_ty],
		SUM(CAST(ly.total_BookSmarterSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.total_BookSmarterQty AS FLOAT)), 0)		[avg_BookSmarterSalesItemAmt_ly],

		SUM(ty.total_BuyOffers)												[total_BuyOffers_ty],
		SUM(ly.total_BuyOffers)												[total_BuyOffers_ly],
		SUM(ty.count_BuyTrans)												[count_BuyTrans_ty],
		SUM(ly.count_BuyTrans)												[count_BuyTrans_ly],
		SUM(ty.total_BuyQty)												[total_BuyQty_ty],
		SUM(ly.total_BuyQty)												[total_BuyQty_ly],
		SUM(CAST(ty.total_BuyOffers AS FLOAT))/
			NULLIF(SUM(CAST(ty.count_BuyTrans AS FLOAT)), 0)				[avg_BuyTransOffer_ty],
		SUM(CAST(ly.total_BuyOffers AS FLOAT))/
			NULLIF(SUM(CAST(ly.count_BuyTrans AS FLOAT)), 0)				[avg_BuyTransOffer_ly],
		SUM(CAST(ty.total_BuyQty AS FLOAT))/
			NULLIF(SUM(CAST(ty.count_BuyTrans AS FLOAT)), 0)				[avg_BuyTransQty_ty],
		SUM(CAST(ly.total_BuyQty AS FLOAT))/
			NULLIF(SUM(CAST(ly.count_BuyTrans AS FLOAT)), 0)				[avg_BuyTransQty_ly],
		SUM(CAST(ty.total_BuyOffers AS FLOAT))/
			NULLIF(SUM(CAST(ty.total_BuyQty AS FLOAT)), 0)					[avg_BuyItemOffer_ty],
		SUM(CAST(ly.total_BuyOffers AS FLOAT))/
			NULLIF(SUM(CAST(ly.total_BuyQty AS FLOAT)), 0)					[avg_BuyItemOffer_ly],
		--Percent differences from previous year		
		ISNULL(CAST(SUM(ty.total_TotalSales ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.total_TotalSales ) AS FLOAT), 0), 0) - 1					[pctdiff_TotalTotalSales],
		ISNULL(CAST(SUM(ty.total_RetailSales ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.total_RetailSales ) AS FLOAT), 0), 0) - 1				[pctdiff_TotalRetailSales],
		--Sorting of metrics ends here, everything below to be completed.
		ISNULL(CAST(SUM(ty.count_TotalSalesTrans ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.count_TotalSalesTrans ) AS FLOAT), 0), 0) - 1			[pctdiff_CountTotalSalesTrans],
		ISNULL(CAST(SUM(ty.count_TotalItemsSold ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.count_TotalItemsSold ) AS FLOAT), 0), 0) - 1				[pctdiff_CountTotalItemSold],
		ISNULL(SUM(CAST(ty.total_TotalSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_TotalSalesTrans AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_TotalSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_TotalSalesTrans AS FLOAT)), 0), 0), 0) - 1		[pctdiff_AvgTotalSalesTransAmt],
		ISNULL(SUM(CAST(ty.count_TotalItemsSold AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_TotalSalesTrans AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.count_TotalItemsSold AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_TotalSalesTrans AS FLOAT)), 0), 0), 0) - 1		[pctdiff_AvgTotalSalesTransQty],
		ISNULL(SUM(CAST(ty.total_TotalSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_TotalItemsSold AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_TotalSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_TotalItemsSold AS FLOAT)), 0), 0), 0) - 1		[pctdiff_AvgTotalSalesItemAmt],
		
		ISNULL(CAST(SUM(ty.count_RetailSalesTrans ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.count_RetailSalesTrans ) AS FLOAT), 0), 0) - 1			[pctdiff_CountRetailSalesTrans],
		ISNULL(CAST(SUM(ty.count_RetailItemsSold ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.count_RetailItemsSold ) AS FLOAT), 0), 0) - 1			[pctdiff_CountRetailItemSold],
		ISNULL(SUM(CAST(ty.total_RetailSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_RetailSalesTrans AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_RetailSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_RetailSalesTrans AS FLOAT)), 0), 0), 0) - 1	[pctdiff_AvgRetailSalesTransAmt],
		ISNULL(SUM(CAST(ty.count_RetailItemsSold AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_RetailSalesTrans AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.count_RetailItemsSold AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_RetailSalesTrans AS FLOAT)), 0), 0), 0) - 1	[pctdiff_AvgRetailSalesTransQty],
		ISNULL(SUM(CAST(ty.total_RetailSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_RetailItemsSold AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_RetailSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_RetailItemsSold AS FLOAT)), 0), 0), 0) - 1		[pctdiff_AvgRetailSalesItemAmt],
		ISNULL(SUM(CAST(ty.total_BuyQty AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_BuyTrans AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_BuyQty AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_BuyTrans AS FLOAT)), 0), 0), 0) - 1			[pctdiff_AvgBuyTransQty], 
		--ISNULL(CAST(SUM(ty.avg_BuysPerDay ) AS FLOAT)/
		--	NULLIF(CAST(SUM(ly.avg_BuysPerDay ) AS FLOAT), 0), 0) - 1					[pctdiff_AvgBuysPerDay],
		ISNULL(CAST(SUM(ty.total_iStoreSales ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.total_iStoreSales ) AS FLOAT), 0), 0) - 1				[pctdiff_TotaliStoreSales],
		ISNULL(CAST(SUM(ty.count_iStoreOrders ) AS FLOAT)/	
			NULLIF(CAST(SUM(ly.count_iStoreOrders ) AS FLOAT), 0), 0) - 1				[pctdiff_CountiStoreOrders],
		ISNULL(CAST(SUM(ty.total_iStoreQty ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.total_iStoreQty ) AS FLOAT), 0), 0) - 1					[pctdiff_TotaliStoreQty],
		ISNULL(SUM(CAST(ty.total_iStoreSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_iStoreOrders AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_iStoreSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_iStoreOrders AS FLOAT)), 0), 0), 0) - 1		[pctdiff_AvgiStoreSalesTransAmt],

		ISNULL(SUM(CAST(ty.total_iStoreQty AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_iStoreOrders AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_iStoreQty AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_iStoreOrders AS FLOAT)), 0), 0), 0) - 1		[pctdiff_AvgiStoreSalesTransQty],

		ISNULL(SUM(CAST(ty.total_iStoreSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.total_iStoreQty AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ty.total_iStoreSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.total_iStoreQty AS FLOAT)), 0), 0), 0) - 1			[pctdiff_AvgiStoreSalesItemAmt],

		ISNULL(CAST(SUM(ty.total_BookSmarterSales ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.total_BookSmarterSales ) AS FLOAT), 0), 0) - 1			[pctdiff_TotalBookSmarterSales],
		ISNULL(CAST(SUM(ty.count_BookSmarterOrders ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.count_BookSmarterOrders ) AS FLOAT), 0), 0) - 1			[pctdiff_CountBookSmarterOrders],
		ISNULL(CAST(SUM(ty.total_BookSmarterQty ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.total_BookSmarterQty ) AS FLOAT), 0), 0) - 1				[pctdiff_TotalBookSmarterQty],
		ISNULL(SUM(CAST(ty.total_BookSmarterSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.total_BookSmarterQty AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_BookSmarterSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.total_BookSmarterQty AS FLOAT)), 0), 0), 0) - 1		[pctdiff_AvgBookSmarterTransAmt],	
		ISNULL(SUM(CAST(ty.total_BookSmarterQty AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_BookSmarterOrders AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_BookSmarterQty AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_BookSmarterOrders AS FLOAT)), 0), 0), 0) - 1	[pctdiff_AvgBookSmarterSalesTransQty],
		ISNULL(SUM(CAST(ty.total_BookSmarterSales AS FLOAT))/
				NULLIF(SUM(CAST(ty.total_BookSmarterQty AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ty.total_BookSmarterSales AS FLOAT))/
				NULLIF(SUM(CAST(ly.total_BookSmarterQty AS FLOAT)), 0), 0), 0) - 1		[pctdiff_AvgBookSmarterSalesItemAmt],
		--Buy metrics
		ISNULL(CAST(SUM(ty.total_BuyOffers ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.total_BuyOffers ) AS FLOAT), 0), 0) - 1					[pctdiff_TotalBuyOffers],
		ISNULL(CAST(SUM(ty.count_BuyTrans ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.count_BuyTrans ) AS FLOAT), 0), 0) - 1					[pctdiff_CountBuyTrans],
		ISNULL(CAST(SUM(ty.total_BuyQty ) AS FLOAT)/
			NULLIF(CAST(SUM(ly.total_BuyQty ) AS FLOAT), 0), 0) - 1						[pctdiff_TotalBuyQty],
		ISNULL(SUM(CAST(ty.total_BuyOffers AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_BuyTrans AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_BuyOffers AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_BuyTrans AS FLOAT)), 0), 0), 0) - 1			[pctdiff_AvgBuyTransAmt],

		ISNULL(SUM(CAST(ty.total_BuyOffers AS FLOAT))/
				NULLIF(SUM(CAST(ty.total_BuyQty AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_BuyOffers AS FLOAT))/
				NULLIF(SUM(CAST(ly.total_BuyQty AS FLOAT)), 0), 0), 0) - 1				[pctdiff_AvgBuyItemAmt],
		ISNULL(SUM(CAST(ty.total_BuyQty AS FLOAT))/
				NULLIF(SUM(CAST(ty.count_BuyTrans AS FLOAT)), 0)/
			NULLIF(SUM(CAST(ly.total_BuyQty AS FLOAT))/
				NULLIF(SUM(CAST(ly.count_BuyTrans AS FLOAT)), 0), 0), 0) - 1			[pctdiff_AvgBuyQty]
	INTO #FinalComp
	FROM #TYeom ty
		LEFT OUTER JOIN #LYeom ly
			ON ty.LocationNo = ly.LocationNo
			AND ty.BusinessMonth = DATEADD(YEAR, 1, ly.BusinessMonth)
	GROUP BY ROLLUP(ty.RegionName, ty.DistrictName, (ty.LocationNo, ty.LocationName))
	
	SELECT *
	FROM #FinalComp fc
	WHERE (	(fc.LocationNo IN ('v1.r4', 'Chain')) OR 
			(fc.Region = 'v1.r4' AND fc.DistrictName <> LocationName))
	ORDER BY fc.Region DESC, fc.LocationNo

	DROP TABLE #LYeom
	DROP TABLE #TYeom
	DROP TABLE #FinalComp
	DROP TABLE #SuggestedOfferStores

	



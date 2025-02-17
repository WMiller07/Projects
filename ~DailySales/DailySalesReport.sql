DECLARE @BusinessDate DATE = DATEADD(DAY, -1, GETDATE())


SELECT [DistrictName]
      ,[LocationNo]
      ,[Store_Date]
	  ,sdm_ty.NRF_Year
	  ,sdm_ty.NRF_Day
	  ,([sales_AmtSold] + [iStore_AmtSold] + [HPBCom_AmtSold] + [BookSmarter_AmtSold]) [totalsales_AmtSold]
	  ,([sales_CountTransactions] + [iStore_CountTransactions] + [HPBCom_CountTransactions] + [BookSmarter_CountTransactions]) [totalsales_CountTransactions]
      
	  ,[sales_AmtSold]
	  ,[sales_CountTransactions]
      
	  ,[iStore_AmtSold]
      ,[iStore_CountTransactions]
      
      ,[HPBCom_AmtSold]
	  ,[HPBCom_CountTransactions]
      
      ,[BookSmarter_AmtSold]
      ,[BookSmarter_CountTransactions]
      
	  ,[buys_CountTransactions]
      ,[buys_AmtPurchased]
      ,[buys_QtyPurchased]
INTO #DailyMetricsTY
FROM [Sandbox].[dbo].[RDA_StoreDailyMetrics] sdm_ty
WHERE sdm_ty.Store_Date = @BusinessDate


SELECT 
	sdm_ty.[DistrictName],
    sdm_ty.[LocationNo],
    sdm_ty.[Store_Date] [date_TY],
	sdm_ly.[Store_Date] [date_LY],
	
	--Total Sales Amounts
	(sdm_ty.[sales_AmtSold] + sdm_ty.[iStore_AmtSold] + sdm_ty.[HPBCom_AmtSold] + sdm_ty.[BookSmarter_AmtSold]) [totalsales_amtSold_TY],
	(sdm_ly.[sales_AmtSold] + sdm_ly.[iStore_AmtSold] + sdm_ly.[HPBCom_AmtSold] + sdm_ly.[BookSmarter_AmtSold]) [totalsales_amtSold_LY],
	CAST(sdm_ty.[sales_AmtSold] + sdm_ty.[iStore_AmtSold] + sdm_ty.[HPBCom_AmtSold] + sdm_ty.[BookSmarter_AmtSold] AS FLOAT) /
		NULLIF(CAST(sdm_ly.[sales_AmtSold] + sdm_ly.[iStore_AmtSold] + sdm_ly.[HPBCom_AmtSold] + sdm_ly.[BookSmarter_AmtSold] AS FLOAT), 0) - 1 [pctdiff_totalSales_amtSold],
	--Total Sales Transactions
	(sdm_ty.[sales_CountTransactions] + sdm_ty.[iStore_CountTransactions] + sdm_ty.[HPBCom_CountTransactions] + sdm_ty.[BookSmarter_CountTransactions]) [totalsales_countTransactions_TY],
	(sdm_ly.[sales_CountTransactions] + sdm_ly.[iStore_CountTransactions] + sdm_ly.[HPBCom_CountTransactions] + sdm_ly.[BookSmarter_CountTransactions]) [totalsales_countTransactions_LY],
	CAST(sdm_ty.[sales_AmtSold] + sdm_ty.[iStore_AmtSold] + sdm_ty.[HPBCom_AmtSold] + sdm_ty.[BookSmarter_AmtSold] AS FLOAT) /
		NULLIF(CAST(sdm_ly.[sales_AmtSold] + sdm_ly.[iStore_AmtSold] + sdm_ly.[HPBCom_AmtSold] + sdm_ly.[BookSmarter_AmtSold] AS FLOAT), 0) - 1 [pctdiff_totalSales_countTransactions],

	--Retail Sales Amounts
	sdm_ty.[sales_AmtSold] [retailSales_amtSold_TY],
	sdm_ly.[sales_AmtSold] [retailSales_amtSold_LY],
	CAST(sdm_ty.[sales_AmtSold] AS FLOAT) / NULLIF(CAST(sdm_ly.[sales_AmtSold] AS FLOAT), 0) - 1 [pctdiff_retailSales_amtSold],
	--Retail Sales Transactions
	sdm_ty.[sales_CountTransactions] [retailSales_countTransactions_TY],
	sdm_ly.[sales_CountTransactions] [retailSales_countTransactions_LY],
	CAST(sdm_ty.[sales_CountTransactions] AS FLOAT) / NULLIF(CAST(sdm_ly.[sales_CountTransactions] AS FLOAT), 0) - 1 [pctdiff_retailSales_countTransactions],
      
	--iStore Sales Amounts
	sdm_ty.[iStore_AmtSold] [iStore_amtSold_TY],
	sdm_ly.[iStore_AmtSold] [iStore_amtSold_LY],
	CAST(sdm_ty.[iStore_AmtSold] AS FLOAT) / NULLIF(CAST(sdm_ly.[iStore_AmtSold] AS FLOAT), 0) - 1 [pctdiff_iStore_amtSold],
    --iStore Sales Transactions
    sdm_ty.[iStore_CountTransactions] [iStore_countTransactions_TY],
	sdm_ly.[iStore_CountTransactions] [iStore_countTransactions_LY],
	CAST(sdm_ty.[iStore_CountTransactions] AS FLOAT) / NULLIF(CAST(sdm_ly.[iStore_CountTransactions] AS FLOAT), 0) - 1 [pctdiff_iStore_countTransactions],

	--HPB.com Sales Amounts
    sdm_ty.[HPBCom_AmtSold] [HPBCom_amtSold_TY],
	sdm_ly.[HPBCom_AmtSold] [HPBCom_amtSold_LY],
	CAST(sdm_ty.[HPBCom_AmtSold] AS FLOAT) / NULLIF(CAST(sdm_ly.[HPBCom_AmtSold] AS FLOAT), 0) - 1 [pctdiff_HPBCom_amtSold],
	--HPB.com Sales Transactions
	sdm_ty.[HPBCom_CountTransactions] [HPBCom_countTransactions_TY],
	sdm_ly.[HPBCom_CountTransactions] [HPBCom_countTransactions_LY],
	CAST(sdm_ty.[HPBCom_CountTransactions] AS FLOAT) / NULLIF(CAST(sdm_ly.[HPBCom_CountTransactions] AS FLOAT), 0) - 1 [pctdiff_HPBCom_countTransactions],
    
	--BookSmarter Sales Amounts
    sdm_ty.[BookSmarter_AmtSold] [BookSmarter_amtSold_TY],
	sdm_ly.[BookSmarter_AmtSold] [BookSmarter_amtSold_LY],
	CAST(sdm_ty.[BookSmarter_AmtSold] AS FLOAT) / NULLIF(CAST(sdm_ly.[BookSmarter_AmtSold] AS FLOAT), 0) - 1 [BookSmarter_amtSold],
	--BookSmarter Sales Transactions
    sdm_ty.[BookSmarter_CountTransactions] [BookSmarter_countTransactions_TY],
	sdm_ly.[BookSmarter_CountTransactions] [BookSmarter_countTransactions_LY],
	CAST(sdm_ty.[HPBCom_CountTransactions] AS FLOAT) / NULLIF(CAST(sdm_ly.[HPBCom_CountTransactions] AS FLOAT), 0) - 1 [pctdiff_HPBCom_countTransactions],
      
	sdm_ty.[buys_AmtPurchased] [buys_amtPurchased_TY],
	sdm_ly.[buys_AmtPurchased] [buys_amtPurchased_LY],
	CAST(sdm_ty.[buys_AmtPurchased] AS FLOAT) / NULLIF(CAST(sdm_ly.[buys_AmtPurchased] AS FLOAT), 0) - 1 [pctdiff_buys_amtPurchased],
	sdm_ty.[buys_CountTransactions] [buys_countTransactions_TY],
	sdm_ly.[buys_CountTransactions] [buys_countTransactions_LY],
	CAST(sdm_ty.[buys_CountTransactions] AS FLOAT) / NULLIF(CAST(sdm_ly.[buys_CountTransactions] AS FLOAT), 0) - 1 [pctdiff_buys_countTransactions],
    sdm_ty.[buys_QtyPurchased] [buys_qtyPurchased_TY],
	sdm_ly.[buys_QtyPurchased] [buys_qtyPurchased_LY],
	CAST(sdm_ty.[buys_QtyPurchased] AS FLOAT) / NULLIF(CAST(sdm_ly.[buys_QtyPurchased] AS FLOAT), 0) - 1 [buys_1tyPurchased]
--INTO #DailyMetricsLY
FROM #DailyMetricsTY sdm_ty
	LEFT OUTER JOIN [Sandbox].[dbo].[RDA_StoreDailyMetrics] sdm_ly
		ON sdm_ty.NRF_Day = sdm_ly.NRF_Day 
		AND (CAST(sdm_ty.NRF_Year AS INT) - 1) = sdm_ly.NRF_YEAR
		AND sdm_ty.LocationNo = sdm_ly.LocationNo
ORDER BY LocationNo, sdm_ty.Store_Date

DROP TABLE #DailyMetricsTY
DECLARE @StartDate DATE 
DECLARE @EndDate DATE = '10/1/2019'

--Find first algorithm generation date that has associated offer percentages, set as start date
SELECT 
	@StartDate = MIN(ba.Date_Generated)
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
WHERE ba.Chain_Buy_Offer_Pct IS NOT NULL

--Get all chain-level offers generated between start date and end date
SELECT DISTINCT
	ba.CatalogID,
	ba.Chain_Buy_Offer_Pct,
	ba.Chain_Avg_Sale_Price,
	ba.Chain_SuggestedOffer,
	ba.Date_Generated
INTO #ChainBuyAlgorithm
FROM Buy_Analytics..BuyAlgorithm_V1_R4 ba
WHERE ba.Date_Generated >= @StartDate
	AND ba.Date_Generated < @EndDate

--Organize algorthim generations by date ranges
SELECT
	cba.CatalogID,
	cba.Date_Generated [from_GenDate],
	LEAD(cba.Date_Generated, 1, DATEADD(DAY, 7, cba.Date_Generated)) OVER (PARTITION BY cba.CatalogID ORDER BY cba.Date_Generated) [to_GenDate]
INTO #BuyAlgorithmDates
FROM #ChainBuyAlgorithm cba


--Assign each SIPS item priced between start date and end date to an algorithm generation based on date range.
SELECT 
	cba.CatalogID,
	CASE 
		WHEN t.binding IN ('Mass Market Paperback', 'CD', 'Audio CD')
		THEN t.binding
		ELSE 'General'
		END [CatalogBinding],
	cba.Chain_SuggestedOffer,
	cba.Chain_Avg_Sale_Price,
	cba.Chain_Buy_Offer_Pct,
	cba.Date_Generated,
	lc.ItemCode,
	lc.First_RecordDate
INTO #ChainItemOffers
FROM Buy_Analytics..ItemCode_LifeCycle lc
	LEFT OUTER JOIN Catalog..titles t
		ON lc.CatalogID = t.catalogId
	INNER JOIN #BuyAlgorithmDates bad
		ON lc.CatalogId = bad.CatalogID
		AND lc.First_RecordDate >= bad.from_GenDate
		AND lc.First_RecordDate < bad.to_GenDate
	INNER JOIN #ChainBuyAlgorithm cba
		ON bad.CatalogId = cba.CatalogID
		AND bad.from_GenDate = cba.Date_Generated
WHERE lc.LastEventType <> 4

SELECT 
	cio.CatalogID,
	cio.CatalogBinding,
	cio.Chain_Buy_Offer_Pct,
	cio.Chain_Avg_Sale_Price,
	cio.ItemCode [SipsItemCode],
	lc.Sale_Price, 
	DATEDIFF(DAY, ISNULL(lc.first_ScanDate, cio.First_RecordDate), ISNULL(lc.Last_SaleDate, GETDATE())) [Acc_Days]
INTO #ChainItemHistory
FROM #ChainItemOffers cio
	INNER JOIN Buy_Analytics..ItemCode_LifeCycle lc
		ON cio.ItemCode = lc.ItemCode

		
----Prediction accuracy evaluation by item (not ideal, but potentially useful)
--SELECT 
--	cih.CatalogID,
--	cih.CatalogBinding,
--	cih.Chain_Buy_Offer_Pct,
--	cih.Chain_Avg_Sale_Price,
--	cih.SipsItemCode,
--	CASE WHEN cih.Sale_Price IS NULL THEN 0 ELSE 1 END [bool_Sold],
--	cih.Sale_Price,
--	cih.Acc_Days,
--	btt.BuyGradeName [target_BuyGrade],
--	btp.BuyGradeName [predicted_BuyGrade]
--FROM #ChainItemHistory cih
--	INNER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 btt
--		ON cih.Acc_Days > btt.AccDaysRangeFrom
--		AND cih.Acc_Days <= btt.AccDaysRangeTo
--		AND cih.CatalogBinding = btt.CatalogBinding
--	INNER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 btp
--		ON cih.Chain_Buy_Offer_Pct = btp.BuyOfferPct
--		AND cih.CatalogBinding = btp.CatalogBinding
--WHERE cih.SipsItemCode IS NOT NULL
--ORDER BY cih.Chain_Buy_Offer_Pct DESC



SELECT 
	cih.CatalogID,
	cih.CatalogBinding,
	btp.BuyGradeName,
	cih.Chain_Buy_Offer_Pct,
	cih.Chain_Avg_Sale_Price,
	COUNT(cih.SipsItemCode) [count_ItemsPriced],
	COUNT(cih.Sale_Price) [count_ItemsSold],
	AVG(cih.Sale_Price) [avg_SalePrice],
	CAST(SUM(cih.Acc_Days) AS FLOAT)/ CAST(COUNT(cih.SipsItemCode) AS FLOAT) [avg_AccDaysCountItems],
	CAST(SUM(cih.Acc_Days) AS FLOAT)/ CAST((COUNT(cih.Sale_Price) + 1) AS FLOAT) [avg_AccDaysSoldItems]
INTO #CatalogSalesTrends
FROM #ChainItemHistory cih
	INNER JOIN Buy_Analytics..AccumulatedDaysOnShelf_BuyTable_V1_R4 btp
		ON cih.Chain_Buy_Offer_Pct = btp.BuyOfferPct
		AND cih.CatalogBinding = btp.CatalogBinding
GROUP BY 
	cih.CatalogID,
	cih.CatalogBinding,
	btp.BuyGradeName,
	cih.Chain_Buy_Offer_Pct,
	cih.Chain_Avg_Sale_Price


SELECT 
	cst.CatalogID,
	cst.CatalogBinding,
	cst.count_ItemsPriced,
	cst.count_ItemsSold,
	CAST(cst.count_ItemsSold AS FLOAT)
		/ CAST(cst.count_ItemsPriced AS FLOAT) [pct_SellThrough],
	cst.Chain_Avg_Sale_Price,
	cst.avg_SalePrice,
	cst.avg_AccDaysCountItems,
	cst.avg_AccDaysSoldItems,
	cst.BuyGradeName [pred_BuyOfferGrade],	
	bt40.BuyGradeName [targ_BuyOfferGrade40],
	bt42.BuyGradeName [targ_BuyOfferGrade42],
	cst.Chain_Buy_Offer_Pct [pred_BuyOfferPct],
	bt40.BuyOfferPct [targ_BuyOfferPct40],
	bt42.BuyOfferPct [targ_BuyOfferPct42],
	cst.Chain_Buy_Offer_Pct * cst.Chain_Avg_Sale_Price [pred_SuggestedOffer],
	bt40.BuyOfferPct * cst.avg_SalePrice [targ_SuggestedOffer40],
	bt42.BuyOfferPct * cst.avg_SalePrice [targ_SuggestedOffer42]
FROM #CatalogSalesTrends cst
	INNER JOIN Buy_Analytics.dbo.AccumulatedDaysOnShelf_BuyTable_V1_R4 bt40
		ON cst.CatalogBinding = bt40.CatalogBinding
		AND cst.avg_AccDaysCountItems > bt40.AccDaysRangeFrom
		AND cst.avg_AccDaysCountItems <= bt40.AccDaysRangeTo
	INNER JOIN Sandbox.dbo.AccumulatedDaysOnShelf_BuyTable_V1_R42 bt42
		ON cst.CatalogBinding = bt42.CatalogBinding
		AND cst.avg_AccDaysSoldItems > bt42.AccDaysRangeFrom
		AND cst.avg_AccDaysSoldItems <= bt42.AccDaysRangeTo


DROP TABLE #ChainBuyAlgorithm
DROP TABLE #BuyAlgorithmDates
DROP TABLE #ChainItemHistory
DROP TABLE #ChainItemOffers
DROP TABLE #CatalogSalesTrends
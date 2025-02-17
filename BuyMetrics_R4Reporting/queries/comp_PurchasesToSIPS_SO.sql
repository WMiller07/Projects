DECLARE @StartDate DATE = '7/27/19'

SELECT
	spi.LocationNo,
	t.catalogId,
	spm.ProductType,
	CASE 
		WHEN t.binding IN ('Mass Market Paperbacks', 'CD', 'Audio CD')
			THEN t.binding
		ELSE 'General'
		END [CatalogBinding],
	spi.DateInStock,
	adc.Avg_Sale_Price [ChainAvg_SalePrice],
	adc.Total_Accumulated_Days_With_Trash_Penalty / adc.Total_Item_Count [ChainAvg_AccDays],
	adl.Avg_Sale_Price [LocAvg_SalePrice],
	adl.Total_Accumulated_Days_With_Trash_Penalty / adl.Total_Item_Count [LocAvg_AccDays]
INTO #AggItemDataSips
FROM ReportsData..SipsProductInventory spi
	INNER JOIN ReportsData..SipsProductMaster spm
		ON spi.SipsID = spm.SipsID
	INNER JOIN Catalog..titles t
		ON spm.CatalogId = t.CatalogID
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON spi.LocationNo = lba.LocationNo
		AND lba.VersionNo = 'v1.r3'
	INNER JOIN Sandbox..BuyAlgorithm_AggregateData_Chain adc
		ON spm.CatalogId = adc.CatalogID
	LEFT OUTER JOIN Sandbox..BuyAlgorithm_AggregateData_Location adl
		ON spi.LocationNo = adl.LocationNo
		AND spm.CatalogId = adl.CatalogID
WHERE spi.DateInStock >= @StartDate AND spm.ProductType IN ('UN', 'DVD')
ORDER BY LocationNo, CatalogID

--SELECT 
--	aids.LocationNo,
--	aids.catalogId,
--	aids.CatalogBinding,
--	aids.DateInStock,
--	aids.ChainAvg_SalePrice,
--	aids.ChainAvg_AccDays,
--	aids.LocAvg_SalePrice,
--	aids.LocAvg_AccDays,
--	cbt.BuyOfferPct,
--	cbt.BuyOfferPct * aids.ChainAvg_SalePrice,
--	lbt.BuyOfferPct,
--	lbt.BuyOfferPct * aids.LocAvg_SalePrice
--FROM #AggItemDataSips aids
--	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 cbt
--		ON aids.CatalogBinding = cbt.CatalogBinding
--		AND aids.ChainAvg_AccDays > cbt.AccDaysRangeFrom
--		AND aids.ChainAvg_AccDays <= cbt.AccDaysRangeTo
--	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 lbt
--		ON aids.CatalogBinding = lbt.CatalogBinding
--		AND aids.LocAvg_AccDays > lbt.AccDaysRangeFrom
--		AND aids.LocAvg_AccDays <= lbt.AccDaysRangeTo


SELECT 
	aids.LocationNo,
	aids.ProductType,
	COUNT(aids.catalogId) [count_SipsItems],
	AVG(ISNULL(lbt.BuyOfferPct * aids.LocAvg_SalePrice, cbt.BuyOfferPct * aids.ChainAvg_SalePrice)) [avg_SipsItem_SuggestedOffer]
INTO #SipsSuggOffers 
FROM #AggItemDataSips aids
	INNER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 cbt
		ON aids.CatalogBinding = cbt.CatalogBinding
		AND aids.ChainAvg_AccDays > cbt.AccDaysRangeFrom
		AND aids.ChainAvg_AccDays <= cbt.AccDaysRangeTo
	LEFT OUTER JOIN Sandbox..AccumulatedDaysOnShelf_BuyTable_V1_R4 lbt
		ON aids.CatalogBinding = lbt.CatalogBinding
		AND aids.LocAvg_AccDays > lbt.AccDaysRangeFrom
		AND aids.LocAvg_AccDays <= lbt.AccDaysRangeTo
GROUP BY aids.LocationNo, aids.ProductType
ORDER BY aids.LocationNo

SELECT 
	bbh.LocationNo,
	lba.TestGroup,
	bt.BuyType,
	COUNT(bbi.CatalogID) [count_BuyItems],
	sso.count_SipsItems,
	SUM(bbi.SuggestedOffer) / SUM(bbi.Quantity) [avg_BuyItem_SuggestedOffer],
	sso.avg_SipsItem_SuggestedOffer
FROM BUYS..BuyBinHeader bbh 
	INNER JOIN Buys..BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN Buys..BuyTypes bt
		ON bbi.BuyTypeID = bt.BuyTypeID
	INNER JOIN #SipsSuggOffers sso
		ON bbh.LocationNo = sso.LocationNo
		AND sso.ProductType = bt.BuyType
	INNER JOIN Sandbox..LocBuyAlgorithms lba
		ON bbh.LocationNo = lba.LocationNo
		AND lba.VersionNo = 'v1.r3'
WHERE bbh.CreateTime >= @StartDate
	AND bbi.SuggestedOfferVersion IN ('v1.r3', 'v1.r4')
	AND bt.BuyType IN ('UN', 'DVD')
GROUP BY bbh.LocationNo, lba.TestGroup, bt.BuyType, sso.count_SipsItems, sso.avg_SipsItem_SuggestedOffer
ORDER BY bbh.LocationNo

DROP TABLE #AggItemDataSips
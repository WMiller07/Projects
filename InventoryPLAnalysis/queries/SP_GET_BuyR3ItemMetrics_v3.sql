USE [Sandbox]
GO
/****** Object:  StoredProcedure [dbo].[GET_BuyR3GeneralMetrics_v3]    Script Date: 7/3/2019 9:51:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		William Miller
-- Create date: 6/28/19
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GET_BuyR3ItemMetrics_v3]
	@StartDate DATE
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @StartDate DATE = '12/1/2018'

SELECT
	DATEADD(DAY,DATEDIFF(DAY, 0, bbh.CreateTime), 0)		[BusinessDate],
	bbh.LocationNo											[LocationNo],
	lba.VersionNo											[VersionNo],
	lba.TestGroup											[TestGroup]
INTO #BuyHeaderMetrics
FROM BUYS..BuyBinHeader bbh
	LEFT OUTER JOIN Sandbox..LocBuyAlgorithms lba
		ON bbh.LocationNo = lba.LocationNo
		AND bbh.CreateTime >= lba.StartDate
		AND (bbh.CreateTime < lba.EndDate 
		OR lba.EndDate IS NULL)
WHERE 
	bbh.CreateTime > DATEADD(YEAR, -1, @StartDate) AND
	bbh.StatusCode = 1 
GROUP BY 
	DATEADD(DAY,DATEDIFF(DAY, 0, bbh.CreateTime), 0),
	bbh.LocationNo,
	lba.VersionNo,
	lba.TestGroup


SELECT
	DATEADD(DAY,DATEDIFF(DAY, 0, bbh.CreateTime), 0)	[BusinessDate],
	bbh.LocationNo										[LocationNo],
	bt.BuyType											[BuyType],
	bhm.VersionNo										[VersionNo],
	bhm.TestGroup										[TestGroup],
	SUM(bbi.Offer)										[total_ItemOffers],
	SUM(bbi.Quantity)									[total_BuyItems],
	SUM(CASE 
			WHEN bbi.ItemEntryModeID IS NULL 
			THEN bbi.Quantity 
			END)										[total_ScannedQuantity],
	SUM(CASE 
			WHEN bbi.ItemEntryModeID IS NULL 
			THEN bbi.Offer
			END)										[total_ScannedOffers],
	SUM(CASE 
			WHEN bbi.Scoring_ID IS NOT NULL
			THEN bbi.Quantity 
			END)										[total_SuggestedOfferQuantity],
	SUM(CASE 
			WHEN bbi.Scoring_ID IS NOT NULL
			THEN bbi.SuggestedOffer
			END)										[total_SuggestedOfferAmount],
	SUM(CASE	
			WHEN bbi.SuggestedOffer = 0
			AND bbi.Scoring_ID IS NOT NULL
			THEN bbi.Quantity
			END)										[total_ZeroSuggestedOfferItems],
	SUM(CASE 
			WHEN bbi.SuggestedOffer <>  (bbi.Offer / NULLIF(bbi.Quantity, 0))
			AND bbi.Scoring_ID IS NOT NULL
			THEN bbi.Quantity
			END)										[total_SuggestedOfferAdjustedItems],
	SUM(CASE 
			WHEN bbi.SuggestedOffer <>  (bbi.Offer / NULLIF(bbi.Quantity, 0))
			AND bbi.Scoring_ID IS NOT NULL
			THEN bbi.Offer
			END)										[total_SuggestedOfferAdjustedOffers],
	SUM(CASE 
			WHEN bbi.SuggestedOffer >  (bbi.Offer / NULLIF(bbi.Quantity, 0))
			AND bbi.Scoring_ID IS NOT NULL
			THEN bbi.Quantity
			END)										[total_SuggestedOfferAdjustedItems_Up],
	SUM(CASE 
			WHEN bbi.SuggestedOffer >  (bbi.Offer / NULLIF(bbi.Quantity, 0))
			AND bbi.Scoring_ID IS NOT NULL
			THEN bbi.Offer
			END)										[total_SuggestedOfferAdjustedOffers_Up],
	SUM(CASE 
			WHEN bbi.SuggestedOffer <  (bbi.Offer / NULLIF(bbi.Quantity, 0))
			AND bbi.Scoring_ID IS NOT NULL
			THEN bbi.Quantity
			END)										[total_SuggestedOfferAdjustedItems_Down],
	SUM(CASE 
			WHEN bbi.SuggestedOffer <  (bbi.Offer / NULLIF(bbi.Quantity, 0))
			AND bbi.Scoring_ID IS NOT NULL
			THEN bbi.Offer
			END)										[total_SuggestedOfferAdjustedOffers_Down],
	COUNT(
		CASE
		WHEN bbi.SuggestedOfferType = 1
		THEN 1
		END)											[count_SuggestedOfferChain],
	SUM(
		CASE
		WHEN bbi.SuggestedOfferType = 1
		THEN bbi.SuggestedOffer
		END)											[total_SuggestedOfferChain],
	COUNT(
		CASE
		WHEN bbi.SuggestedOfferType = 2
		THEN 1
		END)											[count_SuggestedOfferLoc],
	SUM(
		CASE
		WHEN bbi.SuggestedOfferType = 2
		THEN bbi.SuggestedOffer
		END)											[total_SuggestedOfferLoc],
	COUNT(
		CASE
		WHEN bbi.SuggestedOfferType = 1
		AND bbi.SuggestedOffer = 0
		THEN 1
		END)											[count_SuggestedOfferChainZero],
	COUNT(
		CASE
		WHEN bbi.SuggestedOfferType = 2
		AND bbi.SuggestedOffer = 0
		THEN 1
		END)											[count_SuggestedOfferLocZero],
	CAST(COUNT(
		CASE
		WHEN bbi.SuggestedOfferType = 1
		AND bbi.SuggestedOffer <> (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
		THEN 1
		END) AS FLOAT)									[count_SuggestedOfferChainAdj],
	CAST(COUNT(
		CASE
		WHEN bbi.SuggestedOfferType = 2
		AND bbi.SuggestedOffer <> (bbi.Offer / NULLIF(bbi.Quantity, 0)) 
		THEN 1
		END) AS FLOAT)									[count_SuggestedOfferLocAdj]
INTO #BuyMetrics_Base
FROM BUYS..BuyBinHeader bbh
	INNER JOIN BUYS..BuyBinItems bbi
		ON bbh.BuyBinNo = bbi.BuyBinNo
		AND bbh.LocationNo = bbi.LocationNo
	INNER JOIN BUYS..BuyTypes bt
		ON bbi.BuyTypeID = bt.BuyTypeID
	INNER JOIN #BuyHeaderMetrics bhm
		ON bbh.LocationNo = bhm.LocationNo
		AND DATEADD(DAY,DATEDIFF(DAY, 0, bbh.CreateTime), 0) = bhm.BusinessDate
WHERE 
	bbh.CreateTime > DATEADD(YEAR, -1, @StartDate) AND
	bbh.StatusCode = 1 AND
	bbi.StatusCode = 1 AND
	bbi.Quantity > 0 AND
	bbi.Quantity < 10000 AND
	bbi.Offer < 10000
GROUP BY 
	DATEADD(DAY,DATEDIFF(DAY, 0, bbh.CreateTime), 0),
	bbh.LocationNo,
	bhm.VersionNo,
	bhm.TestGroup
ORDER BY bbh.LocationNo, BuyType, BusinessDate

DECLARE @Last_BusinessDate DATE
SELECT
	@Last_BusinessDate = MAX(BusinessDate)
FROM #BuyMetrics_Base

SELECT 
	bmb.BusinessDate,
	bmb.LocationNo,
	bmb.VersionNo,
	bmb.TestGroup,
	bmb.BuyType,
	bmb.total_ItemOffers,
	bmb.total_BuyItems,
	bmb.total_ScannedQuantity,
	bmb.total_ScannedOffers,
	bmb.total_SuggestedOfferQuantity,
	bmb.total_SuggestedOfferAmount,
	--Suggested offer adjustments
	bmb.total_SuggestedOfferAdjustedItems,
	bmb.total_SuggestedOfferAdjustedItems_Up,
	bmb.total_SuggestedOfferAdjustedItems_Down,
	bmb.total_SuggestedOfferAdjustedOffers,
	bmb.total_SuggestedOfferAdjustedOffers_Up,
	bmb.total_SuggestedOfferAdjustedOffers_Down,
	--Chain versus location offers plus adjustments
	bmb.count_SuggestedOfferChain,
	bmb.total_SuggestedOfferChain,
	bmb.count_SuggestedOfferLoc,
	bmb.total_SuggestedOfferLoc,
	bmb.count_SuggestedOfferChainAdj,
	bmb.count_SuggestedOfferLocAdj,
	--Offers of $0.00 from chain and location tables
	bmb.total_ZeroSuggestedOfferItems,
	bmb.count_SuggestedOfferChainZero,
	bmb.count_SuggestedOfferLocZero
INTO #BuyMetrics_TY
FROM #BuyMetrics_Base bmb
WHERE bmb.BusinessDate >= @StartDate

SELECT 
	DATEADD(YEAR, 1, bmb.BusinessDate) [BusinessDate_NextYear],
	bmb.LocationNo,
	bmb.VersionNo,
	bmb.TestGroup,
	bmb.BuyType,
	bmb.total_ItemOffers,
	bmb.total_BuyItems,
	bmb.total_ScannedQuantity,
	bmb.total_ScannedOffers,
	bmb.total_SuggestedOfferQuantity,
	bmb.total_SuggestedOfferAmount,
	--Suggested offer adjustments
	bmb.total_SuggestedOfferAdjustedItems,
	bmb.total_SuggestedOfferAdjustedItems_Up,
	bmb.total_SuggestedOfferAdjustedItems_Down,
	bmb.total_SuggestedOfferAdjustedOffers,
	bmb.total_SuggestedOfferAdjustedOffers_Up,
	bmb.total_SuggestedOfferAdjustedOffers_Down,
	--Chain versus location offers plus adjustments
	bmb.count_SuggestedOfferChain,
	bmb.total_SuggestedOfferChain,
	bmb.count_SuggestedOfferLoc,
	bmb.total_SuggestedOfferLoc,
	bmb.count_SuggestedOfferChainAdj,
	bmb.count_SuggestedOfferLocAdj,
	--Offers of $0.00 from chain and location tables
	bmb.total_ZeroSuggestedOfferItems,
	bmb.count_SuggestedOfferChainZero,
	bmb.count_SuggestedOfferLocZero
INTO #BuyMetrics_LY
FROM #BuyMetrics_Base bmb
WHERE 
	bmb.BusinessDate >= DATEADD(YEAR, -1, @StartDate) AND
	bmb.BusinessDate <= DATEADD(YEAR, -1, @Last_BusinessDate)


--Get chain average buy metrics
SELECT 
	bmt.BusinessDate,
	'00000' [LocationNo],
	NULL [VersionNo],
	NULL [TestGroup],
	bmt.BuyType,
	AVG(bmt.total_ItemOffers) [total_BuyOffers],
	AVG(bmt.total_BuyItems) [total_BuyItems],
	AVG(bmt.total_ScannedQuantity) [total_ScannedQuantity],
	AVG(bmt.total_ScannedOffers) [total_ScannedOffers],
	AVG(bmt.total_SuggestedOfferQuantity) [total_SuggestedOfferQuantity],
	AVG(bmt.total_SuggestedOfferAmount) [total_SuggestedOffers],
	--Suggested offer adjustments
	AVG(bmt.total_SuggestedOfferAdjustedItems) [total_SuggestedOfferAdjustedItems],
	AVG(bmt.total_SuggestedOfferAdjustedItems_Up) [total_SuggestedOfferAdjustedItems_Up],
	AVG(bmt.total_SuggestedOfferAdjustedItems_Down) [total_SuggestedOfferAdjustedItems_Down],
	AVG(bmt.total_SuggestedOfferAdjustedOffers) [total_SuggestedOfferAdjustedOffers],
	AVG(bmt.total_SuggestedOfferAdjustedOffers_Up) [total_SuggestedOfferAdjustedOffers_Up],
	AVG(bmt.total_SuggestedOfferAdjustedOffers_Down) [total_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(bmt.count_SuggestedOfferChain) [count_SuggestedOfferChain],
	AVG(bmt.total_SuggestedOfferChain) [total_SuggestedOfferChain],
	AVG(bmt.count_SuggestedOfferLoc) [count_SuggestedOfferLoc],
	AVG(bmt.total_SuggestedOfferLoc) [total_SuggestedOfferLoc],
	AVG(bmt.count_SuggestedOfferChainAdj) [count_SuggestedOfferChainAdj],
	AVG(bmt.count_SuggestedOfferLocAdj) [count_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(bmt.total_ZeroSuggestedOfferItems) [total_ZeroSuggestedOfferItems],
	AVG(bmt.count_SuggestedOfferChainZero) [count_SuggestedOfferChainZero],
	AVG(bmt.count_SuggestedOfferLocZero) [count_SuggestedOfferLocZero],
	--LY Chain averages
	AVG(bml.total_ItemOffers) [total_ly_BuyOffers],
	AVG(bml.total_BuyItems) [total_ly_BuyItems],
	AVG(bml.total_ScannedQuantity) [total_ly_ScannedQuantity],
	AVG(bml.total_ScannedOffers) [total_ly_ScannedOffers],
	AVG(bml.total_SuggestedOfferQuantity) [total_ly_SuggestedOfferQuantity],
	AVG(bml.total_SuggestedOfferAmount) [total_ly_SuggestedOffers],
	--Suggested offer adjustments
	AVG(bml.total_SuggestedOfferAdjustedItems) [total_ly_SuggestedOfferAdjustedItems],
	AVG(bml.total_SuggestedOfferAdjustedItems_Up) [total_ly_SuggestedOfferAdjustedItems_Up],
	AVG(bml.total_SuggestedOfferAdjustedItems_Down) [total_ly_SuggestedOfferAdjustedItems_Down],
	AVG(bml.total_SuggestedOfferAdjustedOffers) [total_ly_SuggestedOfferAdjustedOffers],
	AVG(bml.total_SuggestedOfferAdjustedOffers_Up) [total_ly_SuggestedOfferAdjustedOffers_Up],
	AVG(bml.total_SuggestedOfferAdjustedOffers_Down) [total_ly_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(bml.count_SuggestedOfferChain) [count_ly_SuggestedOfferChain],
	AVG(bml.total_SuggestedOfferChain) [total_ly_SuggestedOfferChain],
	AVG(bml.count_SuggestedOfferLoc) [count_ly_SuggestedOfferLoc],
	AVG(bml.total_SuggestedOfferLoc) [total_ly_SuggestedOfferLoc],
	AVG(bml.count_SuggestedOfferChainAdj) [count_ly_SuggestedOfferChainAdj],
	AVG(bml.count_SuggestedOfferLocAdj) [count_ly_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(bml.total_ZeroSuggestedOfferItems) [total_ly_ZeroSuggestedOfferItems],
	AVG(bml.count_SuggestedOfferChainZero) [count_ly_SuggestedOfferChainZero],
	AVG(bml.count_SuggestedOfferLocZero) [count_ly_SuggestedOfferLocZero], 
	--Rolling Chain averages
	AVG(AVG(bmt.total_ItemOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyOffers],
	AVG(AVG(bmt.total_BuyItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyItems],
	AVG(AVG(bmt.total_ScannedQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedQuantity],
	AVG(AVG(bmt.total_ScannedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedOffers],
	AVG(AVG(bmt.total_SuggestedOfferQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferQuantity],
	AVG(AVG(bmt.total_SuggestedOfferAmount)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOffers],
		--Suggested offer adjustments
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems_Up],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems_Down],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers_Up],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(AVG(bmt.count_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_CountSuggestedOfferChain],
	AVG(AVG(bmt.total_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_TotalSuggestedOfferChain],
	AVG(AVG(bmt.count_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_CountSuggestedOfferLoc],
	AVG(AVG(bmt.total_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_TotalSuggestedOfferLoc],
	AVG(AVG(bmt.count_SuggestedOfferChainAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferChainAdj],
	AVG(AVG(bmt.count_SuggestedOfferLocAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(AVG(bmt.total_ZeroSuggestedOfferItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ZeroSuggestedOfferItems],
	AVG(AVG(bmt.count_SuggestedOfferChainZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferChainZero],
	AVG(AVG(bmt.count_SuggestedOfferLocZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferLocZero],
	--Chain average differences from last year
	AVG(AVG(bml.total_ItemOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_BuyOffers],
	AVG(AVG(bml.total_BuyItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_BuyItems],
	AVG(AVG(bml.total_ScannedQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ScannedQuantity],
	AVG(AVG(bml.total_ScannedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ScannedOffers],
	AVG(AVG(bml.total_SuggestedOfferQuantity)) 
		OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferQuantity],
	AVG(AVG(bml.total_SuggestedOfferAmount)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOffers],
		--Suggested offer adjustments
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems],
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems_Up],
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems_Down],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers_Up],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(AVG(bml.count_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_CountSuggestedOfferChain],
	AVG(AVG(bml.total_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_TotalSuggestedOfferChain],
	AVG(AVG(bml.count_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_CountSuggestedOfferLoc],
	AVG(AVG(bml.total_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_TotalSuggestedOfferLoc],
	AVG(AVG(bml.count_SuggestedOfferChainAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferChainAdj],
	AVG(AVG(bml.count_SuggestedOfferLocAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(AVG(bml.total_ZeroSuggestedOfferItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ZeroSuggestedOfferItems],
	AVG(AVG(bml.count_SuggestedOfferChainZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferChainZero],
	AVG(AVG(bml.count_SuggestedOfferLocZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferLocZero]
FROM #BuyMetrics_TY bmt
	INNER JOIN #BuyMetrics_LY bml
		ON	bmt.BusinessDate = bml.BusinessDate_NextYear
		AND bmt.LocationNo = bml.LocationNo
		AND bmt.BuyType = bml.BuyType
GROUP BY bmt.BusinessDate, bmt.BuyType
UNION ALL
--Get release 3 average historical buy metrics for all test groups
SELECT 
	bmt.BusinessDate,
	'v1.r3' [LocationNo],
	'hist' [VersionNo],
	NULL [TestGroup],
bmt.BuyType,
	AVG(bmt.total_ItemOffers) [total_BuyOffers],
	AVG(bmt.total_BuyItems) [total_BuyItems],
	AVG(bmt.total_ScannedQuantity) [total_ScannedQuantity],
	AVG(bmt.total_ScannedOffers) [total_ScannedOffers],
	AVG(bmt.total_SuggestedOfferQuantity) [total_SuggestedOfferQuantity],
	AVG(bmt.total_SuggestedOfferAmount) [total_SuggestedOffers],
	--Suggested offer adjustments
	AVG(bmt.total_SuggestedOfferAdjustedItems) [total_SuggestedOfferAdjustedItems],
	AVG(bmt.total_SuggestedOfferAdjustedItems_Up) [total_SuggestedOfferAdjustedItems_Up],
	AVG(bmt.total_SuggestedOfferAdjustedItems_Down) [total_SuggestedOfferAdjustedItems_Down],
	AVG(bmt.total_SuggestedOfferAdjustedOffers) [total_SuggestedOfferAdjustedOffers],
	AVG(bmt.total_SuggestedOfferAdjustedOffers_Up) [total_SuggestedOfferAdjustedOffers_Up],
	AVG(bmt.total_SuggestedOfferAdjustedOffers_Down) [total_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(bmt.count_SuggestedOfferChain) [count_SuggestedOfferChain],
	AVG(bmt.total_SuggestedOfferChain) [total_SuggestedOfferChain],
	AVG(bmt.count_SuggestedOfferLoc) [count_SuggestedOfferLoc],
	AVG(bmt.total_SuggestedOfferLoc) [total_SuggestedOfferLoc],
	AVG(bmt.count_SuggestedOfferChainAdj) [count_SuggestedOfferChainAdj],
	AVG(bmt.count_SuggestedOfferLocAdj) [count_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(bmt.total_ZeroSuggestedOfferItems) [total_ZeroSuggestedOfferItems],
	AVG(bmt.count_SuggestedOfferChainZero) [count_SuggestedOfferChainZero],
	AVG(bmt.count_SuggestedOfferLocZero) [count_SuggestedOfferLocZero],
	--LY Chain averages
	AVG(bml.total_ItemOffers) [total_ly_BuyOffers],
	AVG(bml.total_BuyItems) [total_ly_BuyItems],
	AVG(bml.total_ScannedQuantity) [total_ly_ScannedQuantity],
	AVG(bml.total_ScannedOffers) [total_ly_ScannedOffers],
	AVG(bml.total_SuggestedOfferQuantity) [total_ly_SuggestedOfferQuantity],
	AVG(bml.total_SuggestedOfferAmount) [total_ly_SuggestedOffers],
	--Suggested offer adjustments
	AVG(bml.total_SuggestedOfferAdjustedItems) [total_ly_SuggestedOfferAdjustedItems],
	AVG(bml.total_SuggestedOfferAdjustedItems_Up) [total_ly_SuggestedOfferAdjustedItems_Up],
	AVG(bml.total_SuggestedOfferAdjustedItems_Down) [total_ly_SuggestedOfferAdjustedItems_Down],
	AVG(bml.total_SuggestedOfferAdjustedOffers) [total_ly_SuggestedOfferAdjustedOffers],
	AVG(bml.total_SuggestedOfferAdjustedOffers_Up) [total_ly_SuggestedOfferAdjustedOffers_Up],
	AVG(bml.total_SuggestedOfferAdjustedOffers_Down) [total_ly_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(bml.count_SuggestedOfferChain) [count_ly_SuggestedOfferChain],
	AVG(bml.total_SuggestedOfferChain) [total_ly_SuggestedOfferChain],
	AVG(bml.count_SuggestedOfferLoc) [count_ly_SuggestedOfferLoc],
	AVG(bml.total_SuggestedOfferLoc) [total_ly_SuggestedOfferLoc],
	AVG(bml.count_SuggestedOfferChainAdj) [count_ly_SuggestedOfferChainAdj],
	AVG(bml.count_SuggestedOfferLocAdj) [count_ly_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(bml.total_ZeroSuggestedOfferItems) [total_ly_ZeroSuggestedOfferItems],
	AVG(bml.count_SuggestedOfferChainZero) [count_ly_SuggestedOfferChainZero],
	AVG(bml.count_SuggestedOfferLocZero) [count_ly_SuggestedOfferLocZero], 
	--Rolling Chain averages
	AVG(AVG(bmt.total_ItemOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyOffers],
	AVG(AVG(bmt.total_BuyItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyItems],
	AVG(AVG(bmt.total_ScannedQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedQuantity],
	AVG(AVG(bmt.total_ScannedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedOffers],
	AVG(AVG(bmt.total_SuggestedOfferQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferQuantity],
	AVG(AVG(bmt.total_SuggestedOfferAmount)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOffers],
		--Suggested offer adjustments
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems_Up],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems_Down],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers_Up],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(AVG(bmt.count_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_CountSuggestedOfferChain],
	AVG(AVG(bmt.total_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_TotalSuggestedOfferChain],
	AVG(AVG(bmt.count_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_CountSuggestedOfferLoc],
	AVG(AVG(bmt.total_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_TotalSuggestedOfferLoc],
	AVG(AVG(bmt.count_SuggestedOfferChainAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferChainAdj],
	AVG(AVG(bmt.count_SuggestedOfferLocAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(AVG(bmt.total_ZeroSuggestedOfferItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ZeroSuggestedOfferItems],
	AVG(AVG(bmt.count_SuggestedOfferChainZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferChainZero],
	AVG(AVG(bmt.count_SuggestedOfferLocZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferLocZero],
	--Chain average differences from last year
	AVG(AVG(bml.total_ItemOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_BuyOffers],
	AVG(AVG(bml.total_BuyItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_BuyItems],
	AVG(AVG(bml.total_ScannedQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ScannedQuantity],
	AVG(AVG(bml.total_ScannedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ScannedOffers],
	AVG(AVG(bml.total_SuggestedOfferQuantity)) 
		OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferQuantity],
	AVG(AVG(bml.total_SuggestedOfferAmount)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOffers],
		--Suggested offer adjustments
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems],
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems_Up],
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems_Down],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers_Up],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(AVG(bml.count_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_CountSuggestedOfferChain],
	AVG(AVG(bml.total_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_TotalSuggestedOfferChain],
	AVG(AVG(bml.count_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_CountSuggestedOfferLoc],
	AVG(AVG(bml.total_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_TotalSuggestedOfferLoc],
	AVG(AVG(bml.count_SuggestedOfferChainAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferChainAdj],
	AVG(AVG(bml.count_SuggestedOfferLocAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(AVG(bml.total_ZeroSuggestedOfferItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ZeroSuggestedOfferItems],
	AVG(AVG(bml.count_SuggestedOfferChainZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferChainZero],
	AVG(AVG(bml.count_SuggestedOfferLocZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferLocZero]
FROM #BuyMetrics_TY bmt
	INNER JOIN #BuyMetrics_LY bml
		ON	bmt.BusinessDate = bml.BusinessDate_NextYear
		AND bmt.LocationNo = bml.LocationNo
		AND bmt.BuyType = bml.BuyType
WHERE bmt.LocationNo IN (
	SELECT DISTINCT
		LocationNo
	FROM #BuyHeaderMetrics
	WHERE VersionNo = 'v1.r3'
	)
GROUP BY bmt.BusinessDate, bmt.BuyType
UNION ALL
--Get release test group metrics for group 1
SELECT 
	bmt.BusinessDate,
	'tg1' [LocationNo],
	'v1.r3' [VersionNo],
	1 [TestGroup],
bmt.BuyType,
	AVG(bmt.total_ItemOffers) [total_BuyOffers],
	AVG(bmt.total_BuyItems) [total_BuyItems],
	AVG(bmt.total_ScannedQuantity) [total_ScannedQuantity],
	AVG(bmt.total_ScannedOffers) [total_ScannedOffers],
	AVG(bmt.total_SuggestedOfferQuantity) [total_SuggestedOfferQuantity],
	AVG(bmt.total_SuggestedOfferAmount) [total_SuggestedOffers],
	--Suggested offer adjustments
	AVG(bmt.total_SuggestedOfferAdjustedItems) [total_SuggestedOfferAdjustedItems],
	AVG(bmt.total_SuggestedOfferAdjustedItems_Up) [total_SuggestedOfferAdjustedItems_Up],
	AVG(bmt.total_SuggestedOfferAdjustedItems_Down) [total_SuggestedOfferAdjustedItems_Down],
	AVG(bmt.total_SuggestedOfferAdjustedOffers) [total_SuggestedOfferAdjustedOffers],
	AVG(bmt.total_SuggestedOfferAdjustedOffers_Up) [total_SuggestedOfferAdjustedOffers_Up],
	AVG(bmt.total_SuggestedOfferAdjustedOffers_Down) [total_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(bmt.count_SuggestedOfferChain) [count_SuggestedOfferChain],
	AVG(bmt.total_SuggestedOfferChain) [total_SuggestedOfferChain],
	AVG(bmt.count_SuggestedOfferLoc) [count_SuggestedOfferLoc],
	AVG(bmt.total_SuggestedOfferLoc) [total_SuggestedOfferLoc],
	AVG(bmt.count_SuggestedOfferChainAdj) [count_SuggestedOfferChainAdj],
	AVG(bmt.count_SuggestedOfferLocAdj) [count_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(bmt.total_ZeroSuggestedOfferItems) [total_ZeroSuggestedOfferItems],
	AVG(bmt.count_SuggestedOfferChainZero) [count_SuggestedOfferChainZero],
	AVG(bmt.count_SuggestedOfferLocZero) [count_SuggestedOfferLocZero],
	--LY Chain averages
	AVG(bml.total_ItemOffers) [total_ly_BuyOffers],
	AVG(bml.total_BuyItems) [total_ly_BuyItems],
	AVG(bml.total_ScannedQuantity) [total_ly_ScannedQuantity],
	AVG(bml.total_ScannedOffers) [total_ly_ScannedOffers],
	AVG(bml.total_SuggestedOfferQuantity) [total_ly_SuggestedOfferQuantity],
	AVG(bml.total_SuggestedOfferAmount) [total_ly_SuggestedOffers],
	--Suggested offer adjustments
	AVG(bml.total_SuggestedOfferAdjustedItems) [total_ly_SuggestedOfferAdjustedItems],
	AVG(bml.total_SuggestedOfferAdjustedItems_Up) [total_ly_SuggestedOfferAdjustedItems_Up],
	AVG(bml.total_SuggestedOfferAdjustedItems_Down) [total_ly_SuggestedOfferAdjustedItems_Down],
	AVG(bml.total_SuggestedOfferAdjustedOffers) [total_ly_SuggestedOfferAdjustedOffers],
	AVG(bml.total_SuggestedOfferAdjustedOffers_Up) [total_ly_SuggestedOfferAdjustedOffers_Up],
	AVG(bml.total_SuggestedOfferAdjustedOffers_Down) [total_ly_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(bml.count_SuggestedOfferChain) [count_ly_SuggestedOfferChain],
	AVG(bml.total_SuggestedOfferChain) [total_ly_SuggestedOfferChain],
	AVG(bml.count_SuggestedOfferLoc) [count_ly_SuggestedOfferLoc],
	AVG(bml.total_SuggestedOfferLoc) [total_ly_SuggestedOfferLoc],
	AVG(bml.count_SuggestedOfferChainAdj) [count_ly_SuggestedOfferChainAdj],
	AVG(bml.count_SuggestedOfferLocAdj) [count_ly_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(bml.total_ZeroSuggestedOfferItems) [total_ly_ZeroSuggestedOfferItems],
	AVG(bml.count_SuggestedOfferChainZero) [count_ly_SuggestedOfferChainZero],
	AVG(bml.count_SuggestedOfferLocZero) [count_ly_SuggestedOfferLocZero], 
	--Rolling Chain averages
	AVG(AVG(bmt.total_ItemOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyOffers],
	AVG(AVG(bmt.total_BuyItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyItems],
	AVG(AVG(bmt.total_ScannedQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedQuantity],
	AVG(AVG(bmt.total_ScannedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedOffers],
	AVG(AVG(bmt.total_SuggestedOfferQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferQuantity],
	AVG(AVG(bmt.total_SuggestedOfferAmount)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOffers],
		--Suggested offer adjustments
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems_Up],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems_Down],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers_Up],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(AVG(bmt.count_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_CountSuggestedOfferChain],
	AVG(AVG(bmt.total_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_TotalSuggestedOfferChain],
	AVG(AVG(bmt.count_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_CountSuggestedOfferLoc],
	AVG(AVG(bmt.total_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_TotalSuggestedOfferLoc],
	AVG(AVG(bmt.count_SuggestedOfferChainAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferChainAdj],
	AVG(AVG(bmt.count_SuggestedOfferLocAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(AVG(bmt.total_ZeroSuggestedOfferItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ZeroSuggestedOfferItems],
	AVG(AVG(bmt.count_SuggestedOfferChainZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferChainZero],
	AVG(AVG(bmt.count_SuggestedOfferLocZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferLocZero],
	--Chain average differences from last year
	AVG(AVG(bml.total_ItemOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_BuyOffers],
	AVG(AVG(bml.total_BuyItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_BuyItems],
	AVG(AVG(bml.total_ScannedQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ScannedQuantity],
	AVG(AVG(bml.total_ScannedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ScannedOffers],
	AVG(AVG(bml.total_SuggestedOfferQuantity)) 
		OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferQuantity],
	AVG(AVG(bml.total_SuggestedOfferAmount)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOffers],
		--Suggested offer adjustments
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems],
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems_Up],
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems_Down],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers_Up],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(AVG(bml.count_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_CountSuggestedOfferChain],
	AVG(AVG(bml.total_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_TotalSuggestedOfferChain],
	AVG(AVG(bml.count_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_CountSuggestedOfferLoc],
	AVG(AVG(bml.total_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_TotalSuggestedOfferLoc],
	AVG(AVG(bml.count_SuggestedOfferChainAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferChainAdj],
	AVG(AVG(bml.count_SuggestedOfferLocAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(AVG(bml.total_ZeroSuggestedOfferItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ZeroSuggestedOfferItems],
	AVG(AVG(bml.count_SuggestedOfferChainZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferChainZero],
	AVG(AVG(bml.count_SuggestedOfferLocZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferLocZero]
FROM #BuyMetrics_TY bmt
	INNER JOIN #BuyMetrics_LY bml
		ON	bmt.BusinessDate = bml.BusinessDate_NextYear
		AND bmt.LocationNo = bml.LocationNo
		AND bmt.BuyType = bml.BuyType
WHERE bmt.LocationNo IN (
	SELECT DISTINCT
		LocationNo
	FROM #BuyHeaderMetrics
	WHERE VersionNo = 'v1.r3' AND TestGroup = 1
	)
GROUP BY bmt.BusinessDate, bmt.BuyType
UNION ALL
--Get release test group metrics for group 1
SELECT 
	bmt.BusinessDate,
	'tg2' [LocationNo],
	'v1.r3' [VersionNo],
	2 [TestGroup],
bmt.BuyType,
	AVG(bmt.total_ItemOffers) [total_BuyOffers],
	AVG(bmt.total_BuyItems) [total_BuyItems],
	AVG(bmt.total_ScannedQuantity) [total_ScannedQuantity],
	AVG(bmt.total_ScannedOffers) [total_ScannedOffers],
	AVG(bmt.total_SuggestedOfferQuantity) [total_SuggestedOfferQuantity],
	AVG(bmt.total_SuggestedOfferAmount) [total_SuggestedOffers],
	--Suggested offer adjustments
	AVG(bmt.total_SuggestedOfferAdjustedItems) [total_SuggestedOfferAdjustedItems],
	AVG(bmt.total_SuggestedOfferAdjustedItems_Up) [total_SuggestedOfferAdjustedItems_Up],
	AVG(bmt.total_SuggestedOfferAdjustedItems_Down) [total_SuggestedOfferAdjustedItems_Down],
	AVG(bmt.total_SuggestedOfferAdjustedOffers) [total_SuggestedOfferAdjustedOffers],
	AVG(bmt.total_SuggestedOfferAdjustedOffers_Up) [total_SuggestedOfferAdjustedOffers_Up],
	AVG(bmt.total_SuggestedOfferAdjustedOffers_Down) [total_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(bmt.count_SuggestedOfferChain) [count_SuggestedOfferChain],
	AVG(bmt.total_SuggestedOfferChain) [total_SuggestedOfferChain],
	AVG(bmt.count_SuggestedOfferLoc) [count_SuggestedOfferLoc],
	AVG(bmt.total_SuggestedOfferLoc) [total_SuggestedOfferLoc],
	AVG(bmt.count_SuggestedOfferChainAdj) [count_SuggestedOfferChainAdj],
	AVG(bmt.count_SuggestedOfferLocAdj) [count_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(bmt.total_ZeroSuggestedOfferItems) [total_ZeroSuggestedOfferItems],
	AVG(bmt.count_SuggestedOfferChainZero) [count_SuggestedOfferChainZero],
	AVG(bmt.count_SuggestedOfferLocZero) [count_SuggestedOfferLocZero],
	--LY Chain averages
	AVG(bml.total_ItemOffers) [total_ly_BuyOffers],
	AVG(bml.total_BuyItems) [total_ly_BuyItems],
	AVG(bml.total_ScannedQuantity) [total_ly_ScannedQuantity],
	AVG(bml.total_ScannedOffers) [total_ly_ScannedOffers],
	AVG(bml.total_SuggestedOfferQuantity) [total_ly_SuggestedOfferQuantity],
	AVG(bml.total_SuggestedOfferAmount) [total_ly_SuggestedOffers],
	--Suggested offer adjustments
	AVG(bml.total_SuggestedOfferAdjustedItems) [total_ly_SuggestedOfferAdjustedItems],
	AVG(bml.total_SuggestedOfferAdjustedItems_Up) [total_ly_SuggestedOfferAdjustedItems_Up],
	AVG(bml.total_SuggestedOfferAdjustedItems_Down) [total_ly_SuggestedOfferAdjustedItems_Down],
	AVG(bml.total_SuggestedOfferAdjustedOffers) [total_ly_SuggestedOfferAdjustedOffers],
	AVG(bml.total_SuggestedOfferAdjustedOffers_Up) [total_ly_SuggestedOfferAdjustedOffers_Up],
	AVG(bml.total_SuggestedOfferAdjustedOffers_Down) [total_ly_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(bml.count_SuggestedOfferChain) [count_ly_SuggestedOfferChain],
	AVG(bml.total_SuggestedOfferChain) [total_ly_SuggestedOfferChain],
	AVG(bml.count_SuggestedOfferLoc) [count_ly_SuggestedOfferLoc],
	AVG(bml.total_SuggestedOfferLoc) [total_ly_SuggestedOfferLoc],
	AVG(bml.count_SuggestedOfferChainAdj) [count_ly_SuggestedOfferChainAdj],
	AVG(bml.count_SuggestedOfferLocAdj) [count_ly_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(bml.total_ZeroSuggestedOfferItems) [total_ly_ZeroSuggestedOfferItems],
	AVG(bml.count_SuggestedOfferChainZero) [count_ly_SuggestedOfferChainZero],
	AVG(bml.count_SuggestedOfferLocZero) [count_ly_SuggestedOfferLocZero], 
	--Rolling Chain averages
	AVG(AVG(bmt.total_ItemOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyOffers],
	AVG(AVG(bmt.total_BuyItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyItems],
	AVG(AVG(bmt.total_ScannedQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedQuantity],
	AVG(AVG(bmt.total_ScannedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedOffers],
	AVG(AVG(bmt.total_SuggestedOfferQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferQuantity],
	AVG(AVG(bmt.total_SuggestedOfferAmount)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOffers],
		--Suggested offer adjustments
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems_Up],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedItems_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems_Down],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers_Up],
	AVG(AVG(bmt.total_SuggestedOfferAdjustedOffers_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(AVG(bmt.count_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_CountSuggestedOfferChain],
	AVG(AVG(bmt.total_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_TotalSuggestedOfferChain],
	AVG(AVG(bmt.count_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_CountSuggestedOfferLoc],
	AVG(AVG(bmt.total_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_TotalSuggestedOfferLoc],
	AVG(AVG(bmt.count_SuggestedOfferChainAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferChainAdj],
	AVG(AVG(bmt.count_SuggestedOfferLocAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(AVG(bmt.total_ZeroSuggestedOfferItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ZeroSuggestedOfferItems],
	AVG(AVG(bmt.count_SuggestedOfferChainZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferChainZero],
	AVG(AVG(bmt.count_SuggestedOfferLocZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferLocZero],
	--Chain average differences from last year
	AVG(AVG(bml.total_ItemOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_BuyOffers],
	AVG(AVG(bml.total_BuyItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_BuyItems],
	AVG(AVG(bml.total_ScannedQuantity)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ScannedQuantity],
	AVG(AVG(bml.total_ScannedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ScannedOffers],
	AVG(AVG(bml.total_SuggestedOfferQuantity)) 
		OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferQuantity],
	AVG(AVG(bml.total_SuggestedOfferAmount)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOffers],
		--Suggested offer adjustments
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems],
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems_Up],
	AVG(AVG(bml.total_SuggestedOfferAdjustedItems_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems_Down],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers_Up)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers_Up],
	AVG(AVG(bml.total_SuggestedOfferAdjustedOffers_Down)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(AVG(bml.count_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_CountSuggestedOfferChain],
	AVG(AVG(bml.total_SuggestedOfferChain)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_TotalSuggestedOfferChain],
	AVG(AVG(bml.count_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_CountSuggestedOfferLoc],
	AVG(AVG(bml.total_SuggestedOfferLoc)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_TotalSuggestedOfferLoc],
	AVG(AVG(bml.count_SuggestedOfferChainAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferChainAdj],
	AVG(AVG(bml.count_SuggestedOfferLocAdj)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(AVG(bml.total_ZeroSuggestedOfferItems)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ZeroSuggestedOfferItems],
	AVG(AVG(bml.count_SuggestedOfferChainZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferChainZero],
	AVG(AVG(bml.count_SuggestedOfferLocZero)) OVER (
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferLocZero]
FROM #BuyMetrics_TY bmt
	INNER JOIN #BuyMetrics_LY bml
		ON	bmt.BusinessDate = bml.BusinessDate_NextYear
		AND bmt.LocationNo = bml.LocationNo
		AND bmt.BuyType = bml.BuyType
WHERE bmt.LocationNo IN (
	SELECT DISTINCT
		LocationNo
	FROM #BuyHeaderMetrics
	WHERE VersionNo = 'v1.r3' AND TestGroup = 2
	)
GROUP BY bmt.BusinessDate, bmt.BuyType
UNION ALL
--Get individual location buy metrics
SELECT 
	bmt.BusinessDate,
	bmt.LocationNo,
	bmt.VersionNo,
	bmt.TestGroup,
	bmt.BuyType,
	--Location actual metrics
	bmt.total_ItemOffers [total_BuyOffers],
	bmt.total_BuyItems [total_BuyItems],
	bmt.total_ScannedQuantity [total_ScannedQuantity],
	bmt.total_ScannedOffers [total_ScannedOffers],
	bmt.total_SuggestedOfferQuantity [total_SuggestedOfferQuantity],
	bmt.total_SuggestedOfferAmount [total_SuggestedOffers],
	--Suggested offer adjustments
	bmt.total_SuggestedOfferAdjustedItems [total_SuggestedOfferAdjustedItems],
	bmt.total_SuggestedOfferAdjustedItems_Up [total_SuggestedOfferAdjustedItems_Up],
	bmt.total_SuggestedOfferAdjustedItems_Down [total_SuggestedOfferAdjustedItems_Down],
	bmt.total_SuggestedOfferAdjustedOffers [total_SuggestedOfferAdjustedOffers],
	bmt.total_SuggestedOfferAdjustedOffers_Up [total_SuggestedOfferAdjustedOffers_Up],
	bmt.total_SuggestedOfferAdjustedOffers_Down [total_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	bmt.count_SuggestedOfferChain [count_SuggestedOfferChain],
	bmt.total_SuggestedOfferChain [total_SuggestedOfferChain],
	bmt.count_SuggestedOfferLoc [count_SuggestedOfferLoc],
	bmt.total_SuggestedOfferLoc [total_SuggestedOfferLoc],
	bmt.count_SuggestedOfferChainAdj [count_SuggestedOfferChainAdj],
	bmt.count_SuggestedOfferLocAdj [count_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	bmt.total_ZeroSuggestedOfferItems [total_ZeroSuggestedOfferItems],
	bmt.count_SuggestedOfferChainZero [count_SuggestedOfferChainZero],
	bmt.count_SuggestedOfferLocZero [count_SuggestedOfferLocZero],
		--LY Chain averages
	bml.total_ItemOffers [total_ly_BuyOffers],
	bml.total_BuyItems [total_ly_BuyItems],
	bml.total_ScannedQuantity [total_ly_ScannedQuantity],
	bml.total_ScannedOffers [total_ly_ScannedOffers],
	bml.total_SuggestedOfferQuantity [total_ly_SuggestedOfferQuantity],
	bml.total_SuggestedOfferAmount [total_ly_SuggestedOffers],
	--Suggested offer adjustments
	bml.total_SuggestedOfferAdjustedItems [total_ly_SuggestedOfferAdjustedItems],
	bml.total_SuggestedOfferAdjustedItems_Up [total_ly_SuggestedOfferAdjustedItems_Up],
	bml.total_SuggestedOfferAdjustedItems_Down [total_ly_SuggestedOfferAdjustedItems_Down],
	bml.total_SuggestedOfferAdjustedOffers [total_ly_SuggestedOfferAdjustedOffers],
	bml.total_SuggestedOfferAdjustedOffers_Up [total_ly_SuggestedOfferAdjustedOffers_Up],
	bml.total_SuggestedOfferAdjustedOffers_Down [total_ly_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	bml.count_SuggestedOfferChain [count_ly_SuggestedOfferChain],
	bml.total_SuggestedOfferChain [total_ly_SuggestedOfferChain],
	bml.count_SuggestedOfferLoc [count_ly_SuggestedOfferLoc],
	bml.total_SuggestedOfferLoc [total_ly_SuggestedOfferLoc],
	bml.count_SuggestedOfferChainAdj [count_ly_SuggestedOfferChainAdj],
	bml.count_SuggestedOfferLocAdj [count_ly_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	bml.total_ZeroSuggestedOfferItems [total_ly_ZeroSuggestedOfferItems],
	bml.count_SuggestedOfferChainZero [count_ly_SuggestedOfferChainZero],
	bml.count_SuggestedOfferLocZero [count_ly_SuggestedOfferLocZero], 
	--Chain averages
	AVG(bmt.total_ItemOffers) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyOffers],
	AVG(bmt.total_BuyItems) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyItems],
	AVG(bmt.total_ScannedQuantity) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedQuantity],
	AVG(bmt.total_ScannedOffers) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedOffers],
	AVG(bmt.total_SuggestedOfferQuantity) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferQuantity],
	AVG(bmt.total_SuggestedOfferAmount) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOffers],
		--Suggested offer adjustments
	AVG(bmt.total_SuggestedOfferAdjustedItems) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems],
	AVG(bmt.total_SuggestedOfferAdjustedItems_Up) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems_Up],
	AVG(bmt.total_SuggestedOfferAdjustedItems_Down) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedItems_Down],
	AVG(bmt.total_SuggestedOfferAdjustedOffers) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers],
	AVG(bmt.total_SuggestedOfferAdjustedOffers_Up) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers_Up],
	AVG(bmt.total_SuggestedOfferAdjustedOffers_Down) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(bmt.count_SuggestedOfferChain) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_CountSuggestedOfferChain],
	AVG(bmt.total_SuggestedOfferChain) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_TotalSuggestedOfferChain],
	AVG(bmt.count_SuggestedOfferLoc) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_CountSuggestedOfferLoc],
	AVG(bmt.total_SuggestedOfferLoc) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_TotalSuggestedOfferLoc],
	AVG(bmt.count_SuggestedOfferChainAdj) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferChainAdj],
	AVG(bmt.count_SuggestedOfferLocAdj) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(bmt.total_ZeroSuggestedOfferItems) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ZeroSuggestedOfferItems],
	AVG(bmt.count_SuggestedOfferChainZero) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferChainZero],
	AVG(bmt.count_SuggestedOfferLocZero) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferLocZero],
	--Chain average differences from last year
	AVG(bml.total_ItemOffers) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_BuyOffers],
	AVG(bml.total_BuyItems) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_BuyItems],
	AVG(bml.total_ScannedQuantity) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ScannedQuantity],
	AVG(bml.total_ScannedOffers) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ScannedOffers],
	AVG(bml.total_SuggestedOfferQuantity) OVER (PARTITION BY bmt.LocationNo 
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferQuantity],
	AVG(bml.total_SuggestedOfferAmount) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOffers],
		--Suggested offer adjustments
	AVG(bml.total_SuggestedOfferAdjustedItems) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems],
	AVG(bml.total_SuggestedOfferAdjustedItems_Up) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems_Up],
	AVG(bml.total_SuggestedOfferAdjustedItems_Down) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedItems_Down],
	AVG(bml.total_SuggestedOfferAdjustedOffers) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers],
	AVG(bml.total_SuggestedOfferAdjustedOffers_Up) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers_Up],
	AVG(bml.total_SuggestedOfferAdjustedOffers_Down) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferAdjustedOffers_Down],
	--Chain versus location offers plus adjustments
	AVG(bml.count_SuggestedOfferChain) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_CountSuggestedOfferChain],
	AVG(bml.total_SuggestedOfferChain) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_TotalSuggestedOfferChain],
	AVG(bml.count_SuggestedOfferLoc) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_CountSuggestedOfferLoc],
	AVG(bml.total_SuggestedOfferLoc) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_TotalSuggestedOfferLoc],
	AVG(bml.count_SuggestedOfferChainAdj) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferChainAdj],
	AVG(bml.count_SuggestedOfferLocAdj) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferLocAdj],
	--Offers of $0.00 from chain and location tables
	AVG(bml.total_ZeroSuggestedOfferItems) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_ZeroSuggestedOfferItems],
	AVG(bml.count_SuggestedOfferChainZero) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferChainZero],
	AVG(bml.count_SuggestedOfferLocZero) OVER (PARTITION BY bmt.LocationNo
		ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [ly_rollavg_SuggestedOfferLocZero]
FROM #BuyMetrics_TY bmt
	INNER JOIN #BuyMetrics_LY bml
		ON	bmt.BusinessDate = bml.BusinessDate_NextYear
		AND bmt.LocationNo = bml.LocationNo
		AND bmt.BuyType = bml.BuyType
ORDER BY LocationNo, BuyType, BusinessDate

DROP TABLE #BuyHeaderMetrics
DROP TABLE #BuyMetrics_Base
DROP TABLE #BuyMetrics_LY
DROP TABLE #BuyMetrics_TY


END

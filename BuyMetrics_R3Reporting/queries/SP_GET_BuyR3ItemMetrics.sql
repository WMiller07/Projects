USE [Sandbox]
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		William Miller
-- Create date: 6/28/19
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[GET_BuyR3GeneralMetrics]
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
	lba.TestGroup											[TestGroup],
	COUNT(bbh.BuyBinNo)										[count_BuyTransactions],
	SUM(bbh.TotalOffer)										[total_BuyOffers],
	SUM(CASE
		--if the start machine and end machine are different, and either is a SIPS machine, do not count the wait times towards the total (time zone problem)
		WHEN 	(bbh.CreateMachine = bbh.UpdateMachine OR
				(LOWER(bbh.CreateMachine) NOT LIKE '%sips%' AND
				LOWER(bbh.UpdateMachine) NOT LIKE '%sips%')) AND
				DATEDIFF(MINUTE, bbh.CreateTime, bbh.UpdateTime) < 180
		THEN	DATEDIFF(SECOND, bbh.CreateTime, bbh.UpdateTime)
		END) [total_BuyWaitSec]
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
	'All'												[BuyType],
	bhm.VersionNo										[VersionNo],
	bhm.TestGroup										[TestGroup],
	bhm.count_BuyTransactions							[count_BuyTransactions],
	bhm.total_BuyOffers									[total_BuyOffers],
	bhm.total_BuyWaitSec								[total_BuyWait_Sec],
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
	COUNT(
		CASE
		WHEN bbi.SuggestedOfferType = 2
		THEN 1
		END)											[count_SuggestedOfferLoc],
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
	bhm.count_BuyTransactions,
	bhm.total_BuyOffers,
	bhm.total_BuyWaitSec,	
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
	bmb.count_BuyTransactions,
	bmb.total_BuyOffers,
	bmb.total_ItemOffers,
	bmb.total_BuyItems,
	bmb.total_ScannedQuantity,
	bmb.total_ScannedOffers,
	bmb.total_SuggestedOfferQuantity,
	bmb.total_SuggestedOfferAmount,
	bmb.total_BuyWait_Sec
INTO #BuyMetrics_TY
FROM #BuyMetrics_Base bmb
WHERE bmb.BusinessDate >= @StartDate

SELECT 
	DATEADD(YEAR, 1, bmb.BusinessDate) [BusinessDate_NextYear],
	bmb.LocationNo,
	bmb.VersionNo,
	bmb.TestGroup,
	bmb.BuyType,
	bmb.count_BuyTransactions,
	bmb.total_BuyOffers,
	bmb.total_ItemOffers,
	bmb.total_BuyItems,
	bmb.total_ScannedQuantity,
	bmb.total_ScannedOffers,
	bmb.total_SuggestedOfferQuantity,
	bmb.total_SuggestedOfferAmount,
	bmb.total_BuyWait_Sec
INTO #BuyMetrics_LY
FROM #BuyMetrics_Base bmb
WHERE 
	bmb.BusinessDate >= DATEADD(YEAR, -1, @StartDate) AND
	bmb.BusinessDate <= DATEADD(YEAR, -1, @Last_BusinessDate)

SELECT 
	bty.BusinessDate,
	bty.LocationNo,
	bty.BuyType,
	bty.count_BuyTransactions - bly.count_BuyTransactions [diff_count_BuyTransactions],
	bty.total_BuyOffers - bly.total_BuyOffers [diff_total_BuyOffers],
	bty.total_ItemOffers - bly.total_ItemOffers [diff_total_ItemOffers],
	bty.total_BuyItems - bly.total_BuyItems [diff_total_BuyItems],
	bty.total_ScannedQuantity - bly.total_ScannedQuantity [diff_total_ScannedQuantity],
	bty.total_ScannedOffers - bly.total_ScannedOffers [diff_total_ScannedOffers],
	bty.total_SuggestedOfferQuantity - bly.total_SuggestedOfferQuantity [diff_total_SuggestedOfferQuantity],
	bty.total_SuggestedOfferAmount - bly.total_SuggestedOfferAmount [diff_total_SuggestedOffers],
	bty.total_BuyWait_Sec - bly.total_BuyWait_Sec [diff_total_BuyWait_Sec]
INTO #BuyMetrics_Diff
FROM #BuyMetrics_TY bty
	INNER JOIN #BuyMetrics_LY bly
		ON bty.BusinessDate = bly.BusinessDate_NextYear
		AND bty.LocationNo = bly.LocationNo
		AND bty.BuyType = bly.BuyType

--Get chain average buy metrics
SELECT 
	bmt.BusinessDate,
	'00000' [LocationNo],
	NULL [VersionNo],
	NULL [TestGroup],
	bmt.BuyType,
	AVG(bmt.count_BuyTransactions) [total_BuyTransactions],
	AVG(bmt.total_BuyOffers) [total_BuyOffers],
	AVG(bmt.total_BuyItems) [total_BuyItems],
	AVG(bmt.total_ScannedQuantity) [total_ScannedQuantity],
	AVG(bmt.total_ScannedOffers) [total_ScannedOffers],
	AVG(bmt.total_SuggestedOfferQuantity) [total_SuggestedOfferQuantity],
	AVG(bmt.total_SuggestedOfferAmount) [total_SuggestedOffers],
	AVG(bmt.total_BuyWait_Sec) [total_BuyWait_Sec],
	--Chain averages
	AVG(AVG(bmt.count_BuyTransactions)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyTransactions],
	AVG(AVG(bmt.total_BuyOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyOffers],
	AVG(AVG(bmt.total_BuyItems)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyItems],
	AVG(AVG(bmt.total_ScannedQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedQuantity],
	AVG(AVG(bmt.total_ScannedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedOffers],
	AVG(AVG(bmt.total_SuggestedOfferQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferQuantity],
	AVG(AVG(bmt.total_SuggestedOfferAmount)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOffers],
	AVG(AVG(bmt.total_BuyWait_Sec)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyWait_Sec],
	--Chain average differences from last year
	AVG(AVG(bmd.diff_count_BuyTransactions)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyTransactions],
	AVG(AVG(bmd.diff_total_BuyOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyOffers],
	AVG(AVG(bmd.diff_total_BuyItems)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyItems],
	AVG(AVG(bmd.diff_total_ScannedQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_ScannedQuantity],
	AVG(AVG(bmd.diff_total_ScannedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_ScannedOffers],
	AVG(AVG(bmd.diff_total_SuggestedOfferQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_SuggestedOfferQuantity],
	AVG(AVG(bmd.diff_total_SuggestedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_SuggestedOffers],
	AVG(AVG(bmd.diff_total_BuyWait_Sec)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyWait_Sec]
FROM #BuyMetrics_TY bmt
	INNER JOIN #BuyMetrics_Diff bmd
		ON	bmt.BusinessDate = bmd.BusinessDate 
		AND bmt.LocationNo = bmd.LocationNo
		AND bmt.BuyType = bmd.BuyType
GROUP BY bmt.BusinessDate, bmt.BuyType
UNION ALL
--Get release 3 average historical buy metrics for all test groups
SELECT 
	bmt.BusinessDate,
	'v1.r3' [LocationNo],
	'hist' [VersionNo],
	NULL [TestGroup],
	bmt.BuyType,
	AVG(bmt.count_BuyTransactions) [total_BuyTransactions],
	AVG(bmt.total_BuyOffers) [total_BuyOffers],
	AVG(bmt.total_BuyItems) [total_BuyItems],
	AVG(bmt.total_ScannedQuantity) [total_ScannedQuantity],
	AVG(bmt.total_ScannedOffers) [total_ScannedOffers],
	AVG(bmt.total_SuggestedOfferQuantity) [total_SuggestedOfferQuantity],
	AVG(bmt.total_SuggestedOfferAmount) [total_SuggestedOffers],
	AVG(bmt.total_BuyWait_Sec) [total_BuyWait_Sec],
	--Chain averages
	AVG(AVG(bmt.count_BuyTransactions)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyTransactions],
	AVG(AVG(bmt.total_BuyOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyOffers],
	AVG(AVG(bmt.total_BuyItems)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyItems],
	AVG(AVG(bmt.total_ScannedQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedQuantity],
	AVG(AVG(bmt.total_ScannedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedOffers],
	AVG(AVG(bmt.total_SuggestedOfferQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferQuantity],
	AVG(AVG(bmt.total_SuggestedOfferAmount)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOffers],
	AVG(AVG(bmt.total_BuyWait_Sec)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyWait_Sec],
	--Chain average differences from last year
	AVG(AVG(bmd.diff_count_BuyTransactions)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyTransactions],
	AVG(AVG(bmd.diff_total_BuyOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyOffers],
	AVG(AVG(bmd.diff_total_BuyItems)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyItems],
	AVG(AVG(bmd.diff_total_ScannedQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_ScannedQuantity],
	AVG(AVG(bmd.diff_total_ScannedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_ScannedOffers],
	AVG(AVG(bmd.diff_total_SuggestedOfferQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_SuggestedOfferQuantity],
	AVG(AVG(bmd.diff_total_SuggestedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_SuggestedOffers],
	AVG(AVG(bmd.diff_total_BuyWait_Sec)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyWait_Sec]
FROM #BuyMetrics_TY bmt
	INNER JOIN #BuyMetrics_Diff bmd
		ON	bmt.BusinessDate = bmd.BusinessDate 
		AND bmt.LocationNo = bmd.LocationNo
		AND bmt.BuyType = bmd.BuyType
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
	AVG(bmt.count_BuyTransactions) [total_BuyTransactions],
	AVG(bmt.total_BuyOffers) [total_BuyOffers],
	AVG(bmt.total_BuyItems) [total_BuyItems],
	AVG(bmt.total_ScannedQuantity) [total_ScannedQuantity],
	AVG(bmt.total_ScannedOffers) [total_ScannedOffers],
	AVG(bmt.total_SuggestedOfferQuantity) [total_SuggestedOfferQuantity],
	AVG(bmt.total_SuggestedOfferAmount) [total_SuggestedOffers],
	AVG(bmt.total_BuyWait_Sec) [total_BuyWait_Sec],
	--Chain averages
	AVG(AVG(bmt.count_BuyTransactions)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyTransactions],
	AVG(AVG(bmt.total_BuyOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyOffers],
	AVG(AVG(bmt.total_BuyItems)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyItems],
	AVG(AVG(bmt.total_ScannedQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedQuantity],
	AVG(AVG(bmt.total_ScannedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedOffers],
	AVG(AVG(bmt.total_SuggestedOfferQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferQuantity],
	AVG(AVG(bmt.total_SuggestedOfferAmount)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOffers],
	AVG(AVG(bmt.total_BuyWait_Sec)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyWait_Sec],
	--Chain average differences from last year
	AVG(AVG(bmd.diff_count_BuyTransactions)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyTransactions],
	AVG(AVG(bmd.diff_total_BuyOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyOffers],
	AVG(AVG(bmd.diff_total_BuyItems)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyItems],
	AVG(AVG(bmd.diff_total_ScannedQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_ScannedQuantity],
	AVG(AVG(bmd.diff_total_ScannedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_ScannedOffers],
	AVG(AVG(bmd.diff_total_SuggestedOfferQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_SuggestedOfferQuantity],
	AVG(AVG(bmd.diff_total_SuggestedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_SuggestedOffers],
	AVG(AVG(bmd.diff_total_BuyWait_Sec)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyWait_Sec]
FROM #BuyMetrics_TY bmt
	INNER JOIN #BuyMetrics_Diff bmd
		ON	bmt.BusinessDate = bmd.BusinessDate 
		AND bmt.LocationNo = bmd.LocationNo
		AND bmt.BuyType = bmd.BuyType
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
	AVG(bmt.count_BuyTransactions) [total_BuyTransactions],
	AVG(bmt.total_BuyOffers) [total_BuyOffers],
	AVG(bmt.total_BuyItems) [total_BuyItems],
	AVG(bmt.total_ScannedQuantity) [total_ScannedQuantity],
	AVG(bmt.total_ScannedOffers) [total_ScannedOffers],
	AVG(bmt.total_SuggestedOfferQuantity) [total_SuggestedOfferQuantity],
	AVG(bmt.total_SuggestedOfferAmount) [total_SuggestedOffers],
	AVG(bmt.total_BuyWait_Sec) [total_BuyWait_Sec],
	--Chain averages
	AVG(AVG(bmt.count_BuyTransactions)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyTransactions],
	AVG(AVG(bmt.total_BuyOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyOffers],
	AVG(AVG(bmt.total_BuyItems)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyItems],
	AVG(AVG(bmt.total_ScannedQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedQuantity],
	AVG(AVG(bmt.total_ScannedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedOffers],
	AVG(AVG(bmt.total_SuggestedOfferQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferQuantity],
	AVG(AVG(bmt.total_SuggestedOfferAmount)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOffers],
	AVG(AVG(bmt.total_BuyWait_Sec)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyWait_Sec],
	--Chain average differences from last year
	AVG(AVG(bmd.diff_count_BuyTransactions)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyTransactions],
	AVG(AVG(bmd.diff_total_BuyOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyOffers],
	AVG(AVG(bmd.diff_total_BuyItems)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyItems],
	AVG(AVG(bmd.diff_total_ScannedQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_ScannedQuantity],
	AVG(AVG(bmd.diff_total_ScannedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_ScannedOffers],
	AVG(AVG(bmd.diff_total_SuggestedOfferQuantity)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_SuggestedOfferQuantity],
	AVG(AVG(bmd.diff_total_SuggestedOffers)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_SuggestedOffers],
	AVG(AVG(bmd.diff_total_BuyWait_Sec)) OVER (ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyWait_Sec]
FROM #BuyMetrics_TY bmt
	INNER JOIN #BuyMetrics_Diff bmd
		ON	bmt.BusinessDate = bmd.BusinessDate 
		AND bmt.LocationNo = bmd.LocationNo
		AND bmt.BuyType = bmd.BuyType
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
	bmt.count_BuyTransactions [total_BuyTransactions],
	bmt.total_BuyOffers,
	bmt.total_BuyItems,
	bmt.total_ScannedQuantity,
	bmt.total_ScannedOffers,
	bmt.total_SuggestedOfferQuantity,
	bmt.total_SuggestedOfferAmount,
	bmt.total_BuyWait_Sec,
	--Location averages
	AVG(bmt.count_BuyTransactions) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyTransactions],
	AVG(bmt.total_BuyOffers) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyOffers],
	AVG(bmt.total_BuyItems) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyItems],
	AVG(bmt.total_ScannedQuantity) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedQuantity],
	AVG(bmt.total_ScannedOffers) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_ScannedOffers],
	AVG(bmt.total_SuggestedOfferQuantity) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOfferQuantity],
	AVG(bmt.total_SuggestedOfferAmount) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_SuggestedOffers],
	AVG(bmt.total_BuyWait_Sec) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [rollavg_BuyWait_Sec],
	--Location average differences from last year
	AVG(bmd.diff_count_BuyTransactions) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyTransactions],
	AVG(bmd.diff_total_BuyOffers) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyOffers],
	AVG(bmd.diff_total_BuyItems) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyItems],
	AVG(bmd.diff_total_ScannedQuantity) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_ScannedQuantity],
	AVG(bmd.diff_total_ScannedOffers) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_ScannedOffers],
	AVG(bmd.diff_total_SuggestedOfferQuantity) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_SuggestedOfferQuantity],
	AVG(bmd.diff_total_SuggestedOffers) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_SuggestedOffers],
	AVG(bmd.diff_total_BuyWait_Sec) OVER (PARTITION BY bmt.LocationNo, bmt.BuyType ORDER BY bmt.BusinessDate ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) [diff_avg_BuyWait_Sec]
FROM #BuyMetrics_TY bmt
	INNER JOIN #BuyMetrics_Diff bmd
		ON	bmt.BusinessDate = bmd.BusinessDate 
		AND bmt.LocationNo = bmd.LocationNo
		AND bmt.BuyType = bmd.BuyType
ORDER BY LocationNo, BuyType, BusinessDate

DROP TABLE #BuyHeaderMetrics
DROP TABLE #BuyMetrics_Base
DROP TABLE #BuyMetrics_LY
DROP TABLE #BuyMetrics_TY
DROP TABLE #BuyMetrics_Diff

END
GO

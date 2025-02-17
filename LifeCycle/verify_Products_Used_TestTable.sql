/****** Script for SelectTopNRows command from SSMS  ******/
DECLARE @StartDate DATE = '7/1/2018'
DECLARE @EndDate DATE = '8/1/2018'



SELECT 
	spu.ItemCode,
	spi.Active [active_current],
	spu.Active [active_recomped],
	s.OrderDate,
	t.TransferType,
	t.TransferCompleteDate
INTO #ActiveStatusChanges
FROM Sandbox..Products_Used spu
	INNER JOIN ReportsData..SipsProductInventory spi
		ON spu.ItemCode = spi.ItemCode
	LEFT OUTER JOIN Base_Analytics_Cashew..Sales s
		ON spu.ItemCode = s.SipsItemCode
	LEFT OUTER JOIN Base_Analytics_Cashew..Transfers t
		ON spu.ItemCode = t.SipsItemCode	
WHERE spu.Active <> spi.Active
	AND t.TransferCompleteDate < '8/1/2018'


SELECT *
FROM #ActiveStatusChanges
--WHERE active_recomped <> 'Y'
ORDER BY ItemCode

DROP TABLE #ActiveStatusChanges
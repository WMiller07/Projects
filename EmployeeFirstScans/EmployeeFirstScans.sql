DECLARE @StartDate DATE = '1/1/2018'
DECLARE @EndDate DATE = '2/1/2020'

SELECT 
	fss.first_LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, fss.first_ScanDate), 0) [BusinessMonth],
	fss.first_ScannedBy,
	--ss.Subject [Section],
	--ss.SubjectKey,
	--fss.first_ShelfProxyID,
	COUNT(fss.ItemCode) [count_ItemsShelved],
	COUNT(ssh.SipsItemCode) [count_ItemsSold],
	--CAST(COUNT(ssh.SipsItemCode) AS FLOAT) / CAST(COUNT(fss.ItemCode) AS FLOAT) [pct_SellThrough],
	SUM(ssh.RegisterPrice) [total_ItemSalesAmt]
	--SUM(ssh.RegisterPrice)/ CAST(COUNT(fss.ItemCode) AS FLOAT) [avg_SalesPerShelvedItem],
	--SUM(ssh.RegisterPrice)/ CAST(COUNT(ssh.RegisterPrice) AS FLOAT) [avg_SalesPerSoldItem]
--INTO Sandbox..RDA_EmployeeFirstScans
FROM MathLab..FirstScans_Sips fss
	--INNER JOIN MathLab..NRF_Calendar nrf
	--	ON nrf.Store_StartOfWeek <= fss.first_ScanDate
	--	AND nrf.Store_EndOfWeek >= fss.first_ScanDate
	LEFT OUTER JOIN ReportsData..SipsSalesHistory ssh
		ON fss.ItemCode = ssh.SipsItemCode
	INNER JOIN ReportsData..SubjectSummary ss
		ON fss.first_SubjectKey = ss.SubjectKey
WHERE fss.first_ScanDate >= @StartDate
	AND fss.first_ScanDate < @EndDate
	--AND fss.first_LocationNo = @LocationNo
	--AND ss.Subject <> 'Backroom'
GROUP BY 
	fss.first_LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, fss.first_ScanDate), 0),
	fss.first_ScannedBy
	--ss.[Subject],
	--ss.SubjectKey,
	--fss.first_ShelfProxyID
ORDER BY 
	fss.first_LocationNo,
	DATEADD(MONTH, DATEDIFF(MONTH, 0, fss.first_ScanDate), 0),
	fss.first_ScannedBy,
	count_ItemsShelved DESC
	--Section,
	--fss.first_ShelfProxyID

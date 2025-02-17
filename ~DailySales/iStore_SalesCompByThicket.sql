DECLARE @Start_NRFWeek INT = 1
DECLARE @Start_NRFYear INT = 2018
DECLARE @EndDate DATE = GETDATE()



SELECT 
	nrf.Store_Date [BusinessDate],
	nrf.NRF_Year,
	nrf.NRF_Week,
	nrf.NRF_Day,
	(CASE 
		WHEN GROUPING(li.InstanceName) = 1
		 THEN 'Total'
		 ELSE li.InstanceName
		 END) [ThicketName],
	COUNT(om.ISIS_OrderID) [totalItems],
	SUM(om.MarketPrice) [totalSales], 
	SUM(om.MarketShippingFee) [totalShippingFee],
	SUM(om.MarketPrice + om.MarketShippingFee) [totalSalesShipping]
INTO #OnlineSales
FROM ISIS.dbo.Order_Monsoon om
	INNER JOIN MathLab.dbo.NRF_Daily nrf
		ON DATEADD(DAY, DATEDIFF(DAY, 0, om.ShipDate), 0) = nrf.Store_Date
	--INNER JOIN MathLab.dbo.NRF_Daily nrf_ly
	--	ON nrf_ty.NRF_Day = nrf_ly.NRF_Day
	--	AND (nrf_ty.NRF_Year - 1) = nrf_ly.NRF_Year
	INNER JOIN ISIS.dbo.App_ListingInstances li
		ON om.ListingInstanceID = li.ListingInstanceID
WHERE
	nrf.NRF_Day >= 1
	AND nrf.NRF_Week >= @Start_NRFWeek
	AND nrf.NRF_Year >= @Start_NRFYear
	AND nrf.Store_Date < @EndDate
GROUP BY 
	nrf.Store_Date,
	nrf.NRF_Year,
	nrf.NRF_Week,
	nrf.NRF_Day, 
	ROLLUP(li.InstanceName)

SELECT 
	osty.BusinessDate,
	osly.BusinessDate [CompDate],
	osty.ThicketName,
	osty.totalItems,
	osty.totalSales,
	osty.totalShippingFee,
	osty.totalSalesShipping,

	osty.totalItems - osly.totalItems [diff_totalItems],
	osty.totalSales - osly.totalSales [diff_totalSales],
	osty.totalShippingFee - osly.totalShippingFee [diff_totalShippingFee],
	osty.totalSalesShipping - osly.totalSalesShipping  [diff_totalSalesShipping],

	CAST(osty.totalItems AS FLOAT) / CAST(osly.totalItems AS FLOAT) - 1 [pctdiff_totalItems],
	CAST(osty.totalSales AS FLOAT) / CAST(osly.totalSales AS FLOAT) - 1 [pctdiff_totalSales],
	CAST(osty.totalShippingFee AS FLOAT) / CAST(osly.totalShippingFee AS FLOAT) - 1 [pctdiff_totalShippingFee],
	CAST(osty.totalSalesShipping AS FLOAT) / CAST(osly.totalSalesShipping AS FLOAT) - 1 [pctdiff_totalSalesShipping]
	
FROM #OnlineSales osty
	INNER JOIN #OnlineSales osly
		ON (osty.NRF_Year - 1) = osly.NRF_Year
		AND osty.NRF_Day = osly.NRF_Day
		AND osty.ThicketName = osly.ThicketName
WHERE osty.NRF_Year >= 2020
ORDER BY BusinessDate DESC, ThicketName

DROP TABLE #OnlineSales


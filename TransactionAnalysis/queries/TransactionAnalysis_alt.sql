DECLARE @StartDate DATE = '1/1/2019'
DECLARE @EndDate DATE = '2/1/2019'

SELECT
	slm.LocationNo,
	shh.LocationID,
	shh.SalesXactionID,
	shh.EndDate,
	ISNULL(pm.ItemCode, spi.ItemCode) [ItemCode],
	pm.ItemCode [DipsItemCode],
	spi.ItemCode [SipsItemCode],
	bi.ItemCode [BaseItemCode],
	spi.SipsID,
	sih.Quantity [QtySold],
	sih.ExtendedAmt [Sales],
	sih.DiscountAmt [Discount],
	shh.CouponCode,
	ISNULL(pcmu.Class, pcmd.Class) [Class],
	ISNULL(pcmu.FPSection, pcmd.FPSection) [FPSection],
	LTRIM(RTRIM(ISNULL(pm.ProductType, spi.ProductType))) [ProductType]
INTO #ItemSales
FROM HPB_SALES..SHH2019 shh
	INNER JOIN HPB_SALES..SIH2019 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationId
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro/base items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro/base item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON pm.ItemCode = bi.ItemCode
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi			
		ON	LEFT(sih.ItemCode, 1) <> 0							--SIPS items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables ARE NOT stored in the same format as the inventory tables, necessitating conversion.
	LEFT OUTER JOIN ReportsData..SipsProductMaster spm
		ON spi.SipsID = spm.SipsID
	LEFT OUTER JOIN ReportsData..SubjectSummary ss
		ON spm.SubjectKey = ss.SubjectKey
	LEFT OUTER JOIN MathLab..ProductClassificationMaster pcmu
		ON spm.ProductType = pcmu.ProductType
		AND ss.SubjectKey = pcmu.SubjectKey
	LEFT OUTER JOIN MathLab..ProductClassificationMaster pcmd
		ON pm.ProductType = pcmd.ProductType
		AND pm.SectionCode = pcmd.SectionCode
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'							
	AND shh.EndDate < @EndDate
UNION ALL
SELECT
	slm.LocationNo,
	shh.LocationID,
	shh.SalesXactionID,
	shh.EndDate,
	ISNULL(pm.ItemCode, spi.ItemCode) [ItemCode],
	pm.ItemCode [DipsItemCode],
	spi.ItemCode [SipsItemCode],
	bi.ItemCode [BaseItemCode],
	spi.SipsID,
	sih.Quantity [QtySold],
	sih.ExtendedAmt [Sales],
	sih.DiscountAmt [Discount],
	shh.CouponCode,
	ISNULL(pcmu.Class, pcmd.Class) [Class],
	ISNULL(pcmu.FPSection, pcmd.FPSection) [FPSection],
	LTRIM(RTRIM(ISNULL(pm.ProductType, spi.ProductType))) [ProductType]
FROM HPB_SALES..SHH2018 shh
	INNER JOIN HPB_SALES..SIH2018 sih
		ON shh.SalesXactionID = sih.SalesXactionId
		AND shh.LocationID = sih.LocationID
		AND shh.[Status] = 'A'									--Accepted sales only (exclude voids)
	INNER JOIN ReportsView..StoreLocationMaster slm
		ON shh.LocationID = slm.LocationId
	LEFT OUTER JOIN ReportsData..ProductMaster pm
		ON  LEFT(sih.ItemCode, 1) = 0								--Distro/base items start with 0 in the sales tables
		AND sih.ItemCode = pm.ItemCode							--Distro/base item codes in the sales tables ARE stored in the same format as the inventory tables.
	LEFT OUTER JOIN ReportsData..BaseInventory bi
		ON pm.ItemCode = bi.ItemCode
	LEFT OUTER JOIN ReportsData..SipsProductInventory spi			
		ON	LEFT(sih.ItemCode, 1) <> 0							--SIPS items start non-zero values in the sales tables
		AND CAST(RIGHT(sih.ItemCode, 9) AS INT) = spi.ItemCode	--Item codes in the sales tables ARE NOT stored in the same format as the inventory tables, necessitating conversion.
	LEFT OUTER JOIN ReportsData..SipsProductMaster spm
		ON spi.SipsID = spm.SipsID
	LEFT OUTER JOIN ReportsData..SubjectSummary ss
		ON spm.SubjectKey = ss.SubjectKey
	LEFT OUTER JOIN MathLab..ProductClassificationMaster pcmu
		ON spm.ProductType = pcmu.ProductType
		AND ss.SubjectKey = pcmu.SubjectKey
	LEFT OUTER JOIN MathLab..ProductClassificationMaster pcmd
		ON pm.ProductType = pcmd.ProductType
		AND pm.SectionCode = pcmd.SectionCode
WHERE sih.ItemCode NOT LIKE '%[^0-9]%'							--Some non-numeric item codes exist in our sales tables. Failing to exclude these results in overflow errors.
	AND shh.EndDate >= @StartDate


SELECT *
FROM #ItemSales



USE [Buy_Online_Analytics]

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		William Miller
-- Create date: 3/26/20
-- Description:	Gets latest sales rankings per CatalogID using ISIS.dbo.stats_CompiledRankings
-- =============================================
CREATE PROCEDURE dbo.ru_CatalogCompiledRankings
	-- Add the parameters for the stored procedure here

AS
BEGIN

	SET NOCOUNT ON;

	--MAX is used in the below to eliminate a few thousand duplicated ISBN/UPC combinations


	INSERT INTO Buy_Online_Analytics.dbo.CatalogCompiledRankings
	SELECT 
		c.catalogId,
		MAX(r.ISBN) [ISBN],
		MAX(r.UPC) [UPC],
		MAX(r.AmazonSalesRank) [AmazonSalesRank],
		MAX(r.HPBStoreSalesRank) [HPBStoreSalesRank],
		MAX(r.HPBOnlineMarketSalesRank) [HPBOnlineMarketSalesRank],
		MAX(r.NYTBestsellerRank) [NYTBestsellerRank], 
		MAX(r.LastUpdated) [LastUpdated],
		MAX(r.HPBStoreSalesCount) [HPBStoreSalesCount],
		MAX(r.HPBOnlineMarketSalesCount) [HPBOnlineMarketSalesCount],
		CURRENT_TIMESTAMP [InsertDate]
	FROM [ISIS].[dbo].[stats_CompiledRankings] r
		INNER JOIN Base_Analytics_Cashew.dbo.IdentifierToCatalogIdMapping c
			ON ISNULL(c.isbn, c.upc) = ISNULL(r.ISBN, r.UPC) 
	WHERE c.CatalogID IS NOT NULL
		AND r.AmazonSalesRank > 0 --Sales rank of 0 appears to indicate a data retrieval failure
	GROUP BY c.CatalogID
	ORDER BY c.CatalogID
END
GO

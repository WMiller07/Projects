USE [Buy_Online_Analytics]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE TABLE [dbo].[CatalogCompiledRankings](
	[CatalogID] [bigint] NOT NULL,
	[ISBN] [varchar](13) NULL,
	[UPC] [varchar](13) NULL,
	[AmazonSalesRank] [int] NULL,
	[HPBStoreSalesRank] [int] NULL,
	[HPBOnlineMarketSalesRank] [int] NULL,
	[NYTBestsellerRank] [int] NULL,
	[LastUpdated] [datetime2](2) NULL,
	[HPBStoreSalesCount] [int] NULL,
	[HPBOnlineMarketSalesCount] [int] NULL,
	[InsertDate] [date] NULL,
 CONSTRAINT [PK_CatalogCompiledRankings] PRIMARY KEY CLUSTERED 
(
	[CatalogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO






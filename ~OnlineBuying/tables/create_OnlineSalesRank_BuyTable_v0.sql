USE [Buy_Online_Analytics]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[OnlineSalesRank_BuyTable_V0_R0](
	[BuyGradeID] [int] NOT NULL,
	[MarketName] [varchar](50) NOT NULL,
	[CatalogBinding] [varchar](50) NOT NULL,
	[BuyGradeName] [varchar](5) NULL,
	[OnlineSalesRankRangeFrom] [decimal](18, 4) NULL,
	[OnlineSalesRankRangeTo] [decimal](18, 4) NULL,
	[BuyOfferPct] [decimal](18, 4) NULL
) ON [PRIMARY]
GO






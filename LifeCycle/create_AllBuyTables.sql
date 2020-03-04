USE [Sandbox]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BuyAlgorithm_AggregateData_Chain_181001](
	[CatalogID] [bigint] NOT NULL,
	[Total_Item_Count] [int] NULL,
	[Total_Accumulated_Days_With_Trash_Penalty] [decimal](18, 2) NULL,
	[Days_Total_FromCreate] [decimal](18, 2) NULL,
	[Days_Total_Scanned] [decimal](18, 2) NULL,
	[Days_Total_Salable_Priced] [decimal](18, 2) NULL,
	[Days_Total_Salable_Scanned] [decimal](18, 2) NULL,
	[Days_Total_Salable_Online] [decimal](18, 2) NULL,
	[Total_Transfers] [int] NULL,
	[Total_Trash_Donate] [int] NULL,
	[Total_Sold] [int] NULL,
	[Total_Available] [int] NULL,
	[Total_Scan_Count] [int] NULL,
	[Avg_Price] [money] NULL,
	[Geo_Avg_Price] [money] NULL,
	[Avg_Sale_Price] [money] NULL,
	[Geo_Avg_Sale_Price] [money] NULL,
	[Insert_Date] [smalldatetime] NULL,
	[Avg_Days_Priced_To_Sold] [decimal](18, 2) NULL
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[BuyAlgorithm_AggregateData_Location_181001](
	[LocationNo] [char](5) NULL,
	[LocationID] [char](10) NULL,
	[CatalogID] [bigint] NULL,
	[Total_Item_Count] [int] NULL,
	[Total_Accumulated_Days_With_Trash_Penalty] [decimal](18, 2) NULL,
	[Days_Total_FromCreate] [decimal](18, 2) NULL,
	[Days_Total_Scanned] [decimal](18, 2) NULL,
	[Days_Total_Salable_Priced] [decimal](18, 2) NULL,
	[Days_Total_Salable_Scanned] [decimal](18, 2) NULL,
	[Days_Total_Salable_Online] [decimal](18, 2) NULL,
	[Total_Transfers] [int] NULL,
	[Total_Trash_Donate] [int] NULL,
	[Total_Sold] [int] NULL,
	[Total_Available] [int] NULL,
	[Total_Scan_Count] [int] NULL,
	[Avg_Price] [money] NULL,
	[Geo_Avg_Price] [money] NULL,
	[Avg_Sale_Price] [money] NULL,
	[Geo_Avg_Sale_Price] [money] NULL,
	[Insert_Date] [smalldatetime] NULL,
	[Avg_Days_Priced_To_Sold] [decimal](18, 2) NULL
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[BuyAlgorithm_V1_R4_181001](
	[OfferID] [bigint] IDENTITY(1,1) NOT NULL,
	[Version] [smallint] NOT NULL,
	[Release] [smallint] NOT NULL,
	[CatalogID] [bigint] NOT NULL,
	[Chain_SuggestedOffer] [decimal](18, 2) NOT NULL,
	[LocationNo] [char](5) NULL,
	[LocationID] [char](10) NULL,
	[Location_SuggestedOffer] [decimal](18, 2) NULL,
	[Date_Generated] [datetime2](3) NOT NULL,
	[InsertDate] [datetime2](3) NOT NULL,
	[ListPrice] [money] NOT NULL,
	[Chain_Avg_Sale_Price] [money] NULL,
	[Chain_Buy_Offer_Pct] [decimal](18, 4) NULL,
	[Location_Avg_Sale_Price] [money] NULL,
	[Location_Buy_Offer_Pct] [decimal](18, 4) NULL,
 CONSTRAINT [PK_BuyAlgorithm_V1_R4_181001] PRIMARY KEY CLUSTERED 
(
	[OfferID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[BuyAlgorithm_V1_R4_181001] ADD  CONSTRAINT [DF_BuyAlgorithm_V1_R4_181001_InsertDate]  DEFAULT (getdate()) FOR [InsertDate]
GO

ALTER TABLE [dbo].[BuyAlgorithm_V1_R4_181001] ADD  CONSTRAINT [DF_BuyAlgorithm_V1_R4_181001_ListPrice]  DEFAULT ((0)) FOR [ListPrice]
GO

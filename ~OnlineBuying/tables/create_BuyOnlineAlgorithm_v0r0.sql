USE [Buy_Online_Analytics]
GO

/****** Object:  Table [dbo].[BuyAlgorithm_V1_R42]    Script Date: 3/27/2020 3:28:29 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BuyOnlineAlgorithm_V0_R0](
	[OfferID] [bigint] IDENTITY(1,1) NOT NULL,
	[Version] [smallint] NOT NULL,
	[Release] [decimal](9, 2) NOT NULL,
	[CatalogID] [bigint] NOT NULL,
	[AmazonMarket_SuggestedOffer] [decimal](18, 2) NULL,
	[AmazonMarket_Avg_Sale_Price] [money] NULL,
	[AmazonMarket_Buy_Offer_Pct] [decimal](18, 4) NULL,
	[Date_Generated] [datetime2](3) NOT NULL,
	[InsertDate] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_BuyOnlineAlgorithm_V0_R0] PRIMARY KEY CLUSTERED 
(
	[OfferID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[BuyOnlineAlgorithm_V0_R0] ADD  CONSTRAINT [DF_BuyOnlineAlgorithm_V0_R0_InsertDate]  DEFAULT (getdate()) FOR [InsertDate]
GO




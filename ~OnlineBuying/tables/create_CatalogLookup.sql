USE [Buy_Online_Analytics]
GO

/****** Object:  Table [dbo].[Catalog_Lookup]    Script Date: 3/27/2020 3:55:17 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Catalog_Lookup](
	[Identifier] [varchar](20) NOT NULL,
	[CatalogID] [bigint] NULL,
 CONSTRAINT [PK_Catalog_Lookup] PRIMARY KEY CLUSTERED 
(
	[Identifier] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO



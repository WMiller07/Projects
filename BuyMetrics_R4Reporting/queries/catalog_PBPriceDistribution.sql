SELECT 
	CAST(COUNT(
		CASE
		WHEN t.listPrice <= 5.00
			THEN t.CatalogID
		END) AS FLOAT)/CAST(COUNT(t.listPrice) AS FLOAT) [list_Under5],
	CAST(COUNT(
		CASE
		WHEN t.listPrice > 5.00 AND t.listPrice <= 10.00
			THEN t.CatalogID
		END) AS FLOAT)/CAST(COUNT(t.listPrice) AS FLOAT) [list_5to10],
	CAST(COUNT(
		CASE
		WHEN t.listPrice > 10.00 AND t.listPrice <= 15.00
			THEN t.CatalogID
		END) AS FLOAT)/CAST(COUNT(t.listPrice) AS FLOAT) [list_10to15],
	CAST(COUNT(
		CASE
		WHEN t.listPrice > 15.00 
			THEN t.CatalogID
		END) AS FLOAT)/CAST(COUNT(t.listPrice) AS FLOAT) [list_Over15]
FROM Catalog..titles t
WHERE t.binding = 'Mass Market Paperback'

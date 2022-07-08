-- SERVER: CACALQDBPRO002\NLPDEVSQL2019

USE NLPRegression_Actus7


-- Enter the DocID you want to delete
DECLARE @DocID bigint = 

-- Run this stored proc
EXEC spNLPDeleteDocumentRange @DocID, @DocID



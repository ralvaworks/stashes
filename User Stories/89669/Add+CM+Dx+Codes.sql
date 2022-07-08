-- SERVER: CACALQDBENT001

USE ACTUS_NLP_ICD10

-- This is the valid set of ICD10CM codes.  You need to add the three new codes to this table.
SELECT * FROM LUICD10DiagnosisCodes WHERE TerminationDate IS NULL AND Invalid = 0
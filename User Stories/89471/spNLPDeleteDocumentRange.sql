USE [NLPRegression_Actus7]
GO

/****** Object:  StoredProcedure [dbo].[spNLPDeleteDocumentRange]    Script Date: 1/25/2022 2:44:14 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



/***********************************************************************************************************

Name:    spNLPDeleteDocumentRange
Author:  Carol Donahue
Date:    4/21/2011
Desc:    Delete document range out from the database

Instructions:
Whatever stored procedure or script that calls spActusDeleteDocument must fill #Actus_DocList
with DocIDs that will be deleted

Exec spNLPDeleteDocumentRange 1, 1, 1, 1

Parameters:
@Script SMALLINT = 1 - Normal, 2 - spArchivedDeleteArchiveDocs
@iteration INT = # of Docs for each iteration
@DeleteZipInfo SMALLINT = 0 - DO NOT delete out of AlifeZipInfo, 1 - Delete out of AlifeZipInfo
@DisplayMSG SMALLINT = 0 - DO NOT Display info message each iteration, 1 - Display info message each iteration

Change History:
*  Date              Author		TFS		Comments  
  02/09/2016          mwp                Updates for ALifeDocModifiers related to DC Upgrade to 8.0.17.4
  04/08/2016          cad				 Borrowed heavily from ActusDeleteDocumentRange.  Modified to add logging
***********************************************************************************************************/
CREATE PROCEDURE [dbo].[spNLPDeleteDocumentRange] @MinID BIGINT, @MAXID BIGINT, @Script SMALLINT=1, @iteration INT = 100, 
               @DeleteAudit SMALLINT = 0, @DisplayMSG SMALLINT = 1
WITH EXECUTE AS CALLER
AS


SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

--*****************************************************
--DECLARE @MinID int = 657194599
--DECLARE @MaxID int = 657202769

--DECLARE @Script SMALLINT, @iteration INT, @DeleteAudit SMALLINT, @DisplayMSG SMALLINT

--SET @iteration = 1000
--SET @DeleteAudit = 1
--SET @DisplayMSG = 1
--SET @Script = 1
/***************************************************************/

-- This table only is passed in from other SP
IF OBJECT_ID('tempdb..#Actus_DocList','U') IS NULL
   CREATE TABLE #Actus_DocList (DocID INT PRIMARY KEY)
ELSE
   TRUNCATE TABLE #Actus_DocList

INSERT INTO #Actus_DocList
SELECT DocID
FROM dbo.[AlifeDocMaster] WITH (NOLOCK)
WHERE [DocID] BETWEEN @MinID AND @MaxID
--******************************************************/
--ACTSQLPROD\PRODSQL now CACProSQL01\CACProSQL1 or CACProSQL02\CACProSQL2
IF @@SERVERNAME IN ('CACProSQL01\CACProSQL1', 'CACProSQL02\CACProSQL2', 'CACSQL09\CACPROSQL3', 'CACPROSQL10\CACPROSQL4') AND DB_NAME() = 'Actus2DB' AND @Script <> 2 AND user_Name() <> 'dbo'
BEGIN
	RAISERROR('Script %d is not allowed to run on this environment',16,1,@script) with nowait
	RETURN
END


IF OBJECT_ID('tempdb..#Actus_DocIDs2Delete_Loop','U') IS NULL
   CREATE TABLE #Actus_DocIDs2Delete_Loop (DocID INT PRIMARY KEY)

IF OBJECT_ID('tempdb..#Actus_GSPIDList','U') IS NULL
   CREATE TABLE #Actus_GSPIDList (GSPID INT PRIMARY KEY)

DECLARE @Total INT
DECLARE @RTotal INT
DECLARE @RowCount INT
DECLARE @MaxDocID INT
DECLARE @MINDocID INT
DECLARE @ActionDate DATETIME
DECLARE @StartDate DATETIME
DECLARE @EndDate DATETIME
DECLARE @ErrMsg VARCHAR(2048)
DECLARE @ScriptName VARCHAR(100)
DECLARE @NegativeStatus INT

SET @RTotal = 0
SET @RowCount = 0
SET @MaxDocID = 0
SET @MINDocID = 0
SET @ActionDate = GETDATE()

SET @Script = ISNULL(@Script,0)

IF @Script = 1
BEGIN
   SET @ScriptName = 'Normal'
   SET @NegativeStatus = -28
END
ELSE IF @Script = 2
BEGIN
   SET @ScriptName		= 'spArchivedDeleteArchiveDocs_II'
   SET @NegativeStatus	= -25
   SET @iteration		= 1
END
ELSE
BEGIN
   RAISERROR('Script value %d is not in configuration',16,1,@Script)
	RETURN
END
DECLARE @MinNumber VARCHAR(1000) 
SET @MinNumber=CAST(@MinID AS VARCHAR(100))
DECLARE @MaxNumber VARCHAR(1000) 
SET @MaxNumber=CAST(@MAXID AS VARCHAR(100))
SELECT @Total = COUNT(*) FROM #Actus_DocList
RAISERROR('Total number of documents in range (%s - %s) to delete:   %i ',10,1,@MinNumber,@MaxNumber,@Total) with nowait


WHILE 1 = 1
BEGIN -- While Loop Start
   BEGIN TRY

      TRUNCATE TABLE #Actus_GSPIDList
      TRUNCATE TABLE #Actus_DocIDs2Delete_Loop

      INSERT INTO #Actus_DocIDs2Delete_Loop (DocID)
      SELECT TOP(@iteration) DocID FROM #Actus_DocList ORDER BY [DocID]

      SELECT @RowCount = @@ROWCOUNT
      IF @RowCount = 0 BREAK
      SELECT @MinDocID = MIN(DocID), @MaxDocID = MAX(DocID) FROM #Actus_DocIDs2Delete_Loop

      SET @StartDate = GETDATE()
      UPDATE dbo.AlifeDocMaster
      SET [Status] = @NegativeStatus
      FROM dbo.AlifeDocMaster a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocLock FROM dbo.AlifeDocLock a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocAttributes FROM dbo.AlifeDocAttributes a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.ALifeDocCustomFlags FROM dbo.ALifeDocCustomFlags a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocDCProcessing FROM dbo.AlifeDocDCProcessing a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocOutcomeValues FROM dbo.AlifeDocOutcomeValues a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocImageConnectionDetailsData FROM dbo.AlifeDocImageConnectionDetailsData a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID



      DELETE dbo.AlifeDocOcrPageStatistics FROM dbo.AlifeDocOcrPageStatistics a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocCustomRuleLog FROM dbo.AlifeDocCustomRuleLog a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocOcrConfigLog FROM dbo.AlifeDocOcrConfigLog a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID


      DELETE dbo.AlifeDocImageConnectionData FROM dbo.AlifeDocImageConnectionData a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocEditHistoryChanges FROM dbo.AlifeDocEditHistoryChanges a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocEditHistory FROM dbo.AlifeDocEditHistory a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

	  DELETE dbo.AlifeDocRISCPTMap FROM dbo.AlifeDocRISCPTMap a WITH(NOLOCK)	  
	  INNER JOIN AlifeDocRISReconciliation b WITH(NOLOCK) on a.RISCPTCodeID=b.RISCPTCodeID 
	  INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = b.DocID   
	  
	  DELETE dbo.AlifeDocRISCPT10Map FROM dbo.AlifeDocRISCPT10Map a WITH(NOLOCK)	  
	  INNER JOIN AlifeDocRISReconciliation b WITH(NOLOCK) on a.RISCPTCodeID=b.RISCPTCodeID 
	  INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = b.DocID   

	  DELETE [dbo].[AlifeDocRISReconciliationICD] FROM [dbo].[AlifeDocRISReconciliationICD] a WITH(NOLOCK)
	  INNER JOIN AlifeDocRISReconciliation b WITH(NOLOCK) on a.RISCPTCodeID=b.RISCPTCodeID 
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocRISReconciliation FROM dbo.AlifeDocRISReconciliation a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

	  -- icd10 table
      DELETE a FROM dbo.AlifeDocRuleLog rl WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = rl.DocID
	  INNER JOIN  dbo.[AlifeDocRuleActionsLog] a WITH(NOLOCK) on rl.DocRuleID = a.DocRuleID 

      DELETE dbo.AlifeDocRuleLog FROM dbo.AlifeDocRuleLog a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocStatusHist FROM dbo.AlifeDocStatusHist a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocUserWorkFlow FROM dbo.AlifeDocUserWorkFlow a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocDGO FROM dbo.AlifeDocDGO a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocHilite FROM dbo.AlifeDocHilite a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocIntCPTGraphMap FROM dbo.AlifeDocCpt cpt WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = cpt.DocID
      INNER JOIN dbo.AlifeDocIntCPTGraphMap a WITH(NOLOCK) ON a.CPTCodeID = cpt.CPTCodeID

      DELETE dbo.AlifeDocCodeMap FROM dbo.AlifeDocCpt cpt WITH(NOLOCK)
      INNER JOIN dbo.AlifeDocCodeMap a WITH(NOLOCK) ON a.CPTCodeID = cpt.CPTCodeID
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = cpt.DocID

      DELETE dbo.AlifeDocICD10CodeMap FROM dbo.AlifeDocCpt10 cpt WITH(NOLOCK)
      INNER JOIN dbo.AlifeDocICD10CodeMap a WITH(NOLOCK) ON a.CPTCodeID = cpt.CPTCodeID
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = cpt.DocID

	  -- Sprint 24 tables AlifeDocCPTFac, AlifeDocICD9Proc, AlifeDocICDFac, & AlifeDocFacCodeMap
      DELETE dbo.AlifeDocFacCodeMap FROM dbo.AlifeDocCPTFac b WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = b.DocID
	  INNER JOIN dbo.AlifeDocICD9Proc c WITH (NOLOCK) ON tmp.DocID = c.DocID
	  INNER JOIN dbo.AlifeDocFacCodeMap a WITH(NOLOCK) ON a.[CPTFacCodeID] = b.[CPTFacCodeID]  AND  a.[ICD9CodeID] = c.[ICD9CodeID]

      DELETE dbo.AlifeDocCPTFac FROM dbo.AlifeDocCPTFac a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

	  DELETE dbo.AlifeDocICDFac FROM dbo.AlifeDocICDFac a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

	   DELETE dbo.AlifeDocICD9Proc FROM dbo.AlifeDocICD9Proc a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID
	  -- Sprint 24


-- IDC10 tables

      DELETE a FROM dbo.[AlifeDocTimeoutStatus] a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE a FROM dbo.[AlifeDocTimeoutStatusHistory] a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE a FROM dbo.[ALifeDocTranscriptions] a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE a FROM dbo.[ALifeDocFilterTags] a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE a FROM dbo.[ALifeDocGroupMap] a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE a FROM dbo.[AlifeDocClientCustom] a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE a FROM dbo.[AlifeDocEchoData] a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE a FROM dbo.[AlifeDocDCProcessingDetails] a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE a FROM dbo.[ActusDCError] a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID
	  
-- ICD10 tables End



      DELETE dbo.AlifeDocICD FROM dbo.AlifeDocICD a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocIcd10 FROM dbo.AlifeDocIcd10 a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocModifiers FROM dbo.AlifeDocModifiers cddm WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = cddm.DocID

	  DELETE dbo.ALifeDocNLPCDIIndicatorElementTraces FROM dbo.ALifeDocNLPCDIIndicatorElementTraces idtr WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = idtr.DocID

	  DELETE dbo.ALifeDocNLPCDIIndicatorElements FROM dbo.ALifeDocNLPCDIIndicatorElements idel WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = idel.DocID

	  DELETE dbo.ALifeDocNLPCDIIndicators FROM dbo.ALifeDocNLPCDIIndicators id WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = id.DocID

	  DELETE dbo.ALifeDocNLPCDIScenarios FROM dbo.ALifeDocNLPCDIScenarios sn WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = sn.DocID

	  DELETE dbo.ALifeDocNLPCDIMarkers FROM dbo.ALifeDocNLPCDIMarkers mark WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = mark.DocID

      DELETE dbo.AlifeDocCPTComment FROM dbo.AlifeDocCPTComment cddm WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = cddm.DocID	  

	  DELETE dbo.AlifeDocComments FROM dbo.AlifeDocComments dcom WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = dcom.DocID

      DELETE dbo.AlifeDocCpt FROM dbo.AlifeDocCpt a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocCpt10 FROM dbo.AlifeDocCpt10 a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      INSERT INTO #Actus_GSPIDList
      SELECT a.GSPID FROM #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK)
      INNER JOIN dbo.AlifeDocGSP a WITH(NOLOCK) ON tmp.DocID = a.DocID
      UNION
      SELECT a.GSPID FROM #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK)
      INNER JOIN dbo.AlifeDocGSP a WITH(NOLOCK) ON tmp.DocID = a.GSPGroupID

      DELETE dbo.AlifeDocGSPHistory FROM #Actus_GSPIDList a WITH(NOLOCK)
      INNER JOIN dbo.AlifeDocGSPHistory b WITH(NOLOCK) ON a.GSPID = b.GSPID

      DELETE dbo.AlifeDocGSP FROM #Actus_GSPIDList a WITH(NOLOCK)
      INNER JOIN dbo.AlifeDocGSP b WITH(NOLOCK) ON a.GSPID = b.GSPID


      DELETE dbo.AlifeDocEM FROM dbo.AlifeDocEM a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocEMElements FROM dbo.AlifeDocEMElements a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID


         DELETE dbo.AlifeDocCodeListDetail FROM dbo.AlifeDocCodeListDetail a WITH(NOLOCK)
         INNER JOIN dbo.AlifeDocCodeList b WITH(NOLOCK) ON a.CodeListID = b.CodeListID
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = b.DocID

         DELETE dbo.AlifeDocCodeList FROM dbo.AlifeDocCodeList a WITH(NOLOCK)
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

         DELETE dbo.AlifeDocLCSegments FROM dbo.AlifeDocLCSegments a WITH(NOLOCK)
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

         DELETE dbo.AlifeDocLifeCodeData FROM dbo.AlifeDocLifeCodeData a WITH(NOLOCK)
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID


      DELETE dbo.ALifeDocFlagDetails FROM dbo.ALifeDocFlagDetails a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocDetail FROM dbo.AlifeDocDetail a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.ActusBEPrepData FROM dbo.ActusBEPrepData a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      
      DELETE dbo.ActusCSDocBatchMap FROM dbo.ActusCSDocBatchMap a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.ActusCSBatch FROM dbo.ActusCSBatch csb WITH(NOLOCK)
      INNER JOIN dbo.ActusCSDocBatchMap dbm WITH(NOLOCK) ON csb.BatchID = dbm.BatchID
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = dbm.DocID

      DELETE dbo.ActusCSDoc FROM dbo.ActusCSDoc a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      IF @DeleteAudit = 1
      BEGIN
         DELETE dbo.ActusAuditDocCodeMap FROM dbo.ActusAuditDocCodeMap a WITH(NOLOCK)
         INNER JOIN dbo.ActusAuditDocCPTCodes cpt WITH(NOLOCK) ON a.AuditCPTID = cpt.AuditCPTID
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = cpt.DocID

         DELETE dbo.ActusAuditDocCodeMap FROM dbo.ActusAuditDocCodeMap a WITH(NOLOCK)
         INNER JOIN dbo.ActusAuditDocICDCodes icd WITH(NOLOCK) ON a.AuditICDID = icd.AuditICDID
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = icd.DocID

         DELETE dbo.ActusAuditDocICDCodes FROM dbo.ActusAuditDocICDCodes a WITH(NOLOCK)
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

         DELETE dbo.ActusAuditDocCPTCodes FROM dbo.ActusAuditDocCPTCodes a WITH(NOLOCK)
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

         DELETE dbo.ActusAuditDocHilites FROM dbo.ActusAuditDocHilites a WITH(NOLOCK)
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

         DELETE dbo.ActusAuditDocEM FROM dbo.ActusAuditDocEM a WITH(NOLOCK)
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

         DELETE dbo.ActusAuditDocEM 
         FROM #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK)
         INNER JOIN dbo.ActusAuditResult ar WITH(NOLOCK) ON tmp.DocID = ar.DocID
         INNER JOIN dbo.ActusAuditDocEM a  ON ar.DocID = a.DocID and ar.AuditID = a.AuditID

         DELETE dbo.ActusAuditResult FROM dbo.ActusAuditResult a WITH(NOLOCK)
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

         DELETE dbo.ActusAuditBatchParams FROM dbo.ActusAuditBatchParams a WITH(NOLOCK)
         INNER JOIN dbo.ActusAuditBatch ab  WITH(NOLOCK) ON a.BatchParamsID = ab.BatchParamsID
         INNER JOIN dbo.ActusAuditResult ar WITH(NOLOCK) ON ab.AuditID = ar.AuditID
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = ar.DocID

         DELETE dbo.ActusAuditBatch FROM dbo.ActusAuditBatch a WITH(NOLOCK)
         INNER JOIN dbo.ActusAuditResult ar WITH(NOLOCK) ON a.AuditID = ar.AuditID
         INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = ar.DocID
      END

      DELETE dbo.ActusBELogDetailMap FROM dbo.ActusBELogDetailMap a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocDemoMap FROM dbo.AlifeDocDemoMap a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.ActusRecActionLog FROM dbo.ActusRecActionLog a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.ActusRecContention FROM dbo.ActusRecContention a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocAccessionNrs FROM dbo.AlifeDocAccessionNrs a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocAppLogMap FROM dbo.AlifeDocAppLogMap a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocChargeLogMap FROM dbo.AlifeDocChargeLogMap a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocExportLogMap FROM dbo.AlifeDocExportLogMap a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.AlifeDocMissedCharges FROM dbo.AlifeDocMissedCharges a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE dbo.CodeDirectChargePayments FROM dbo.CodeDirectChargePayments cdcp WITH(NOLOCK)
      INNER JOIN dbo.CodeDirectDocCharges cddc WITH(NOLOCK) ON cdcp.CodeID = cddc.CodeID
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = cddc.DocID

      DELETE dbo.CodeDirectDocCharges FROM dbo.CodeDirectDocCharges cddc WITH(NOLOCK)
      INNER JOIN dbo.CodeDirectDocMap cddm WITH(NOLOCK) ON cddc.DocID = cddm.DocID
      INNER JOIN dbo.CodeDirectDocMaster dm WITH(NOLOCK) ON cddc.DocID = dm.DocID AND cddm.DocID = dm.DocID
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = cddc.DocID

      DELETE dbo.CodeDirectDocMaster FROM dbo.CodeDirectDocMaster dm WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = dm.DocID

      DELETE dbo.CodeDirectDocMap FROM dbo.CodeDirectDocMap cddm WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = cddm.DocID

      DELETE dbo.AlifeDocMaster FROM dbo.AlifeDocMaster a WITH(NOLOCK)
      INNER JOIN #Actus_DocIDs2Delete_Loop tmp WITH(NOLOCK) ON tmp.DocID = a.DocID

      DELETE a
      FROM [#Actus_DocList] a
         INNER JOIN #Actus_DocIDs2Delete_Loop b ON a.[DocID]=b.DocID

      SET @EndDate = GETDATE()

      SELECT @RTotal = @RTotal + @RowCount

      IF @DisplayMSG = 1
      BEGIN
	     declare @EffectiveStartDateText varchar(30)
         set @EffectiveStartDateText = cast(@StartDate as varchar)
	     Raiserror('CLEANED %i out of %i document(s) StartTime= %s',10,1,@RTotal,@Total,@EffectiveStartDateText) with nowait         
	  END


      -- 12/19/2013 - ptf - Deletions in Preview were failing
	  -- Set the Date the Doc was delete from Production.
      IF @Script=2
	  BEGIN
		  UPDATE a
		  SET [DeletedDate] = GetDate()
		  FROM dbo.[ActusArchiveLog] a
			  INNER JOIN #Actus_DocIDs2Delete_Loop b  ON a.DocID = b.DocID
      END

   END TRY
   BEGIN CATCH
      SET @ErrMsg=ERROR_MESSAGE()

	  INSERT INTO dbo.ActusDeleteDocumentLog(ScriptName, DocumentCount, MINDocID, MAXDocID, ActionDate, Duration, InfoMessage)
	  SELECT @ScriptName, @RowCount, @MINDocID, @MaxDocID, GETDATE(), DATEDIFF(SECOND,@StartDate,GETDATE()), '@ErrMsg'

      RAISERROR ('Error deleting MinDocID = %d - MaxDocID = %d.  Error message - %s', 10, 1, @MinDocID, @MaxDocID, @ErrMsg) with nowait
   END CATCH

END -- While Loop End

IF @DisplayMSG = 1
BEGIN
   Raiserror('CLEANED %i out of %i document(s) ',10,1,@RTotal,@Total) with nowait   
END


IF OBJECT_ID('tempdb..#Actus_DocIDs2Delete_Loop','U') IS NOT NULL
   DROP TABLE #Actus_DocIDs2Delete_Loop
IF OBJECT_ID('tempdb..#Actus_GSPIDList','U') IS NOT NULL
   DROP TABLE #Actus_GSPIDList
GO



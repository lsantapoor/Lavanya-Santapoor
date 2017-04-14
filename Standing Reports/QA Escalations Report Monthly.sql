use reports
 
Declare @sDate as datetime,@xDate as datetime,@iDME as int
Declare @iHOSCount as int , @iHOS_step as int ,@iHOS as int, @iHOS_ID as int,@iHOS_SEQ_NO as int,@iHOSNAME as varchar(100)

set @sDate = DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - 1, 0)
set @xDate = CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(GETDATE())),GETDATE()),101)

print @sDate
Print @xDate

--drop table dbo.iHOS_list
IF OBJECT_ID('reports_bic.dbo.QAiHOS_list', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.QAiHOS_list; 

create table reports_bic.dbo.QAiHOS_list(
iHOS_SEQ_NO int,
iHOS_ID int,
iHOS_name varchar(100)
)

insert into reports_bic.dbo.QAiHOS_list values(1,87,'Amedisys')
insert into reports_bic.dbo.QAiHOS_list values(2,29,'Odyssey / Gentiva')
insert into reports_bic.dbo.QAiHOS_list values(3,10,'Evercare')
insert into reports_bic.dbo.QAiHOS_list values(4,12,'Alacare')
insert into reports_bic.dbo.QAiHOS_list values(5,86,'Vitas')
insert into reports_bic.dbo.QAiHOS_list values(6,299,'Tidewell Hospice')
insert into reports_bic.dbo.QAiHOS_list values(7,257,'Harbor Light Hospice')
insert into reports_bic.dbo.QAiHOS_list values(8,238,'SouthernCare, Inc')
insert into reports_bic.dbo.QAiHOS_list values(9,187,'Santa Cruz')
insert into reports_bic.dbo.QAiHOS_list values(10,1058,'Elizabeth Hospice, Inc')
insert into reports_bic.dbo.QAiHOS_list values(11,269,'Suncrest Health Services')
insert into reports_bic.dbo.QAiHOS_list values(12,1057,'Sta-Home Health & Hospice, Inc.')
insert into reports_bic.dbo.QAiHOS_list values(13,120,'Banner Hospice')
insert into reports_bic.dbo.QAiHOS_list values(14,27,'Brookdale Senior Living, Inc')
insert into reports_bic.dbo.QAiHOS_list values(15,232,'Hospice Partners of America')
insert into reports_bic.dbo.QAiHOS_list values(16,295,'Encompass Home Health & Hospice')
insert into reports_bic.dbo.QAiHOS_list values(17,227,'Delaware Hospice')
insert into reports_bic.dbo.QAiHOS_list values(18,1334,'Cornerstone Hospice & Palliative Care')
insert into reports_bic.dbo.QAiHOS_list values(19,144,'Signature Hospice')
insert into reports_bic.dbo.QAiHOS_list values(20,136,'Nathan Adelson Hospice')
insert into reports_bic.dbo.QAiHOS_list values(21,114,'Montgomery Hospice')

IF OBJECT_ID('reports_bic.[dbo].[TempQAFeedback_Monthly]', 'U') IS NOT NULL 
  DROP TABLE reports_bic.[dbo].[TempQAFeedback_Monthly]; 

CREATE TABLE reports_bic.[dbo].[TempQAFeedback_Monthly](
	[OrderID] [int] NOT NULL,
	[FeedbackType] [varchar](32) NULL,
	[DateGiven] [date] NULL,
	[Comments] [varchar](8000) NULL,
	[HospiceName] varchar(100) NULL,
	RegionName varchar(100) Null,
	Clientname varchar(100) NULL
) ON [PRIMARY]


select @iHOScount= count(*) from reports_bic.dbo.QAiHOS_list
print @iHOScount

select * from reports_bic.dbo.QAiHOS_list
set @iHOS_step=1

while (@iHOS_step <= @iHOScount)
begin

select @iHOS=iHOS_ID from reports_bic.dbo.QAiHOS_list where iHOS_SEQ_NO = @iHOS_step -- read Hospice id from the list 
select @iHOSNAME=iHOS_name from reports_bic.dbo.QAiHOS_list where iHOS_SEQ_NO = @iHOS_step
-----------
----your coode starts here
print @iHOS

---logic starts here

--Get any Dyad that ever had a valid budget record and filter by HOS / DME if given.
declare @tDyads as table (
	iHOS int,
	iCID int,
	iSID int,
	iDME int
)

insert into @tDyads
select distinct c.iCompanyRef as iHOS, bu.iClientRef as iCID, bu.iSiteRef as iSID, s.iCompanyRef as iDME
from ss.tblBudget as bu
join ss.tblLocation as c on c.iLocationID = bu.iClientRef
join ss.tblLocation as s on s.iLocationID = bu.iSiteRef
where c.iCompanyRef = isnull(@iHOS, c.iCompanyRef)
  and s.iCompanyRef = isnull(@iDME, s.iCompanyRef)

--Temp table to store our list of Client Site Dyads
declare @Dyad as table (
	iRgn int,
	sRgn varchar(64),
	iCID int,
	sCName varchar(128),
	iSID int,
	sSName varchar(128),
	iDME int,
	sDMEName  varchar(128)
)

	insert into @Dyad
	/* Get a List of Clients by Region with Site and DME*/
	select distinct r.isetid as iRegion, isnull(r.sName,c.sState + ' Region') as sRegion,
		dy.iClientRef as iCID, c.sName as sClient,
		dy.iSiteRef as iSID, s.sName as sSite,
		d.iCompanyID as iDME, d.sName as sDME
	from ss.tblDyad as dy
	join ss.tblLocation as c on dy.iClientRef = c.iLocationID
	join ss.tblLocation as s on dy.iSiteRef = s.iLocationID
	join ss.tblCompany as d on s.iCompanyRef = d.iCompanyID
	left join ss.tblSet as r on r.iSetId = c.iSetRef
	join @tDyads as td on dy.iClientRef = td.iCID and dy.iSiteRef = td.iSID
--	where dy.iClientRef in (
--		--select iLocationID from ss.tblLocation where iCompanyRef = @iHOS
--		--734,121,1951,36,215,268,44,538,1889
--		select iCID from @CIDs
--	)

--437 H1, R4, C39, Raw 86, Feed 301
	--and iClientRef = 466
	order by sRegion, sClient, sSite


--Any Region that was not defined needs a negative Region ID based on the state ID.
declare @USStates table (
	iRID int,
	sState char(2)
)
insert into @USStates values (-1,'DE')
insert into @USStates values (-2,'NJ')
insert into @USStates values (-3,'PA')
insert into @USStates values (-4,'GA')
insert into @USStates values (-5,'CT')
insert into @USStates values (-6,'MA')
insert into @USStates values (-7,'MD')
insert into @USStates values (-8,'SC')
insert into @USStates values (-9,'NH')
insert into @USStates values (-10,'VA')
insert into @USStates values (-11,'NY')
insert into @USStates values (-12,'NC')
insert into @USStates values (-13,'RI')
insert into @USStates values (-14,'VT')
insert into @USStates values (-15,'KY')
insert into @USStates values (-16,'TN')
insert into @USStates values (-17,'OH')
insert into @USStates values (-18,'LA')
insert into @USStates values (-19,'IN')
insert into @USStates values (-20,'MS')
insert into @USStates values (-21,'IL')
insert into @USStates values (-22,'AL')
insert into @USStates values (-23,'ME')
insert into @USStates values (-24,'MO')
insert into @USStates values (-25,'AR')
insert into @USStates values (-26,'MI')
insert into @USStates values (-27,'FL')
insert into @USStates values (-28,'TX')
insert into @USStates values (-29,'IA')
insert into @USStates values (-30,'WI')
insert into @USStates values (-31,'CA')
insert into @USStates values (-32,'MN')
insert into @USStates values (-33,'OR')
insert into @USStates values (-34,'KS')
insert into @USStates values (-35,'WV')
insert into @USStates values (-36,'NV')
insert into @USStates values (-37,'NE')
insert into @USStates values (-38,'CO')
insert into @USStates values (-39,'ND')
insert into @USStates values (-40,'SD')
insert into @USStates values (-41,'MT')
insert into @USStates values (-42,'WA')
insert into @USStates values (-43,'ID')
insert into @USStates values (-44,'WY')
insert into @USStates values (-45,'UT')
insert into @USStates values (-46,'OK')
insert into @USStates values (-47,'NM')
insert into @USStates values (-48,'AZ')
insert into @USStates values (-49,'AK')
insert into @USStates values (-50,'HI')
insert into @USStates values (-51,'DC')

update @Dyad
set iRgn = us.iRID
from @Dyad as dy
join @USStates as us on left(dy.sRgn,2) = us.sState
where iRgn is null

--select * from ss.tblLocation where iLocationID = 466
--select * from ss.tblDyad where iClientRef = 466

--If there is no region data, this will blow things up. 
--This was the case for a Washington DC with DC as the State name under Vitas.
select 'ERROR' as info, 'Missing iRGN' as note, * from @Dyad
where iRgn is null


--select ss.fn_Qts_Show('He&#39;s doin&#36; a &#34;great&#34; Job.')
select QAR.iOrderRef as OrderID, --QAF.cType, 
	QAFT.sName as FeedbackType, QAF.dCreated as DateGiven,
	ss.fn_Qts_Show(QAF.sNote) as Comments, @iHOSNAME as HospiceName, isnull(re.sname,us.sState) as RegionName, s.sName as ClientName into #tempFeedback--Remove the markup

from ss.tblQAFeedback as QAF
join ss.tblQAResults as QAR on QAF.iQAResultsRef = QAR.iQAResultsID
join ss.tblLookup as QAFT on QAFT.sGroup = 'QAFT' and QAF.cType = QAFT.sCode
join ss.tblOrder as O on o.iOrderID = QAR.iOrderRef
join ss.tblPatient as P on p.iPatientID = o.iPatientID
join ss.tblLocation as S on s.iLocationID = p.iSiteRef
join ss.tblLocation as C on c.iLocationID = p.iClientRef
join @USStates as us on us.sState = c.sState
left join ss.tblSet as re on re.iSetId = c.iSetRef
left join ss.tblIPU as I on i.iPatientRef = p.iPatientID
where iQAResultsRef in (
	--Get all the QA IDs that fall in the date range and are for these CIDs
	select iQAResultsID from ss.tblQAResults
	where iPatientRef in (
		select iPatientID from ss.tblPatient as p
		join @tDyads as d on p.iClientRef = d.iCID and p.iSiteRef = d.iSID

--			where iClientRef in (
--			--select iLocationID from ss.tblLocation where iCompanyRef = @iHOS
--			select iCID from @CIDs
--		)
	)
	and QAF.dCreated <= @xDate and QAF.dCreated >= @sDate
	and cStatusQA in ('O','E','C','A','U') --('C' = iDone, 'O' = iOpOut, 'E' = iNoEng, 'A' = iAbort, 'U' = iNoCnt)
	and QAFT.sName='Escalation'
)
order by QAF.dCreated

insert into reports_bic.[dbo].[TempQAFeedback_Monthly] select * from #tempFeedback

DROP TABLE #tempFeedback

delete from @Dyad
delete from @tDyads
delete from @USStates
--logic ends here


---your code ends here----
set @iHOS_step = @iHOS_step +1
end

---Your code ends here--


--This below code emails a report to the recipients--
 
 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.[dbo].[TempQAFeedback_Monthly]';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'Stateserv Reports'
      --, @recipients = 'sfriedt@stateserv.com;manager@icehouseproductions.com;cRoode@stateserv.com' 
	 ,@copy_recipients = 'lsantapoor@stateserv.com'
      , @subject = 'QA Escalations Monthly Report'
      , @body = 'Hi,
	  
	  Please find the QA Escalations monthly report attached.

	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @query
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'QA Escalations Monthly.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767
	
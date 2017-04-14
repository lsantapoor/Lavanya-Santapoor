use reports
 
Declare @sDate as datetime,@xDate as datetime,@iDME as int
Declare @iHOSCount as int , @iHOS_step as int ,@iHOS as int, @iHOS_ID as int,@iHOS_SEQ_NO as int

set @sDate = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
set @xDate = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week


print @sDate
Print @xDate

--drop table dbo.iHOS_list
IF OBJECT_ID('reports_bic.dbo.iHOS_list', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.iHOS_list; 

create table reports_bic.dbo.iHOS_list(
iHOS_SEQ_NO int,
iHOS_ID int
)

insert into reports_bic.dbo.iHOS_list values(1,87)
insert into reports_bic.dbo.iHOS_list values(2,29)
insert into reports_bic.dbo.iHOS_list values(3,10)
insert into reports_bic.dbo.iHOS_list values(4,12)
insert into reports_bic.dbo.iHOS_list values(5,86)
insert into reports_bic.dbo.iHOS_list values(6,299)
insert into reports_bic.dbo.iHOS_list values(7,257)
insert into reports_bic.dbo.iHOS_list values(8,238)
insert into reports_bic.dbo.iHOS_list values(9,187)
insert into reports_bic.dbo.iHOS_list values(10,1058)
insert into reports_bic.dbo.iHOS_list values(11,269)
insert into reports_bic.dbo.iHOS_list values(12,1057)
insert into reports_bic.dbo.iHOS_list values(13,120)
insert into reports_bic.dbo.iHOS_list values(14,27)
insert into reports_bic.dbo.iHOS_list values(15,232)
insert into reports_bic.dbo.iHOS_list values(16,295)
insert into reports_bic.dbo.iHOS_list values(17,227)
insert into reports_bic.dbo.iHOS_list values(18,1334)
insert into reports_bic.dbo.iHOS_list values(19,144)
insert into reports_bic.dbo.iHOS_list values(20,136)


IF OBJECT_ID('reports_bic.[dbo].[TempQAFeedback_Weekly]', 'U') IS NOT NULL 
  DROP TABLE reports_bic.[dbo].[TempQAFeedback_Weekly]; 

CREATE TABLE reports_bic.[dbo].[TempQAFeedback_Weekly](
	[OrderID] [int] NOT NULL,
	[FeedbackType] [varchar](32) NULL,
	[DateGiven] [date] NULL,
	[Comments] [varchar](8000) NULL
) ON [PRIMARY]


select @iHOScount= count(*) from reports_bic.dbo.iHOS_list
print @iHOScount

select * from reports_bic.dbo.iHOS_list
set @iHOS_step=1

while (@iHOS_step <= @iHOScount)
begin

select @iHOS=iHOS_ID from reports_bic.dbo.iHOS_list where iHOS_SEQ_NO = @iHOS_step -- read Hospice id from the list 
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
--3775
insert into @tDyads
select distinct c.iCompanyRef as iHOS, bu.iClientRef as iCID, bu.iSiteRef as iSID, s.iCompanyRef as iDME
from ss.tblBudget as bu
join ss.tblLocation as c on c.iLocationID = bu.iClientRef
join ss.tblLocation as s on s.iLocationID = bu.iSiteRef
where c.iCompanyRef = isnull(@iHOS, c.iCompanyRef)
  and s.iCompanyRef = isnull(@iDME, s.iCompanyRef)


--select ss.fn_Qts_Show('He&#39;s doin&#36; a &#34;great&#34; Job.')
select 'Feedback' as info
select QAR.iOrderRef as OrderID, --QAF.cType, 
	QAFT.sName as FeedbackType, QAF.dCreated as DateGiven,
	ss.fn_Qts_Show(QAF.sNote) as Comments into #tempFeedback--Remove the markup
from ss.tblQAFeedback as QAF
join ss.tblQAResults as QAR on QAF.iQAResultsRef = QAR.iQAResultsID
join ss.tblLookup as QAFT on QAFT.sGroup = 'QAFT' and QAF.cType = QAFT.sCode
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

insert into reports_bic.[dbo].[TempQAFeedback_Weekly] select * from #tempFeedback

DROP TABLE #tempFeedback


--logic ends here


---your code ends here----
set @iHOS_step = @iHOS_step +1
end

--This below code emails a report to the recipients--
 
 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.[dbo].[TempQAFeedback_Weekly]';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'DMETrack Reports'
      , @recipients = 'sfriedt@stateserv.com;manager@icehouseproductions.com;cRoode@stateserv.com' 
	 ,@copy_recipients = 'lsantapoor@stateserv.com'
      , @subject = 'QA Escalations Weekly Report'
      , @body = 'Hi,
	  
	  Please find the QA Escalations weekly report attached.

	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @query
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'QA Escalations Report Weekly.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767
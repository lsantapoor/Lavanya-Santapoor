USE [reports]
GO
/****** Object:  StoredProcedure [ss].[sp_Report_OrderWorkflowActivity]    Script Date: 11/3/2016 5:21:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Declare @startDate as datetime,@EndDate as datetime

--Below code is to fetch the date for the first(sunday) and last day(Saturday) of previous week--
--set @startDate = '11/02/2016'
--set @EndDate = '11/02/2016'
set @StartDate = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
set @EndDate = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week

print @StartDate
print @EndDate

DECLARE @TempHistory TABLE 
(
	OrderId int null
	,ActionTime datetime null
	,UserName varchar(50) null
	,FullName varchar(128) null
	,cAction varchar(16)
	,[Description] varchar(128) null
)

insert into @TempHistory
select	h.iOrderRef as OrderId
		,h.dAction as ActionTime
		,u.sUser as UserName
		,FullName = u.sFull
		,h.cAction
		,[Description] = lu.sDescription
from	ss.tblOrderHistory h left outer join ss.tblUser as u
			on h.iUserref = u.iUserID
		inner join ss.tblLookup lu
			on h.cAction = lu.sCode
where h.iOrderRef in
(	select o.iOrderId
	FROM	ss.tblOrder o
	WHERE	o.dtDateStamp >= @StartDate
	and o.dtDateStamp <= @EndDate
)
order by h.dAction


IF OBJECT_ID('reports_bic.dbo.WorkFlowData', 'U') IS NOT NULL 
  DROP TABLE  reports_bic.dbo.WorkFlowData; 

	CREATE TABLE reports_bic.dbo.WorkFlowData(
	CompanyName varchar(100) null
	,OrderId int null
	,OrderType varchar(100) null
	,FullName varchar(100) null
	,DateStamp date null
	,WhenViewed date null
	,ViewedBy varchar(50) null
	,WhenScheduled date null
	,ScheduledBy varchar(50) null
	,WhenAssigned date null
	,AssignedBy varchar(50) null
	--,WhenComplete datetime null
	--,CompleteBy varchar(50) null
	--,WhenReconciled datetime null
	--,ReconciledBy varchar(50) null
	,CreatedToViewed varchar(50) null
	,ScheduledToAssigned varchar(50) null
	,ViewedToScheduled varchar(50) null
	--,CompleteToReconciled varchar(50) null

)
insert into reports_bic.dbo.WorkFlowData	
SELECT	
		c.sName as CompanyName,
		o.iOrderID as OrderId,
		t.szType as OrderType,
		p.szLastName + ', ' + p.szFirstName AS FullName,
		
		o.dtDateStamp as DateStamp,
	
		WhenViewed = (select top 1 ActionTime from @TempHistory where OrderId = o.iOrderID and cAction != 'Nod' and ActionTime is not null order by ActionTime)
		,ViewedBy = (select top 1 UserName from @TempHistory where OrderId = o.iOrderID and cAction != 'Nod' and ActionTime is not null order by ActionTime)
		,WhenScheduled = (select top 1 ActionTime from @TempHistory where OrderId = o.iOrderID and cAction = 'Sch' and ActionTime is not null order by ActionTime)
		,ScheduledBy = (select top 1 UserName from @TempHistory where OrderId = o.iOrderID and cAction = 'Sch' and ActionTime is not null order by ActionTime)
		,CASE 
			WHEN day(o.dtDateStamp) = day(o.dtScheduled) then (select top 1 ActionTime from @TempHistory where OrderId = o.iOrderID and cAction = 'EnR' and ActionTime is not null order by ActionTime)
		END as WhenAssigned
		,CASE 
			WHEN day(o.dtDateStamp) = day(o.dtScheduled) then (select top 1 UserName from @TempHistory where OrderId = o.iOrderID and cAction = 'EnR' and ActionTime is not null order by ActionTime)
		END as AssignedBy
				
		--,WhenComplete = (select top 1 ActionTime from @TempHistory where OrderId = o.iOrderID and cAction = 'Cmp' and ActionTime is not null order by ActionTime)
		--,CompleteBy = (select top 1 UserName from @TempHistory where OrderId = o.iOrderID and cAction = 'Cmp' and ActionTime is not null order by ActionTime)
		--,WhenReconciled = (select top 1 ActionTime from @TempHistory where OrderId = o.iOrderID and cAction = 'Rcd' and ActionTime is not null order by ActionTime)
		--,ReconciledBy = (select top 1 UserName from @TempHistory where OrderId = o.iOrderID and cAction = 'Rcd' and ActionTime is not null order by ActionTime)
		
		
		,CreatedToViewed = ' '
		,ScheduledToAssigned = ' '
		,ViewedToScheduled = ' '
		--,CompleteToReconciled = ' '

	FROM	ss.tblOrder o
	JOIN	ss.tblType t		ON	t.cTypeID = o.cTypeID
	JOIN	ss.tblPatient p		ON	o.iPatientID = p.iPatientID
	left JOIN	ss.tblLocation c		ON	c.iLocationID = p.iClientRef and c.cType = 'C'
	WHERE	o.dtDateStamp >= @StartDate
			and o.dtDateStamp <= @EndDate
	order by iOrderId
	
	--update timespans
	update	reports_bic.dbo.WorkFlowData
	set		CreatedToViewed = ss.fn_TimeSpan(DateStamp, WhenViewed)
			,ScheduledToAssigned = ss.fn_TimeSpan(WhenScheduled, WhenAssigned)
			,ViewedToScheduled = ss.fn_TimeSpan(WhenViewed, WhenScheduled)
			--,CompleteToReconciled = ss.fn_TimeSpan(WhenComplete, WhenReconciled)
	
	
	select * from reports_bic.dbo.WorkFlowData
	select * from @TempHistory

-- Below code is to send data by email to the recipients--

 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.dbo.WorkFlowData';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'DMETrack Reports'
     --, @recipients = 'CYeretzian@stateserv.com;kkahl@stateserv.com;SiteManagers@stateserv.com' 
	 ,@copy_recipients = 'lsantapoor@stateserv.com'
      , @subject = 'Order WorkFlow Activity Data Weekly'
      , @body = 'Hi,
	  
	  Please find the weekly Order Workflow Activity Data report attached.
	  
	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @query
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'Order WorkFlow Activity Data Weekly .csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767
USE [reports_bic]
GO

/****** Object:  StoredProcedure [dbo].[OrdersDispatch]    Script Date: 2/27/2017 9:55:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Lavanya Santapoor
-- Create date: 2017-03-10
-- Description:	Created to pull all the orders and and time took from order is being placed to the dispatch status
-- =============================================
CREATE PROCEDURE [dbo].[OrdersDispatch]

AS
BEGIN

Declare @dS as date,@dE as date
--set @dS = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
--set @dE = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week
set @dS=GetDATE()-1
set @dE=GETDATE()
print @dS
print @dE
declare @iDME as int = 2
declare @tOrderList as table (
       iOID int,
       dNewOrder datetime,
       dRecieved datetime, --New Order if Recieved is null
       iOHID_NOd int, --Order History ID of New Order
       iOHID_Rec int, --Order History ID of New Order or Recieved, greater of the two...
       iOHID_Sch int, --Order History ID of Last Scheduled
       iUID_Sch int,
       iOHID_EnR int, --Order History ID of Last Enroute
       iUID_EnR int,
       --dSchBgn datetime,
       dSchEnd datetime,
       iOHID_ViewF int, 
       dFirstView datetime,
       iOHID_ViewL int,
       dLastView datetime,
       iCntViewB4Scheduled int
)
--Get list of orders
insert into @tOrderList (iOID, dSchEnd, dNewOrder, dRecieved)
select o.iOrderID, o.dtxScheduled, o.dtDateStamp, isnull(o.dtxReceived,o.dtDateStamp)
from reports.ss.tblOrder as o
join reports.ss.tblPatient as p on o.iPatientID = p.iPatientID
join reports.ss.tblLocation as s on s.iLocationID = p.iSiteRef
where o.ScheduleEnd >= @dS and o.ScheduleEnd <= @dE
and s.iCompanyRef = @iDME --limit to B&M
--Get New Order Info for list of orders
update @tOrderList 
set iOHID_NOd = x.iOHID
from @tOrderList as ol
join (
       select iOrderRef as iOID, 
       max(iOrderHistoryID) as iOHID 
       from reports.ss.tblOrderHistory 
       where iOrderRef in (select iOID from @tOrderList)
       and cAction = 'NOd'
       group by iOrderRef
) as x on ol.iOID = x.iOID
--Get Last Recieved Info for list of orders
update @tOrderList 
set iOHID_Rec = x.iOHID
from @tOrderList as ol
join (
       select iOrderRef as iOID, 
       max(iOrderHistoryID) as iOHID 
       from reports.ss.tblOrderHistory 
       where iOrderRef in (select iOID from @tOrderList)
       and cAction in ('NOd','Rec')
       group by iOrderRef
) as x on ol.iOID = x.iOID
--Get Last Scheduled Info for list of orders
update @tOrderList 
set iOHID_Sch = x.iOHID
from @tOrderList as ol
join (
       select iOrderRef as iOID, 
       max(iOrderHistoryID) as iOHID 
       from reports.ss.tblOrderHistory 
       where iOrderRef in (select iOID from @tOrderList)
       and cAction = 'Sch'
       group by iOrderRef
) as x on ol.iOID = x.iOID
--Get Last Enroute Info for list of orders
update @tOrderList 
set iOHID_EnR = x.iOHID
from @tOrderList as ol
join (
       select iOrderRef as iOID, 
       max(iOrderHistoryID) as iOHID 
       from reports.ss.tblOrderHistory 
       where iOrderRef in (select iOID from @tOrderList)
       and cAction = 'EnR'
       group by iOrderRef
) as x on ol.iOID = x.iOID
--Get User Data for Scheduled
update @tOrderList 
set iUID_Sch = oh.iUserRef
from @tOrderList as ol
join reports.ss.tblOrderHistory as oh on ol.iOHID_Sch = oh.iOrderHistoryID
--Get User Data for Enroute
update @tOrderList 
set iUID_EnR = oh.iUserRef
from @tOrderList as ol
join reports.ss.tblOrderHistory as oh on ol.iOHID_EnR = oh.iOrderHistoryID
--Get Date Scheduled Start
--update @tOrderList set dSchBgn = cast(dSchEnd as date)
update @tOrderList 
set iCntViewB4Scheduled = x.iViewCnt
from @tOrderList as ol
join (
       select oh.iOrderRef as iOID,
       sum(1) as iViewCnt
       from @tOrderList as z
       join reports.ss.tblOrderHistory as oh on oh.iOrderRef = z.iOID
       where oh.cAction = 'LVB'
       --and oh.dAction <= z.dSchEnd
       and oh.iOrderHistoryID <= z.iOHID_Sch
       group by iOrderRef
) as x on ol.iOID = x.iOID
--Get First View Since (Last New Order or Recieved)
update @tOrderList 
set iOHID_ViewF = x.iOHID
from @tOrderList as ol
join (
       select oh.iOrderRef as iOID,
       min(iOrderHistoryID) as iOHID 
       from @tOrderList as z
       join reports.ss.tblOrderHistory as oh on oh.iOrderRef = z.iOID
       where oh.cAction = 'LVB'
       and oh.iOrderHistoryID >= z.iOHID_Rec
       group by iOrderRef
) as x on ol.iOID = x.iOID
--Get Last Viewed before Scheduled Action...
update @tOrderList 
set dFirstView = dAction
from @tOrderList as ol
join reports.ss.tblOrderHistory as oh on ol.iOHID_ViewF = oh.iOrderHistoryID

--Get Last View Date (before Scheduled Action)
update @tOrderList 
set iOHID_ViewL = x.iOHID
from @tOrderList as ol
join (
       select oh.iOrderRef as iOID,
       max(iOrderHistoryID) as iOHID 
       from @tOrderList as z
       join reports.ss.tblOrderHistory as oh on oh.iOrderRef = z.iOID
       where oh.cAction = 'LVB'
       and oh.iOrderHistoryID <= z.iOHID_Sch
       group by iOrderRef
) as x on ol.iOID = x.iOID
--Get Last Viewed before Scheduled Action...
update @tOrderList 
set dLastView = dAction
from @tOrderList as ol
join reports.ss.tblOrderHistory as oh on ol.iOHID_ViewL = oh.iOrderHistoryID

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
from	reports.ss.tblOrderHistory h left outer join reports.ss.tblUser as u
			on h.iUserref = u.iUserID
		inner join reports.ss.tblLookup lu
			on h.cAction = lu.sCode
where h.iOrderRef in
(	select o.iOrderId
	FROM	reports.ss.tblOrder o
	WHERE	o.dtDateStamp >= @ds
	and o.dtDateStamp <= @de
)
order by h.dAction

IF OBJECT_ID('reports_bic.[dbo].[TimetoDispatch]', 'U') IS NOT NULL 
  DROP TABLE  reports_bic.[dbo].[TimetoDispatch]; 

CREATE TABLE reports_bic.[dbo].[TimetoDispatch](
	[Order Scheduled Date] [date] NULL,
	[Order ID] [int] NOT NULL,
	[Order Type] [varchar](16) NOT NULL,
	[Order Priority] [varchar](3) NOT NULL,
	[Hospice Name] [varchar](85) NULL,
	[Site Name] [varchar](85) NULL,
	[Order Enroute Date] [datetime] NULL,
	[Times Enrouted] [int] NOT NULL,
	[Enrouted By] [varchar](128) NULL,
	[Time to Dispatch] [varchar](24) NULL,
	[Order Completed Date] [datetime] NULL,
	[Completed By] [varchar](85) null,
	[URL] [varchar](83) NULL
) ON [PRIMARY]

insert into reports_bic.[dbo].[TimetoDispatch]
select cast(o.ScheduleEnd as date) as 'dScheduleEnd', 
 o.iOrderID as 'iOID', 
 ts.szStatus as 'Order Type',
     case when o.Priority = 0 then 'No' else 'Yes' end as 'sOrderPriority', 
	      h.sAbbr + ': ' + c.sName as [HOS Client],
       s.sName + ' [ ' + cast(s.iLocationID as varchar(16)) + ' ]' as 'sSiteName', 
	    o.dtxEnroute as 'dtLastEnroute', 
       isnull(o.iEnrouteCnt,0) as 'iEnrouteCnt', 
       ue.sFull as 'sUserEnroute', 
       reports.ss.fn_TimeSpan(o.dtxScheduled,o.dtxEnroute) as 'xS2D_DHMS',
	   o.dtCompleted as 'dLastCompleted',
	   CompleteBy = (select top 1 UserName from @TempHistory where OrderId = o.iOrderID and cAction = 'Cmp' and ActionTime is not null order by ActionTime),
       
       'https://www.dmetrack.com/DME/ViewOrder.aspx?order=' + cast(o.iOrderID as varchar(16)) + '#' + cast(o.iOrderID as varchar(16)) as 'Link'

from @tOrderList as ol
join reports.ss.tblOrder as o on ol.iOID = o.iOrderID
JOIN reports.ss.tblStatus ts (NOLOCK)ON	ts.cStatusID = o.cStatusID
join reports.ss.tblPatient as p on o.iPatientID = p.iPatientID
join reports.ss.tblLocation as s on s.iLocationID = p.iSiteRef
join reports.ss.tblLocation as c on p.iClientRef = c.iLocationID
join reports.ss.tblCompany as h on c.iCompanyRef = h.iCompanyID
join reports.ss.tblUser as us on us.iUserID = ol.iUID_Sch
left join reports.ss.tblUser as ue on ue.iUserID = ol.iUID_EnR
join reports.ss.tblUser as ub on ub.iUserID = o.iOrderedBy where iEnrouteCnt<>'0'

delete from @tOrderList
delete from @TempHistory
/*
-- Below code is to send data by email to the recipients--

 Declare @query nvarchar(max);
    Set @query = 'select * from reports_bic.[dbo].[TimetoDispatch]';

 Execute msdb.dbo.sp_send_dbmail
        @profile_name = 'StateServ Reports'
    --, @recipients = 'croode@stateserv.com;sfriedt@stateserv.com' 
	 --,@copy_recipients = 'lsantapoor@stateserv.com;jstrong@stateserv.com'
      , @subject = 'Order WorkFlow Activity Data Daily'
      , @body = 'Hi,
	  
	  Please find the Order Workflow Activity Data report attached.
	  
	  Let me know in case of any concerns.

	  Have a nice day.
	  
	  Thanks,
	  Lavanya'
      , @query = @query
      , @query_result_separator='	' -- tab
      , @query_result_header = 1
      , @attach_query_result_as_file = 1
      , @query_attachment_filename = 'Order WorkFlow Activity Data Daily.csv'
	  ,@query_result_no_padding=1 --trim
	 ,@query_result_width = 32767
	 */END
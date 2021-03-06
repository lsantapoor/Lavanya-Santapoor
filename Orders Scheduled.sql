USE [reports_bic]
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Lavanya Santapoor
-- Create date: 2017-03-10
-- Description:	Created to pull all the orders and the flow of the orders till completed
-- =============================================
CREATE PROCEDURE [dbo].[OrdersScheduledV1]

AS
BEGIN
Declare @dS as date,@dE as date
--set @dS = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
--set @dE = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week
set @dS=GetDATE()-1
set @dE=@dS
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
where cast(o.dtScheduled as date)= @dS-- and o.ScheduleEnd <= @dE
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

IF OBJECT_ID('reports_bic.[dbo].[OrdersScheduled]', 'U') IS NOT NULL 
  DROP TABLE  reports_bic.[dbo].[OrdersScheduled]; 

CREATE TABLE reports_bic.[dbo].[OrdersScheduled](
	[Scheduled Date] [date] NULL,
	[Orders Scheduled] [int] NULL,
	[Scheduler] [varchar](128) NOT NULL
) ON [PRIMARY]
--select * from @tOrderList
insert into reports_bic.[dbo].[OrdersScheduled]
select 
       o.dtScheduled as '[Scheduled Date]',
	   --o.dtxScheduled as 'dtLastScheduled', 
	   o.iScheduledCnt,
       us.sFull as 'sUserScheduled'
	
from @tOrderList as ol
join reports.ss.tblOrder as o on ol.iOID = o.iOrderID
join reports.ss.tblPatient as p on o.iPatientID = p.iPatientID
join reports.ss.tblLocation as s on s.iLocationID = p.iSiteRef
join reports.ss.tblUser as us on us.iUserID = ol.iUID_Sch
left join reports.ss.tblUser as ue on ue.iUserID = ol.iUID_EnR
join reports.ss.tblUser as ub on ub.iUserID = o.iOrderedBy

delete from @tOrderList

END
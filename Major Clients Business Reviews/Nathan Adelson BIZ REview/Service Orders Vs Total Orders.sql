USE [reports]
GO
/****** Object:  StoredProcedure [ss].[sp_GetOrder]    Script Date: 8/11/2016 10:18:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Declare @startDate as datetime,@EndDate as datetime,@startDate1 as datetime, @loop_step as int ,@smonth as varchar(12)


set @loop_step=0

IF OBJECT_ID('reports_bic.[dbo].[NathanServiceOrders]', 'U') IS NOT NULL 
  DROP TABLE reports_bic.[dbo].[NathanServiceOrders]; 
  
  CREATE TABLE reports_bic.[dbo].[NathanServiceOrders](
	[OrderCount] [int] NOT NULL,
	[Servicecalls] [int] NOT NULL,
	[dGiven] varchar(12) NULL,
	[NocallPercent] numeric(9,6) NULL
) ON [PRIMARY] 

while (@loop_step <= 2) --Loop for 3 months
begin

set @StartDate1 = DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - (0+@loop_step) , 0)
set @StartDate = DATEADD(month, DATEDIFF(month, -1, getdate()) - (2+@loop_step), 0)
set @EndDate = DATEADD(ss, -1, DATEADD(month, DATEDIFF(month, 0, @StartDate1), 0))

set @smonth=DATENAME(month ,@StartDate)

print @StartDate
print @EndDate
print @smonth

/*
-=[Version Infomration]=-
Name        Date     VER Update
I. Erickson 20061212 1.1 Updated to handle new Order / Order Detail structure.
I. Erickson 20070620 1.2 Updated for Address Detail Changes
I. Erickson 20070625 1.3 Updated for Order Referance Change to Detail Table
			  App was not using Refernece Number as such was dropped
				Infact Cnt see where this is even getting called from?
I. Erickson 20100604 2.0 Update for Version 2.0 DME Track network backend.
I. Erickson 20100902 2.1 Update for Version 2.1 DME Track network backend.
E.Eilertsen 20110812 2.2 Outputs times offset by timezone.

-=[Called By]=-
orderstatus.asp
services.aspx.cs

-=[Example Calls]=-
exec ss.sp_GetOrder 123456

-=[Function]=-
Pulls back order data for a single order. Pulls back address, Type, Status, Patient info with the order.
*/	
	
	--- get timezone for location/company ---
	DECLARE @iSiteRef int
	DECLARE @iTZRef int, @iorderid int
	set @iorderid=0
	SELECT @iSiteRef = p.iSiteRef FROM ss.tblOrder o (NOLOCK) JOIN ss.tblPatient p (NOLOCK) ON p.iPatientID = o.iPatientID --WHERE o.iOrderID = @iOrderID
	SET @iTZRef = ss.fn_GetTimeZone(null,@iSiteRef,null)
	
	--- get order info ---
	SELECT	o.iOrderID,
		o.iPatientID,
		o.iDMEID,
		o.cStatusID,
		s.szStatus,
		o.cTypeID,
		t.szType,
--		o.iReferenceOrderID,
		ss.fn_LocationTime(o.dtDateStamp,@iTZRef,0) as 'DateStamp',
		u.sFull as vcUserName,
		o.vcGUID,
		o.szContactName,
		o.szPhone1,
		o.szPhone2,
		p.szLastName + ', ' + p.szFirstName AS PATIENT,
		a.szAddress1,
		a.szAddress2,
		a.szCity,
		a.szState,
		a.szZip,
		p.iClientRef as iClientID,
		p.iSiteRef,
		o.blnIncident,
		o.CompletionActionId,
		o.IsRedelivery,
		o.IsServiceCall,
		o.Priority,
		ss.fn_LocationTime(o.dtScheduled,@iTZRef,0) as ScheduleStart,
		ss.fn_LocationTime(o.ScheduleEnd,@iTZRef,0) as ScheduleEnd,
		tz.sZoneAbbr as TZAbbr,
		( SELECT dbo.fnGetOrderDeliveryMinutes(@iOrderid,NULL) ) as DeliveryMinutes into #temporders@loop_step
	FROM	ss.tblOrder o (NOLOCK)
	JOIN	ss.tblStatus s (NOLOCK)		ON	s.cStatusID = o.cStatusID
	JOIN	ss.tblType t (NOLOCK)		ON	t.cTypeID = o.cTypeID
	JOIN	ss.tblPatient p (NOLOCK)	ON	o.iPatientID = p.iPatientID
	JOIN	ss.tblAddress a (NOLOCK)	ON	o.iAddressRef = a.iAddressID
	join	ss.tblUser u (NOLOCK)		ON	o.iOrderedBy = u.iUserID  
	LEFT JOIN ss.tblTimeZone tz (NOLOCK) on tz.iTZID = @iTZRef
	--where p.iClientRef in (3268,17) 
	left join reports.ss.tblLocation w on p.iClientRef=w.iLocationid where w.iCompanyref=136 
	
	and o.dtDateStamp between @startdate and @enddate
--	WHERE	o.iOrderID = @iOrderID

declare @ordercnt int ,@ServiceCallcnt int,@percent decimal(9,6)
select @ordercnt=count(iOrderID) from #temporders@loop_step
select @ServiceCallcnt=count(IsServiceCall) from #temporders@loop_step where IsServiceCall=1
select @percent=((@ordercnt-@ServiceCallcnt)*100/cast (@ordercnt as float))

print @percent

insert into reports_bic.[dbo].[NathanServiceOrders] values(@ordercnt,@ServiceCallcnt,@smonth,@percent)

drop table #temporders@loop_step

--Logic ends here
set @loop_step = @loop_step +1
end





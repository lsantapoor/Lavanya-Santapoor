USE [reports]
GO
/****** Object:  StoredProcedure [ss].[sp_GetOrder]    Script Date: 8/11/2016 10:18:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Declare @startDate as datetime,@EndDate as datetime,@startDate1 as datetime, @loop_step as int ,@smonth as varchar(12)
--=[ Pick Target Company ]=--

IF OBJECT_ID('reports_bic.dbo.iHOS_ServiceOrderslistBizReview', 'U') IS NULL 
begin
declare @table_text char(100)
set @table_text = 'Hospice List Table Not present. Creating the table.... '
print @table_text

--  DROP TABLE reports_bic.dbo.iHOS_ServiceOrderslistBizReview; 

create table reports_bic.dbo.iHOS_ServiceOrderslistBizReview(
iHOS_SEQ_NO int,
iHOS_ID int,
iHOS_name char(100)
)

--Usage of insert below:
--insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(sequence_number,hospice id, Hospice Name)

insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(1,10,'Optum Palliative and Hospice Care') --Optum Palliative and Hospice Care
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(2,12,'Alacare Home Health & Hospice')  --Alacare Home Health & Hospice
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(3,257,'Harbor Light Hospice') --Harbor Light Hospice
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(4,238,'SouthernCare, Inc {Curo}') --SouthernCare, Inc {Curo}
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(5,187,'Hospice of Santa Cruz County') --Hospice of Santa Cruz County
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(6,269,'Suncrest Health Services') --Suncrest Health Services
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(7,1057,'Sta-Home Health & Hospice, Inc.') --Sta-Home Health & Hospice, Inc.
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(8,120,'Banner Hospice') --Banner Hospice
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(9,232,'Hospice Partners of America') --Hospice Partners of America
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(10,295,'Encompass Home Health & Hospice') 
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(11,227,'Delaware Hospice')-- Delaware Hospice
insert into reports_bic.dbo.iHOS_ServiceOrderslistBizReview values(12,144,'Signature Hospice')-- Signature Hospice 

end

IF OBJECT_ID('reports_bic.[dbo].[StandardServiceOrders]', 'U') IS NOT NULL 
  DROP TABLE reports_bic.[dbo].[StandardServiceOrders]; 
  
  CREATE TABLE reports_bic.[dbo].[StandardServiceOrders](
	[HospiceName] varchar(100) NULL,
	[HospiceID] [int] NOT NULL,
	[OrderCount] [int] NOT NULL,
	[Servicecalls] [int] NOT NULL,
	[dGiven] varchar(12) NULL,
	[NocallPercent] numeric(9,6) NULL
) ON [PRIMARY] 


--Comment ends 

Declare @iHOSCount as int , @iHOS_step as int ,@iHOS as int, @iHOS_ID as int,@iHOS_SEQ_NO as int,@iHOSNAME as char(100)
select @iHOScount= count(*) from reports_bic.dbo.iHOS_ServiceOrderslistBizReview
print @iHOScount

select * from reports_bic.dbo.iHOS_ServiceOrderslistBizReview
set @iHOS_step=1

while (@iHOS_step <= @iHOScount)
begin

select @iHOS=iHOS_ID from reports_bic.dbo.iHOS_ServiceOrderslistBizReview where iHOS_SEQ_NO = @iHOS_step -- read Hospice id from the list 
select @iHOSNAME=iHOS_name from reports_bic.dbo.iHOS_ServiceOrderslistBizReview where iHOS_SEQ_NO = @iHOS_step
-----------
----your coode starts here
print @iHOS

---logic starts here

set @loop_step=0

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
		( SELECT dbo.fnGetOrderDeliveryMinutes(@iOrderid,NULL) ) as DeliveryMinutes into #tempServiceorders@loop_step
	FROM	ss.tblOrder o (NOLOCK)
	JOIN	ss.tblStatus s (NOLOCK)		ON	s.cStatusID = o.cStatusID
	JOIN	ss.tblType t (NOLOCK)		ON	t.cTypeID = o.cTypeID
	JOIN	ss.tblPatient p (NOLOCK)	ON	o.iPatientID = p.iPatientID
	JOIN	ss.tblAddress a (NOLOCK)	ON	o.iAddressRef = a.iAddressID
	join	ss.tblUser u (NOLOCK)		ON	o.iOrderedBy = u.iUserID  
	LEFT JOIN ss.tblTimeZone tz (NOLOCK) on tz.iTZID = @iTZRef
	left join reports.ss.tblLocation w on p.iClientRef=w.iLocationid where w.iCompanyref=@iHos
	--where p.iClientRef in (3268,17) 
	and o.dtDateStamp between @startdate and @enddate
--	WHERE	o.iOrderID = @iOrderID

declare @ordercnt int ,@ServiceCallcnt int,@percent decimal(9,6)
select @ordercnt=count(iOrderID) from #tempServiceorders@loop_step
select @ServiceCallcnt=count(IsServiceCall) from #tempServiceorders@loop_step where IsServiceCall=1
select @percent=((@ordercnt-@ServiceCallcnt)*100/cast (@ordercnt as float))

print @percent

insert into reports_bic.[dbo].[StandardServiceOrders] values(@iHOSNAME,@iHOS,@ordercnt,@ServiceCallcnt,@smonth,@percent)

drop table #tempServiceorders@loop_step


--Logic ends here
set @loop_step = @loop_step +1
end

---your code ends here----
set @iHOS_step = @iHOS_step +1
end



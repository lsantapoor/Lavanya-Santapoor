use reports
declare @iDME as int, @iLimitDataFlag as int, @iReportSum as int
set @iDME = 2
set @iLimitDataFlag = 0
set @iLimitDataFlag = 1
/*
	version 
	1.4 erickson 20150810 Updated to use reports dev calls
*/
Declare @startDate as date,@EndDate as date

---Below code is to fetch the date for the first and last day of previous month--

set @StartDate = DATEADD(wk, -1, DATEADD(DAY, 1-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --first day previous week
set @EndDate = DATEADD(wk, 0, DATEADD(DAY, 0-DATEPART(WEEKDAY, GETDATE()), DATEDIFF(dd, 0, GETDATE()))) --last day previous week
print @StartDate
print @EndDate
/*------------------------------------*\
|  Bgn Standard Reporting Window Call  |
\*------------------------------------*/

--declare @cWindow as char(1), @iOffset as int, @iSummaryFlag as int
--set @cWindow = 'W' --'Y'early, 'Q'uarterly, 'M'onthly, 'W'eekly (Su-Sa), 'I'SO Week (Mo-Su), 'D'aily, 'B'i-Monthly
--set @iOffset = -0 --0 for Last (day, week, etc) Negative for older reports, +1 is current time span
--set @iSummaryFlag = 0 --1 will force a 13 x window view for summary data lines.1 is current time span
--set @iSummaryFlag = 1 --1 will force a 13 x window view for summary data lines.1 is current time span
--set @cWindow = 'M' --'Y'early, 'Q'uarterly, 'M'onthly, 'W'eekly (Su-Sa), 'I'SO Week (Mo-Su), 'D'aily, 'B'i-Monthly

--select 'All values returned'
--select * from ss.fn_Report_DateRange(@cWindow,@iOffset,@iSummaryFlag,default,default) --Window, Offset, Summary, Size, Date

select 'Get what is Needed'
declare @dOldest as datetime, @sTitle as varchar(32), @sLabel as char(10), @sInfo as varchar(64), @sVer varchar(8)


select @sTitle as Title, @startDate as dStart, @EndDate as dEnd, @dOldest as dOldest, @sLabel as dLabel,
    @sInfo as info, @sVer as Ver

/*------------------------------------*\
|  End Standard Reporting Window Call  |
\*------------------------------------*/

IF OBJECT_ID('reports_bic.dbo.ServiceCallOrdersWeeklyV2', 'U') IS NOT NULL 
  DROP TABLE  reports_bic.dbo.ServiceCallOrdersWeeklyV2; 
  
  
  CREATE TABLE reports_bic.dbo.ServiceCallOrdersWeeklyV2 (
	iSID int not null,
	sDMESite varchar(128) not null,
	sHOSClient varchar(128) not null,
	dCompleted datetime not null,
	iOID int not null,
	sDriver varchar(64),
	sOrderedBy varchar(64),
	sUserType varchar(16),
	sReason varchar(24),
	sLocation varchar(3),
	iServiceCall int not null,
	iCntBeds int not null,
	iCntConc int not null,
	iCntLAL  int not null,
	iCntWC   int not null,
	sNotes varchar(8000)
)ON [PRIMARY]

insert into reports_bic.dbo.ServiceCallOrdersWeeklyV2
select  s.iLocationID as iSID,
		d.sAbbr + ': ' + s.sName as [DME Site],
		h.sAbbr + ': ' + c.sName as [HOS Client],
		isnull(o.dtCompleted,'') as [Date Completed],
		o.iOrderID as [Order ID],
		isnull(ud.sLast + ', ' + ud.sFirst,'') as [Driver],
		rtrim(uo.sLast + ', ' + uo.sFirst + ' ' + uo.cMiddle) as [Ordered By],
		isnull(pl.sName,'Unknown') as [User Type],
		r.sName as [Reason],
		isnull(a.szDeliveryLocation,'Unknown') as [Location],
		case when scc.iCntSC = 0 then 0 else 1 end as iCntSC,
		case when scc.iCntBeds = 0 then 0 else 1 end as iCntBeds,
		case when scc.iCntConc = 0 then 0 else 1 end as iCntConc,
		case when scc.iCntLAL  = 0 then 0 else 1 end as iCntLAL,
		case when scc.iCntWC   = 0 then 0 else 1 end as iCntWC,
		isnull(replace(replace(replace(onp.sFullNote,'<br />',''),'<br>',''),char(13) + char(10),''),'') as [Notes]
from ss.tblorder as o
left join ss.tblOrderNotepad as onp on o.iOrderID = onp.iOrderRef 
join ss.tblPatient as p on o.iPatientID = p.iPatientID
left join ss.tblLookup as r on o.cReason = r.sCode and sGroup = 'ORC'
join ss.tblAddress as a on p.iAddressRef = a.iAddressID
join ss.tblLocation as c on p.iClientRef = c.iLocationID
join ss.tblLocation as s on p.iSiteRef = s.iLocationID
join ss.tblCompany as d on s.iCompanyRef = d.iCompanyID
join ss.tblCompany as h on c.iCompanyRef = h.iCompanyID
left join ss.tblUser ud on o.iDriverID = ud.iUserID
left join ss.tblUser uo on o.iOrderedBy = uo.iUserID
left join dbo.UserLocation as ul on ul.Priority = 1 and ul.UserID = uo.iUserID 
left join (select distinct cPyL, sName from ss.tblPyramid_Levels) as pl on pl.cPyL = ul.cType 
join (

		select distinct c.iOrderID as iOID, sum(c.iCntServiceCall) as iCntSC, 
			SUM(c.iCntBeds) as iCntBeds, SUM(c.iCntConc) as iCntConc, SUM(c.iCntLAL) as iCntLAL, SUM(c.iCntWC) as iCntWC
		from (
			select o.iOrderID, 
				case when i.iCategoryRef = 234 then (
						case when i.sName like 'Service Call' then 1 else 0 end
					) else 0 end as iCntServiceCall,
				case when i.iCategoryRef in (130,132,272) then 1 else 0 end as iCntBeds,
				case when i.iCategoryRef in (166,167) then 1 else 0 end as iCntConc,
				case when i.iCategoryRef = 137 then 1 else 0 end as iCntLAL,
				case when i.iCategoryRef in (115,116,117,118,119) then 1 else 0 end as iCntWC
			from ss.tblOrder as o
			join ss.tblOrderDetail as od on o.iOrderID = od.iOrderID 
			join ss.tblProductEquip as pe on od.iProductID = pe.iProductRef 
			join ss.tblEquipment as e on pe.iEquipmentRef = e.iEquipmentID 
			join ss.tblItem as i on i.iItemID = e.iItemRef 
			where o.dtCompleted between @startDate and @EndDate
		) as c
		group by c.iOrderID
	
) as scc on scc.iOID = o.iOrderID 
where d.iCompanyID = @iDME
and o.dtCompleted between @startDate and @EndDate
and o.cTypeID in ('D','P')
and o.cStatusID in ('D','P')
order by [DME SITE], [HOS Client], o.dtCompleted

if @iLimitDataFlag = 0 begin
select 'Details' as info
select sDMESite, sHOSClient, dCompleted, iOID, sDriver, sOrderedBy, sUserType, sReason, sLocation,
	case when iServiceCall = 0 then 'N' else 'Y' end as cCntServiceCall,
	case when iCntBeds = 0 then 'N' else 'Y' end as cCntBeds,
	case when iCntConc = 0 then 'N' else 'Y' end as cCntConc,
	case when iCntLAL  = 0 then 'N' else 'Y' end as cCntLAL,
	case when iCntWC   = 0 then 'N' else 'Y' end as cCntWC,
	case when iCntBeds + iCntConc + iCntLAL + iCntWC = 0 then 'Y' else 'N' end as iCntOther,
	sNotes
from reports_bic.dbo.ServiceCallOrdersWeeklyV2
end

select 'Site Summary' as info
select s.iSID, s.sSite, '' as x, 
	iBeds as iBeds,
	iConc as iConc,
	iLAL as iLAL,
	iWC as iWC,
	iOther as iOther,
	'' as y, 
	cast(cast(case when iServiceCall = 0 then 0 else (iBeds *100.00)/iServiceCall end as numeric(9,2)) as varchar(8)) + '%' as pBeds,
	cast(cast(case when iServiceCall = 0 then 0 else (iConc *100.00)/iServiceCall end as numeric(9,2)) as varchar(8)) + '%' as pConc,
	cast(cast(case when iServiceCall = 0 then 0 else (iLAL  *100.00)/iServiceCall end as numeric(9,2)) as varchar(8)) + '%' as pLAL,
	cast(cast(case when iServiceCall = 0 then 0 else (iWC   *100.00)/iServiceCall end as numeric(9,2)) as varchar(8)) + '%' as pWC,
	cast(cast(case when iServiceCall = 0 then 0 else (iOther*100.00)/iServiceCall end as numeric(9,2)) as varchar(8)) + '%' as pOther,
	'' as z,
	iServiceCall as iServiceCall,
	iTotal as iTotalOrders,
	cast(cast(case when iTotal       = 0 then 0 else (iServiceCall*100.00)/iTotal end as numeric(9,2)) as varchar(8)) + '%' as pServiceCalls,
	     cast(case when iTotal       = 0 then 0 else (iServiceCall*100.00)/iTotal end as numeric(9,2)) as nSCalls
from (
	select iLocationID as iSID, sName as sSite from ss.tblLocation where iCompanyRef = @iDME 
) as s
left join (
	select iSID, sDMESite, SUM(1) as iTotal, SUM(iServiceCall) as iServiceCall,
		isnull(Sum(Case when iServiceCall = 0 then 0 else iCntBeds end),0) as iBeds,
		isnull(Sum(Case when iServiceCall = 0 then 0 else iCntConc end),0) as iConc,
		isnull(Sum(Case when iServiceCall = 0 then 0 else iCntLAL  end),0) as iLAL,
		isnull(Sum(Case when iServiceCall = 0 then 0 else iCntWC   end),0) as iWC,
		isnull(Sum(Case when iServiceCall = 0 then 0 else 
			case when iCntBeds + iCntConc + iCntLAL + iCntWC = 0 then 1 else 0 end
		end),0) as iOther
	from reports_bic.dbo.ServiceCallOrdersWeeklyV2
	group by iSID, sDMESite 
) as x on s.iSID = x.iSID 
order by s.iSID

select 'Company Summary' as info
select 0 as iSID, 'All' as sSite, '' as x, 
	sum(iBeds) as iBeds,
	sum(iConc) as iConc,
	sum(iLAL) as iLAL,
	sum(iWC) as iWC,
	sum(iOther) as iOther,
	'' as y, 
	cast(cast(case when sum(iServiceCall) = 0 then 0 else (sum(iBeds )*100.00)/sum(iServiceCall) end as numeric(9,2)) as varchar(8)) + '%' as pBeds,
	cast(cast(case when sum(iServiceCall) = 0 then 0 else (sum(iConc )*100.00)/sum(iServiceCall) end as numeric(9,2)) as varchar(8)) + '%' as pConc,
	cast(cast(case when sum(iServiceCall) = 0 then 0 else (sum(iLAL  )*100.00)/sum(iServiceCall) end as numeric(9,2)) as varchar(8)) + '%' as pLAL,
	cast(cast(case when sum(iServiceCall) = 0 then 0 else (sum(iWC   )*100.00)/sum(iServiceCall) end as numeric(9,2)) as varchar(8)) + '%' as pWC,
	cast(cast(case when sum(iServiceCall) = 0 then 0 else (sum(iOther)*100.00)/sum(iServiceCall) end as numeric(9,2)) as varchar(8)) + '%' as pOther,
	'' as z,
	sum(iServiceCall) as iServiceCall,
	sum(iTotal) as iTotalOrders,
	cast(cast(case when sum(iTotal     )  = 0 then 0 else (sum(iServiceCall)*100.00)/sum(iTotal) end as numeric(9,2)) as varchar(8)) + '%' as pServiceCalls,
	     cast(case when sum(iTotal     )  = 0 then 0 else (sum(iServiceCall)*100.00)/sum(iTotal) end as numeric(9,2)) as nSCalls
from (
	select iLocationID as iSID, sName as sSite from ss.tblLocation where iCompanyRef = @iDME 
) as s
left join (
	select iSID, sDMESite, SUM(1) as iTotal, SUM(iServiceCall) as iServiceCall,
		isnull(Sum(Case when iServiceCall = 0 then 0 else iCntBeds end),0) as iBeds,
		isnull(Sum(Case when iServiceCall = 0 then 0 else iCntConc end),0) as iConc,
		isnull(Sum(Case when iServiceCall = 0 then 0 else iCntLAL  end),0) as iLAL,
		isnull(Sum(Case when iServiceCall = 0 then 0 else iCntWC   end),0) as iWC,
		isnull(Sum(Case when iServiceCall = 0 then 0 else 
			case when iCntBeds + iCntConc + iCntLAL + iCntWC = 0 then 1 else 0 end
		end),0) as iOther
	from reports_bic.dbo.ServiceCallOrdersWeeklyV2
	group by iSID, sDMESite 
) as x on s.iSID = x.iSID 


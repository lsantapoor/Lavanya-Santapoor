use reports
--use ss
/*--------------------------------------------------------------------------*\
| QA Data for an SRM Report!                                                 |
| Pulls back all data by Client / Site Dyad                                  |
| Groups by National Level = National Top 5, shown by Regions                |
| Groups Top 5 by Region = Each Regions Top 5 Items                          | 
\*--------------------------------------------------------------------------*/
--v2.1 Remove Dyad table, and use windowed budget table.

--Rem out set table windowing as it is not working!

--=[Define what we are looking for]=--
declare @iHOS int, @YYYY int, @MM int, @Span int, @Debug int
set @YYYY = year(getdate()) --Last Year and Month of the data to collect (2013-12 = December as Last month of X Span months)
set @MM = month(getdate())-1
print @MM
set @Span = 3 --Three months of Data
set @iHOS = 136 -- Nathan Adelson Hospice (201602)


--select * from ss.tblCompany where sName like '%Encompass%'
--select * from ss.tblLocation where iCompanyRef = 295



--Get the name of the hospice for extracts later.
declare @sHospice as varchar(128)
select @sHospice = sName from ss.tblCompany where iCompanyID = @iHOS
declare @xDate as date, @sDate as datetime, @eDate as char(10), @nDate as date, @xYYYY as int, @xMM as int, @xYYYYMM as int
set @sDate = cast(@YYYY as varchar(4)) + '-' + cast(@MM as varchar(2)) + '-01 00:00:00.000'
set @xDate = dateadd(ms,-3,DATEADD(m,1,@sDate))
set @eDate = cast(year(@xDate) as char(4)) + '-' + right('0' + cast(month(@xDate) as varchar(2)),2) + '-' + right('0' + cast(Day(@xDate) as varchar(2)),2)
set @sDate = DATEADD(m,-1*(@Span-1),@sDate)
--select @sDate, @xDate, @eDate


--Info to make sure we pulled what we thought we wanted.
select @sHospice as Hospice, cast(@sDate as date) as dS, @eDate as dE

/*exec ss.sp_Report_QACall_Dump YYYY,MM,Span where Span is number of months before YYYYMM you want to range with 1 = current.*/
/*Use the below to fill in A34 to H34 and below, update the SQL with new Date Range, run and cut a lot. Update the values in N24 to N32 and copy over all black cells*/



/*--------------------------------------------------------------------------*\
|   Start of Contract Dyads Pull x by Month                                  |
\*--------------------------------------------------------------------------*/

--Need to lookup the target months active (have DME Days)
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[iceClients]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table dbo.iceClients 
--Create New Temp Table
CREATE TABLE dbo.iceClients (
	iCID int,
	sClient varchar(64),
	sState char(2)
)  ON [PRIMARY]
insert into dbo.iceClients 
select iLocationID, sName, sState from ss.tblLocation where iCompanyRef = @iHOS
select * from dbo.iceClients

--Drop Temp Table
if exists (select * from dbo.sysobjects where id = object_id(N'[ss].[setContractDyad]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table ss.setContractDyad
--Create New Temp Table
CREATE TABLE ss.setContractDyad (
	iYYYY int,
	iMM int,
	iCID int,
	iIPU int,
	iSID int,
	iActivity int,
	iBudget int,
	iContract int,
	iOwner int,
	cType char(3),
	--nClientRate, cCRateType
	--nSiteRate, cSRateType
	cNetworkType char(1)
)  ON [PRIMARY]

CREATE NONCLUSTERED INDEX IX_setContractDyad_iCID   ON ss.setContractDyad (iCID)   ON [PRIMARY]
CREATE NONCLUSTERED INDEX IX_setContractDyad_iIPU   ON ss.setContractDyad (iIPU)   ON [PRIMARY]
CREATE NONCLUSTERED INDEX IX_setContractDyad_iSID   ON ss.setContractDyad (iSID)   ON [PRIMARY]


set @nDate = @sDate
while @nDate < @xDate begin
	--Get Current Date
	select @xYYYY = YEAR(@nDate), @xMM = MONTH(@nDate), @xYYYYMM = YEAR(@nDate) * 100 + MONTH(@nDate)

	--Do the Insert for current month.

	insert into ss.setContractDyad (iYYYY, iMM, iCID, iIPU, iSID, iActivity)
	select distinct @xYYYY, @xMM, iCID, isnull(iIPUID,0) as iIPUID, iSID, 1 as iActivity
	from (
		--Patient List with DME Days
		select * from ss.tblPatient_DayCount
		where YYYY = @xYYYY
		and MM = @xMM
		and iSID > 0 --Hide Master Patients
	) as x

	--Any that are not in DayCount (and have no Activity) Add them anyways
	insert into ss.setContractDyad (iYYYY, iMM, iCID, iIPU, iSID, iActivity)
	select @xYYYY, @xMM, b.iClientRef, isnull(b.iIPURef,0), b.iSiteRef, 0 as iActivity
	from ss.tblBudget as b
	left join ss.setContractDyad as cd on b.iClientRef = cd.iCID and isnull(b.iIPURef,0) = cd.iIPU and b.iSiteRef = cd.iSID 
	where b.iBgnYYYYMM <= @xYYYYMM and ISNULL(b.iEndYYYYMM,299912) >= @xYYYYMM
	and cd.iCID is null

	--Get budget Data
	update ss.setContractDyad 
	set iBudget = b.iBudgetID,
		iContract = b.iContractRef,
		cNetworkType = b.cNetworkType
	from ss.setContractDyad as cd 
	join ss.tblBudget as b on cd.iCID = b.iClientRef and cd.iSID = b.iSiteRef and isnull(cd.iIPU,0) = isnull(b.iIPURef,0)
		and b.iBgnYYYYMM <= @xYYYYMM and isnull(b.iEndYYYYMM,299912) >= @xYYYYMM 
	where cd.iYYYY = @xYYYY and cd.iMM = @xMM

	--IPUs without an IPU Record, default budget data to parent
	update ss.setContractDyad 
	set iBudget = b.iBudgetID,
		iContract = b.iContractRef,
		iActivity = -1, --So we can find them later
		cNetworkType = isnull(cd.cNetworkType, b.cNetworkType)
	--select * 
	from ss.setContractDyad as cd
	join ss.tblBudget as b on cd.iCID = b.iClientRef and cd.iSID = b.iSiteRef 
		and 0 = isnull(b.iIPURef,0) --Get Main non IPU Ref
		and b.iBgnYYYYMM <= @xYYYYMM and isnull(b.iEndYYYYMM,299912) >= @xYYYYMM 
	where cd.iBudget is null --No Budget Record was found at the IPU Level
	and cd.iIPU is not null --But there was an IPU Value, get the main records contract data
	and cd.iYYYY = @xYYYY and cd.iMM = @xMM
	--select * from ss.setContractDyad as cd where iActivity = -1

	 --More date forward a month
	set @nDate = dateadd(m,1,@nDate)
	--Repeate as needed
end

--Get Owner
update ss.setContractDyad 
set iOwner = isnull(c.Owner_iCompanyID,2)
from ss.setContractDyad as d 
left join ss.tblContract as c on d.iContract = c.iContractID 

--Set Contract Type
update ss.setContractDyad 
set cType = case when iOwner = 2 then 'NET' else 'SWC' end

--set B&M
update ss.setContractDyad 
set cType = 'B&M'
where iSID in (
	--B&M Sites
	select iLocationID from ss.tblLocation where iCompanyRef = 2
)
--Show all in DME
--select * from ss.setContractDyad as cd 


--select cNetworkType, SUM(1) as xCnt from ss.setContractDyad as cd group by cNetworkType

/*--------------------------------------------------------------------------*\
|   End of Contract Dyads Pull                                               |
\*--------------------------------------------------------------------------*/



/*--------------------------------------------------------------------------*\
|   Start of Client Dyads Pull                                               |
\*--------------------------------------------------------------------------*/
--Temp table to store our list of Client Site Dyads
declare @Dyad as table (
	iYYYY int,
	iMM int,
	cType char(3),
	iRgn int,
	sRgn varchar(64),
	iCID int,
	sCName varchar(128),
	iSID int,
	sSName varchar(128),
	iDME int,
	sDMEName varchar(128)
)
set @nDate = @sDate
while @nDate < @xDate begin
	--Get Current Date
	select @xYYYY = YEAR(@nDate), @xMM = MONTH(@nDate), @xYYYYMM = YEAR(@nDate) * 100 + MONTH(@nDate)

	--Do the Insert for current month.

	insert into @Dyad (iYYYY, iMM, iRgn, sRgn, iCID, sCName, iSID, sSName, iDME, sDMEName)
	/* Get a List of Clients by Region with Site and DME*/
	select distinct @xYYYY, @xMM, --Need the distinct as we are having issues with closing out set record dates before a new one is added.
		r.isetid as iRegion, isnull(ltrim(rtrim(r.sName)),c.sState + ' Region') as sRegion,
		dy.iClientRef as iCID, c.sName as sClient,
		dy.iSiteRef as iSID, s.sName as sSite,
		d.iCompanyID as iDME, d.sName as sDME
	--from ss.tblDyad as dy
	from ss.tblBudget as dy --v2.1 Remove Dyad table, and use windowed budget table.
	join ss.tblLocation as c on dy.iClientRef = c.iLocationID
	join ss.tblLocation as s on dy.iSiteRef = s.iLocationID
	join ss.tblCompany as d on s.iCompanyRef = d.iCompanyID
	left join ss.tblSet as r on r.iSetId = c.iSetRef
--		and r.iStartYYYYMM <= @xYYYYMM and isnull(r.iEndYYYYMM,299912) >= @xYYYYMM	--Does not have a window of old data even with bn and end dates
	where dy.iClientRef in (
		--select iLocationID from ss.tblLocation where iCompanyRef = @iHOS
		select iCID from dbo.iceClients
	)
	and dy.iBgnYYYYMM <= @xYYYYMM --v2.1 Remove Dyad table, and use windowed budget table.
	and isnull(dy.iEndYYYYMM,299912) >= @xYYYYMM --v2.1 Remove Dyad table, and use windowed budget table.
	--and iClientRef = 466
	order by sRegion, sClient, sSite
	 --More date forward a month
	set @nDate = dateadd(m,1,@nDate)
	--Repeate as needed
end
--select 'Dyad' as info, * from @Dyad 

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
declare @iErrChk as int
select @iErrChk = SUM(1) from @Dyad where iRgn is null
if isnull(@iErrChk,0) <> 0 begin
	select 'ERROR' as info, 'Missing iRGN' as note, * from @Dyad
	where iRgn is null
end

--Get Network Type
update @Dyad
set cType = cd.cType 
from @Dyad as dy
join ss.setContractDyad as cd on cd.iCID = dy.iCID and cd.iIPU = 0 and cd.iSID = dy.iSID 
	and cd.iYYYY = dy.iYYYY and cd.iMM = dy.iMM

--Drop anything that does not map up to the cType (as we do not have data for that month if this is the case
--select SUM(1) as xCnt_all from @Dyad
--delete From @Dyad where cType is null
--select SUM(1) as xCnt_NNull from @Dyad

declare @iBnM_Cnt int, @iNET_Cnt int, @iSWC_Cnt int, @iBNx_Cnt int, @iBxS_Cnt int, @ixNS_Cnt int, @iBNS_Cnt int, @ixxx_Cnt int
select @iBnM_Cnt = SUM(1) from @Dyad where cType = 'B&M'
if ISNULL(@iBnM_Cnt,0) = 0 begin set @iBnM_Cnt = 0 end
select @iNET_Cnt = SUM(1) from @Dyad where cType = 'NET'
if ISNULL(@iNET_Cnt,0) = 0 begin set @iNET_Cnt = 0 end
select @iSWC_Cnt = SUM(1) from @Dyad where cType = 'SWC'
if ISNULL(@iSWC_Cnt,0) = 0 begin set @iSWC_Cnt = 0 end
select @iBNx_Cnt = 0, @iBxS_Cnt = 0, @ixNS_Cnt = 0, @iBNS_Cnt = 0
--select @iBnM_Cnt as iBnM, @iNET_Cnt as iNet, @iSWC_Cnt as iSWC

--Load Mixed Modes as needed
if @iBnM_Cnt <> 0 begin
	if @iNET_Cnt <> 0 begin
		--Merge B&M w/ Network
		insert into @Dyad (iYYYY, iMM, cType, iRgn, sRgn, iCID, sCName, iSID, sSName, iDME, sDMEName)
		select iYYYY, iMM, 'BN-' as cType, iRgn, sRgn, iCID, sCName, iSID, sSName, iDME, sDMEName 
		from @Dyad
		where cType in ('B&M', 'NET')
		--Get Count
		select @iBNx_Cnt = SUM(1) from @Dyad where cType = 'BN-'
	end

	if @iSWC_Cnt <> 0 begin
		--Merge B&M w/ Network
		insert into @Dyad (iYYYY, iMM, cType, iRgn, sRgn, iCID, sCName, iSID, sSName, iDME, sDMEName)
		select iYYYY, iMM, 'B-S' as cType, iRgn, sRgn, iCID, sCName, iSID, sSName, iDME, sDMEName 
		from @Dyad
		where cType in ('B&M', 'SWC')
		--Get Count
		select @iBxS_Cnt = SUM(1) from @Dyad where cType = 'B-S'
	end
end

if @iNET_Cnt <> 0 begin
	if @iSWC_Cnt <> 0 begin
		--Merge B&M w/ Network
		insert into @Dyad (iYYYY, iMM, cType, iRgn, sRgn, iCID, sCName, iSID, sSName, iDME, sDMEName)
		select iYYYY, iMM, '-NS' as cType, iRgn, sRgn, iCID, sCName, iSID, sSName, iDME, sDMEName 
		from @Dyad
		where cType in ('NET', 'SWC')
		--Get Count
		select @ixNS_Cnt = SUM(1) from @Dyad where cType = '-NS'
	end
end

if @iBnM_Cnt <> 0 begin
	if @iNET_Cnt <> 0 begin
		if @iSWC_Cnt <> 0 begin
			--Merge B&M w/ Network
			insert into @Dyad (iYYYY, iMM, cType, iRgn, sRgn, iCID, sCName, iSID, sSName, iDME, sDMEName)
			select iYYYY, iMM, 'BNS' as cType, iRgn, sRgn, iCID, sCName, iSID, sSName, iDME, sDMEName 
			from @Dyad
			where cType in ('B&M', 'NET', 'SWC')
			--Get Count
			select @iBNS_Cnt = SUM(1) from @Dyad where cType = 'BNS'
		end
	end
end

select @ixxx_Cnt = SUM(1) from @Dyad where cType is null
if ISNULL(@ixxx_Cnt,0) = 0 begin set @ixxx_Cnt = 0 end

if @Debug <> 0 begin
	select 'Dyad cType' as info, @iBnM_Cnt as iBnM, @iNET_Cnt as iNet, @iSWC_Cnt as iSWC, @iBNx_Cnt as iBNx, @iBxS_Cnt as iBxS, @ixNS_Cnt as ixNS, @iBNS_Cnt as iBNS, @ixxx_Cnt as iNull
end

/*--------------------------------------------------------------------------*\
|   End of Client Dyads Pull                                                 |
\*--------------------------------------------------------------------------*/






/*--------------------------------------------------------------------------*\
|   Get Billable Equipment For Region by Date                                |
\*--------------------------------------------------------------------------*/

--Lets Get all items by date
Declare @BE_Items as table (
	iYYYY int not null,
	iMM int not null,
	iRgn int not null,
	iCID int not null,
	iSID int not null,
	iItemID int not null,
	nTotal money not null,
	iCnt int not null,
	cType char(3)
)

--Loop the date and insert into our temp table the data
set @nDate = @sDate
while @nDate < @xDate begin
	--Get Current Date
	select @xYYYY = YEAR(@nDate), @xMM = MONTH(@nDate)
	--Do the Insert for current month.
	insert into @BE_Items
	select YYYY, MM, 0 as iRGN, iCID, iSID, iItemID, sum(Total) as nTotal, SUM(1) as xCnt, null as cType
	from ss.tblBillableEquip as be
		join ss.tblEquipment as e on be.iEID = e.iEquipmentID 
		join	 ss.tblItem as i on e.iItemRef = i.iItemID 
		join ss.tblLocation as c on c.iLocationID = be.iCID 
	where iCID in (
			--select iLocationID from ss.tblLocation where iCompanyRef = @iHOS
			select iCID from dbo.iceClients
		)
		and YYYY = @xYYYY
		and MM = @xMM
		and Total <> 0 --Drop zero Records
	group by YYYY, MM, iCID, iSID, iItemID
	--More date forward a month
	set @nDate = dateadd(m,1,@nDate)
	--Repeate as needed
end

--Get Network Type
--update @BE_Items
--set cType = cd.cType 
--from @BE_Items as be
--join ss.setContractDyad as cd on cd.iCID = be.iCID and cd.iIPU = 0 and cd.iSID = be.iSID 
--	and cd.iYYYY = be.YYYY and cd.iMM = be.MM

--select SUM(1) as xCnt_ALL from @BE_Items --17872
delete from @BE_Items where nTotal = 0 --Some items sum 2 zero (pos-neg=0) drop these as well.
--select SUM(1) as xCnt from @BE_Items --3382

--Get Contract Type
update @BE_Items
set cType = d.cType 
from @BE_Items as be
join @Dyad as d on d.iCID = be.iCID and d.iSID = be.iSID 
	and d.iYYYY = be.iYYYY and d.iMM = be.iMM
where d.cType in ('B&M','NET','SWC') --Only Use the basic types currently

select @iBnM_Cnt = SUM(1) from @BE_Items where cType = 'B&M'
if ISNULL(@iBnM_Cnt,0) = 0 begin set @iBnM_Cnt = 0 end
select @iNET_Cnt = SUM(1) from @BE_Items where cType = 'NET'
if ISNULL(@iNET_Cnt,0) = 0 begin set @iNET_Cnt = 0 end
select @iSWC_Cnt = SUM(1) from @BE_Items where cType = 'SWC'
if ISNULL(@iSWC_Cnt,0) = 0 begin set @iSWC_Cnt = 0 end
select @iBNx_Cnt = 0, @iBxS_Cnt = 0, @ixNS_Cnt = 0, @iBNS_Cnt = 0
--select @iBnM_Cnt as iBnM, @iNET_Cnt as iNet, @iSWC_Cnt as iSWC

--Load Mixed Modes as needed
if @iBnM_Cnt <> 0 begin
	if @iNET_Cnt <> 0 begin
		--Merge B&M w/ Network
		insert into @BE_Items (iYYYY, iMM, iRGN, iCID, iSID, iItemID, nTotal, iCnt, cType)
		select iYYYY, iMM, iRGN, iCID, iSID, iItemID, nTotal, iCnt, 'BN-' as cType
		from @BE_Items
		where cType in ('B&M', 'NET')
		--Get Count
		select @iBNx_Cnt = SUM(1) from @BE_Items where cType = 'BN-'
	end

	if @iSWC_Cnt <> 0 begin
		--Merge B&M w/ Network
		insert into @BE_Items (iYYYY, iMM, iRGN, iCID, iSID, iItemID, nTotal, iCnt, cType)
		select iYYYY, iMM, iRGN, iCID, iSID, iItemID, nTotal, iCnt, 'B-S' as cType
		from @BE_Items
		where cType in ('B&M', 'SWC')
		--Get Count
		select @iBxS_Cnt = SUM(1) from @BE_Items where cType = 'B-S'
	end
end

if @iNET_Cnt <> 0 begin
	if @iSWC_Cnt <> 0 begin
		--Merge B&M w/ Network
		insert into @BE_Items (iYYYY, iMM, iRGN, iCID, iSID, iItemID, nTotal, iCnt, cType)
		select iYYYY, iMM, iRGN, iCID, iSID, iItemID, nTotal, iCnt, '-NS' as cType
		from @BE_Items
		where cType in ('NET', 'SWC')
		--Get Count
		select @ixNS_Cnt = SUM(1) from @BE_Items where cType = '-NS'
	end
end

if @iBnM_Cnt <> 0 begin
	if @iNET_Cnt <> 0 begin
		if @iSWC_Cnt <> 0 begin
			--Merge B&M w/ Network
			insert into @BE_Items (iYYYY, iMM, iRGN, iCID, iSID, iItemID, nTotal, iCnt, cType)
			select iYYYY, iMM, iRGN, iCID, iSID, iItemID, nTotal, iCnt, 'BNS' as cType
			from @BE_Items
			where cType in ('B&M', 'NET', 'SWC')
			--Get Count
			select @iBNS_Cnt = SUM(1) from @BE_Items where cType = 'BNS'
		end
	end
end

select @ixxx_Cnt = SUM(1) from @BE_Items where cType is null
if ISNULL(@ixxx_Cnt,0) = 0 begin set @ixxx_Cnt = 0 end

if @Debug <> 0 begin
	select 'BE Items cType' as info, @iBnM_Cnt as iBnM, @iNET_Cnt as iNet, @iSWC_Cnt as iSWC, @iBNx_Cnt as iBNx, @iBxS_Cnt as iBxS, @ixNS_Cnt as ixNS, @iBNS_Cnt as iBNS, @ixxx_Cnt as iNull
end



--need to assign region data based on date of record.
update @BE_Items
set iRgn = dy.iRgn
from @BE_Items as be 
join @Dyad as dy on be.iCID = dy.iCID and be.iSID = dy.iSID 
	and be.iYYYY = dy.iYYYY and be.iMM = dy.iMM 

--If no Region it is likly a client edit without a site id. Or site ID changed in budget record?
select @iErrChk = SUM(1) from @BE_Items as be join ss.tblItem as i on be.iItemID = i.iItemID where iRgn = 0
if isnull(@iErrChk,0) <> 0 begin
	select 'ERROR' as info, 'Items No Rgn - bad missing dyad' as note, i.sName, be.* 
	from @BE_Items as be
	join ss.tblItem as i on be.iItemID = i.iItemID
	where iRgn = 0
	--Debug this
	/*
	declare @xY as int = 2014
	declare @xM as int = 11
	declare @xCID as int = 2626
	declare @xSID as int = 2630
	declare @xSD as datetime = cast(@xY as char(4)) + '-' + right('0' + cast(@xM as varchar(2)),2) + '-01'
	declare @xED as datetime = DATEADD(ms,-3,DATEADD(m,1,@xSD))
	--Dyad
	select * from @Dyad where iCID = @xCID
	--Budget
	select * from ss.tblBudget where iClientRef = @xCID
	--Order Details
	select p.iClientRef, p.iSiteRef, od.* 
	from ss.tblOrderDetail as od
	join ss.tblOrder as o on od.iOrderID = o.iOrderID
	join ss.tblPatient as p on p.iPatientID = p.iPatientID
	where iClientRef = @xCID
	and iSiteRef = @xSID
	and dtCheckOut >= @xSD and dtCheckOut <= @xED
	*/
end



/*--------------------------------------------------------------------------*\
|   Start of National Top 5 Data by Contract Types                           |
\*--------------------------------------------------------------------------*/

--declare @iTop int = 5

declare @top5 table (
	iYYYY int, iMM int, cType char(3), cScope char(1),	
	cPyramid char(1), iLvl int, iRgn int,
	iItemID int, nTotal money, nFFS money
)
insert into @top5
--Brick and Mortar
select top 5
	0, 0, cType, 'N', 'N', 10, 0 as iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
from @BE_Items as be
where cType = 'B&M'
group by iItemID, cType
order by nTotal desc

insert into @top5
--Network
select top 5
	0, 0, cType, 'N', 'N', 10, 0 as iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
from @BE_Items as be
where cType = 'NET'
group by iItemID, cType
order by nTotal desc

insert into @top5
--Soft Ware Client
select top 5
	0, 0, cType, 'N', 'N', 10, 0 as iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
from @BE_Items as be
where cType = 'SWC'
group by iItemID, cType
order by nTotal desc

insert into @top5
--Brick and Mortar + Network
select top 5
	0, 0, 'BN-' as cType, 'N', 'N', 10, 0 as iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
from @BE_Items as be
where cType = 'BN-'-- in ('B&M', 'NET') 
group by iItemID
order by nTotal desc

insert into @top5
--Brick and Mortar + Soft Ware Client
select top 5
	0, 0, 'B-S' as cType, 'N', 'N', 10, 0 as iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
from @BE_Items as be
where cType = 'B-S'
group by iItemID
order by nTotal desc

insert into @top5
--Network + Soft Ware Client
select top 5
	0, 0, '-NS' as cType, 'N', 'N', 10, 0 as iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
from @BE_Items as be
where cType = '-NS'
group by iItemID
order by nTotal desc

insert into @top5
--Brick and Mortar + Network + Soft Ware Client
select top 5
	0, 0, 'BNS' as cType, 'N', 'N', 10, 0 as iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
from @BE_Items as be
where cType = 'BNS' -- in ('B&M', 'NET', 'SWC') 
group by iItemID
order by nTotal desc


--Update the Totals for the same range. (B&M, NET, SWC, BN-, B-S, -NS, BNS)
update @top5
set nFFS = x.nFFS
from @top5 as t5
join (
	select cType, SUM(nTotal) as nFFS
	from @BE_Items as be
	group by cType
) as x on t5.cType = x.cType

if @Debug <> 0 begin

	select @iBnM_Cnt = SUM(1) from @top5 where cType = 'B&M' and cScope = 'N' and cPyramid = 'N'
	if ISNULL(@iBnM_Cnt,0) = 0 begin set @iBnM_Cnt = 0 end
	select @iNET_Cnt = SUM(1) from @top5 where cType = 'NET' and cScope = 'N' and cPyramid = 'N'
	if ISNULL(@iNET_Cnt,0) = 0 begin set @iNET_Cnt = 0 end
	select @iSWC_Cnt = SUM(1) from @top5 where cType = 'SWC' and cScope = 'N' and cPyramid = 'N'
	if ISNULL(@iSWC_Cnt,0) = 0 begin set @iSWC_Cnt = 0 end

	select @iBNx_Cnt = SUM(1) from @top5 where cType = 'BN-' and cScope = 'N' and cPyramid = 'N'
	if ISNULL(@iBNx_Cnt,0) = 0 begin set @iBNx_Cnt = 0 end
	select @iBxS_Cnt = SUM(1) from @top5 where cType = 'B-S' and cScope = 'N' and cPyramid = 'N'
	if ISNULL(@iBxS_Cnt,0) = 0 begin set @iBxS_Cnt = 0 end
	select @ixNS_Cnt = SUM(1) from @top5 where cType = '-NS' and cScope = 'N' and cPyramid = 'N'
	if ISNULL(@ixNS_Cnt,0) = 0 begin set @ixNS_Cnt = 0 end

	select @iBNS_Cnt = SUM(1) from @top5 where cType = 'BNS' and cScope = 'N' and cPyramid = 'N'
	if ISNULL(@iBNS_Cnt,0) = 0 begin set @iBNS_Cnt = 0 end

	select @ixxx_Cnt = SUM(1) from @top5 where cType is null and cScope = 'N' and cPyramid = 'N'
	if ISNULL(@ixxx_Cnt,0) = 0 begin set @ixxx_Cnt = 0 end

	select 'Top 5 cType (NN)' as info, @iBnM_Cnt as iBnM, @iNET_Cnt as iNet, @iSWC_Cnt as iSWC, @iBNx_Cnt as iBNx, @iBxS_Cnt as iBxS, @ixNS_Cnt as ixNS, @iBNS_Cnt as iBNS, @ixxx_Cnt as iNull
end

--Select * from @top5

--Get Regional Data for National Top 5 Data
insert into @top5
select 
	be.iYYYY, be.iMM, t5.cType, 'N', 'R', 20, be.iRgn, t5.iItemID, SUM(isnull(be.nTotal,0)) as nTotal, 0 as nFFS
from (select cType, iItemID from @top5) as t5
left join @BE_Items as be on t5.cType = be.cType and t5.iItemID = be.iItemID
group by be.iYYYY, be.iMM, t5.iItemID, t5.cType, be.iRgn
order by nTotal desc

--Update the Totals for the same range.
update @top5
set nFFS = x.nFFS
from @top5 as t5
join (
	select cType, iRgn, iYYYY, iMM, SUM(nTotal) as nFFS
	from @BE_Items as be
	group by cType, iRgn, iYYYY, iMM
) as x on t5.cType = x.cType and t5.iRgn = x.iRgn and t5.iYYYY = x.iYYYY and t5.iMM = x.iMM
where t5.cScope = 'N' and t5.cPyramid = 'R'

if @Debug <> 0 begin

	select @iBnM_Cnt = SUM(1) from @top5 where cType = 'B&M' and cScope = 'N' and cPyramid = 'R'
	if ISNULL(@iBnM_Cnt,0) = 0 begin set @iBnM_Cnt = 0 end
	select @iNET_Cnt = SUM(1) from @top5 where cType = 'NET' and cScope = 'N' and cPyramid = 'R'
	if ISNULL(@iNET_Cnt,0) = 0 begin set @iNET_Cnt = 0 end
	select @iSWC_Cnt = SUM(1) from @top5 where cType = 'SWC' and cScope = 'N' and cPyramid = 'R'
	if ISNULL(@iSWC_Cnt,0) = 0 begin set @iSWC_Cnt = 0 end

	select @iBNx_Cnt = SUM(1) from @top5 where cType = 'BN-' and cScope = 'N' and cPyramid = 'R'
	if ISNULL(@iBNx_Cnt,0) = 0 begin set @iBNx_Cnt = 0 end
	select @iBxS_Cnt = SUM(1) from @top5 where cType = 'B-S' and cScope = 'N' and cPyramid = 'R'
	if ISNULL(@iBxS_Cnt,0) = 0 begin set @iBxS_Cnt = 0 end
	select @ixNS_Cnt = SUM(1) from @top5 where cType = '-NS' and cScope = 'N' and cPyramid = 'R'
	if ISNULL(@ixNS_Cnt,0) = 0 begin set @ixNS_Cnt = 0 end

	select @iBNS_Cnt = SUM(1) from @top5 where cType = 'BNS' and cScope = 'N' and cPyramid = 'R'
	if ISNULL(@iBNS_Cnt,0) = 0 begin set @iBNS_Cnt = 0 end

	select @ixxx_Cnt = SUM(1) from @top5 where cType is null and cScope = 'N' and cPyramid = 'R'
	if ISNULL(@ixxx_Cnt,0) = 0 begin set @ixxx_Cnt = 0 end

	select 'Top 5 cType (NR)' as info, @iBnM_Cnt as iBnM, @iNET_Cnt as iNet, @iSWC_Cnt as iSWC, @iBNx_Cnt as iBNx, @iBxS_Cnt as iBxS, @ixNS_Cnt as ixNS, @iBNS_Cnt as iBNS, @ixxx_Cnt as iNull

end

--select * from @top5 as t5 where t5.cScope = 'N' and t5.cPyramid = 'R'

/*
select * from @top5
where cType = 'B&M'
--and t5.cScope = 'N' and t5.cPyramid = 'R'
order by iItemID, iRgn, iYYYY * 100 + iMM
*/


----Lets get a place to store QA Data we are dumpping out by Dyad.
--declare @QA_Dump as table (
--	oid int
--)


/*--------------------------------------------------------------------------*\
|   Start of Regional Top 5 Data by Contract Types                           |
\*--------------------------------------------------------------------------*/

--select * from @BE_Items where iRgn = 0





--Cursor Loop
--Declare Loop Vars
DECLARE @z_iRgn int
--Declare Cursor
DECLARE rgn_cursor CURSOR FOR
--Select Loop Data
select Distinct iRgn from @BE_Items order by iRgn
--Open Loop
OPEN rgn_cursor
-- Perform the first fetch and store the values in variables.
FETCH NEXT FROM rgn_cursor INTO @z_iRgn
-- Check @@FETCH_STATUS to see if there are any more rows to fetch.
WHILE @@FETCH_STATUS = 0
BEGIN
	--Do Stuff
	--Get Regional Data for National Top 5 Data

	insert into @top5
	select top 5
		0, 0, be.cType, 'R', 'X', 10, iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
	from @BE_Items as be
	where cType = 'B&M'
	and be.iRgn = @z_iRgn
	group by iItemID, cType, iRgn
	order by nTotal desc

	insert into @top5
	select top 5
		0, 0, cType, 'R', 'X', 10, iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
	from @BE_Items as be
	where cType = 'NET'
	and be.iRgn = @z_iRgn
	group by iItemID, cType, iRgn
	order by nTotal desc

	insert into @top5
	select top 5
		0, 0, cType, 'R', 'X', 10, iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
	from @BE_Items as be
	where cType = 'SWC'
	and be.iRgn = @z_iRgn
	group by iItemID, cType, iRgn
	order by nTotal desc

	insert into @top5
	select top 5
		0, 0, cType, 'R', 'X', 10, iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
	from @BE_Items as be
	where cType = 'BN-'
	and be.iRgn = @z_iRgn
	group by iItemID, cType, iRgn
	order by nTotal desc

	insert into @top5
	select top 5
		0, 0, cType, 'R', 'X', 10, iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
	from @BE_Items as be
	where cType = 'B-S'
	and be.iRgn = @z_iRgn
	group by iItemID, cType, iRgn
	order by nTotal desc
	
	insert into @top5
	select top 5
		0, 0, cType, 'R', 'X', 10, iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
	from @BE_Items as be
	where cType = '-NS'
	and be.iRgn = @z_iRgn
	group by iItemID, cType, iRgn
	order by nTotal desc
	
	insert into @top5
	select top 5
		0, 0, cType, 'R', 'X', 10, iRgn, iItemID, SUM(nTotal) as nTotal, 0 as nFFS
	from @BE_Items as be
	where cType = 'BNS'
	and be.iRgn = @z_iRgn
	group by iItemID, cType, iRgn
	order by nTotal desc
				
	-- This is executed as long as the previous fetch succeeds.
   	FETCH NEXT FROM rgn_cursor INTO @z_iRgn
END
--Close the loop
CLOSE rgn_cursor
DEALLOCATE rgn_cursor

--Update the Totals for the same range.
update @top5
set nFFS = x.nFFS
from @top5 as t5
join (
	select cType, iRgn, SUM(nTotal) as nFFS
	from @BE_Items as be
	group by cType, iRgn
) as x on t5.cType = x.cType and t5.iRgn = x.iRgn
where t5.cScope = 'R' and t5.cPyramid = 'X'

if @Debug <> 0 begin

	select @iBnM_Cnt = SUM(1) from @top5 where cType = 'B&M' and cScope = 'R' and cPyramid = 'X'
	if ISNULL(@iBnM_Cnt,0) = 0 begin set @iBnM_Cnt = 0 end
	select @iNET_Cnt = SUM(1) from @top5 where cType = 'NET' and cScope = 'R' and cPyramid = 'X'
	if ISNULL(@iNET_Cnt,0) = 0 begin set @iNET_Cnt = 0 end
	select @iSWC_Cnt = SUM(1) from @top5 where cType = 'SWC' and cScope = 'R' and cPyramid = 'X'
	if ISNULL(@iSWC_Cnt,0) = 0 begin set @iSWC_Cnt = 0 end

	select @iBNx_Cnt = SUM(1) from @top5 where cType = 'BN-' and cScope = 'R' and cPyramid = 'X'
	if ISNULL(@iBNx_Cnt,0) = 0 begin set @iBNx_Cnt = 0 end
	select @iBxS_Cnt = SUM(1) from @top5 where cType = 'B-S' and cScope = 'R' and cPyramid = 'X'
	if ISNULL(@iBxS_Cnt,0) = 0 begin set @iBxS_Cnt = 0 end
	select @ixNS_Cnt = SUM(1) from @top5 where cType = '-NS' and cScope = 'R' and cPyramid = 'X'
	if ISNULL(@ixNS_Cnt,0) = 0 begin set @ixNS_Cnt = 0 end

	select @iBNS_Cnt = SUM(1) from @top5 where cType = 'BNS' and cScope = 'R' and cPyramid = 'X'
	if ISNULL(@iBNS_Cnt,0) = 0 begin set @iBNS_Cnt = 0 end

	select @ixxx_Cnt = SUM(1) from @top5 where cType is null and cScope = 'R' and cPyramid = 'X'
	if ISNULL(@ixxx_Cnt,0) = 0 begin set @ixxx_Cnt = 0 end

	select 'Top 5 cType (RX)' as info, @iBnM_Cnt as iBnM, @iNET_Cnt as iNet, @iSWC_Cnt as iSWC, @iBNx_Cnt as iBNx, @iBxS_Cnt as iBxS, @ixNS_Cnt as ixNS, @iBNS_Cnt as iBNS, @ixxx_Cnt as iNull

end



/*
select * from @top5
where cType = 'B&M'
and cScope = 'R' and cPyramid = 'X'
order by iItemID, iRgn, iYYYY * 100 + iMM
*/
	
insert into @top5
select 
	be.iYYYY, be.iMM, t5.cType, 'R', 'R', 20, t5.iRgn, t5.iItemID, SUM(isnull(be.nTotal,0)) as nTotal, 0 as nFFS
from (select cType, iItemID, iRgn from @top5 where cScope = 'R') as t5
left join @BE_Items as be on t5.cType = be.cType and t5.iItemID = be.iItemID and t5.iRgn = be.iRgn 
where t5.iRgn <> 0
group by be.iYYYY, be.iMM, t5.iItemID, t5.cType, t5.iRgn
order by nTotal desc

update @top5
set nFFS = x.nFFS
from @top5 as t5
join (
	select cType, iRgn, iYYYY, iMM, SUM(nTotal) as nFFS
	from @BE_Items as be
	group by cType, iRgn, iYYYY, iMM
) as x on t5.cType = x.cType and t5.iRgn = x.iRgn and t5.iYYYY = x.iYYYY and t5.iMM = x.iMM
where t5.cScope = 'R' and t5.cPyramid = 'R'

if @Debug <> 0 begin

	select @iBnM_Cnt = SUM(1) from @top5 where cType = 'B&M' and cScope = 'R' and cPyramid = 'R'
	if ISNULL(@iBnM_Cnt,0) = 0 begin set @iBnM_Cnt = 0 end
	select @iNET_Cnt = SUM(1) from @top5 where cType = 'NET' and cScope = 'R' and cPyramid = 'R'
	if ISNULL(@iNET_Cnt,0) = 0 begin set @iNET_Cnt = 0 end
	select @iSWC_Cnt = SUM(1) from @top5 where cType = 'SWC' and cScope = 'R' and cPyramid = 'R'
	if ISNULL(@iSWC_Cnt,0) = 0 begin set @iSWC_Cnt = 0 end

	select @iBNx_Cnt = SUM(1) from @top5 where cType = 'BN-' and cScope = 'R' and cPyramid = 'R'
	if ISNULL(@iBNx_Cnt,0) = 0 begin set @iBNx_Cnt = 0 end
	select @iBxS_Cnt = SUM(1) from @top5 where cType = 'B-S' and cScope = 'R' and cPyramid = 'R'
	if ISNULL(@iBxS_Cnt,0) = 0 begin set @iBxS_Cnt = 0 end
	select @ixNS_Cnt = SUM(1) from @top5 where cType = '-NS' and cScope = 'R' and cPyramid = 'R'
	if ISNULL(@ixNS_Cnt,0) = 0 begin set @ixNS_Cnt = 0 end

	select @iBNS_Cnt = SUM(1) from @top5 where cType = 'BNS' and cScope = 'R' and cPyramid = 'R'
	if ISNULL(@iBNS_Cnt,0) = 0 begin set @iBNS_Cnt = 0 end

	select @ixxx_Cnt = SUM(1) from @top5 where cType is null and cScope = 'R' and cPyramid = 'R'
	if ISNULL(@ixxx_Cnt,0) = 0 begin set @ixxx_Cnt = 0 end

	select 'Top 5 cType (RR)' as info, @iBnM_Cnt as iBnM, @iNET_Cnt as iNet, @iSWC_Cnt as iSWC, @iBNx_Cnt as iBNx, @iBxS_Cnt as iBxS, @ixNS_Cnt as ixNS, @iBNS_Cnt as iBNS, @ixxx_Cnt as iNull

end

/*
select * from @top5
where cType = 'B&M'
and cScope = 'R'
order by iRgn, iItemID, iYYYY * 100 + iMM
*/

/*
select * from @top5
where cType = 'B&M'
and cScope = 'R' and cPyramid = 'R'
order by iRgn, iItemID, iYYYY * 100 + iMM
*/


/*--------------------------------------------------------------------------*\
|   Start of Rollup of the Data                                              |
\*--------------------------------------------------------------------------*/

--m#Lbl char(7)			= "YYYY-MM" Label for this Report
--m#Ttl money			= nTotal for this month
--m#FFS money			= nFFS for this month
--m#APD int				= Acting Patient Days (not currently pulled)
--m#Per numeric(5,2)	= Percent of FFS this item makes up
--m#CPD money			= Cost per acting Patient Day (not currently calculated)
declare @Rollup as table (
	cType char(3), iRgn int, sRgn varchar(128), cScope char(1), cPyramid char(1), iItemID int, 
	m1Lbl char(7), m1Ttl money, m1FFS money, m1APD int, m1Per numeric(4,3), m1CPD money,
	m2Lbl char(7), m2Ttl money, m2FFS money, m2APD int, m2Per numeric(4,3), m2CPD money,
	m3Lbl char(7), m3Ttl money, m3FFS money, m3APD int, m3Per numeric(4,3), m3CPD money,
	m4Lbl char(7), m4Ttl money, m4FFS money, m4APD int, m4Per numeric(4,3), m4CPD money,
	m5Lbl char(7), m5Ttl money, m5FFS money, m5APD int, m5Per numeric(4,3), m5CPD money,
	m6Lbl char(7), m6Ttl money, m6FFS money, m6APD int, m6Per numeric(4,3), m6CPD money,
	sItemName varchar(128), mXTtl money --All Months Ttl for Sorting
)
--Get base data for the Rollup Table.
insert into @Rollup (cType, iRgn, sRgn, cScope, cPyramid, iItemID) 
--All Regions
select distinct rgn.cType, rgn.iRgn, rgn.sRgn, t5.cScope, t5.cPyramid, t5.iItemID
from (
	select distinct cType, iRgn, sRgn from @Dyad
	where cType is not null --Drop empty data sets
) as rgn
left join (
	select cType, iRgn, cScope, cPyramid, iItemID from @top5
) as t5 on t5.iRgn = rgn.iRgn and t5.cType = rgn.cType
order by rgn.cType, rgn.iRgn, cScope, cPyramid

--Load National which has no Region Data
insert into @Rollup (cType, iRgn, sRgn, cScope, cPyramid, iItemID) 
--All Regions
select distinct rgn.cType, rgn.iRgn, rgn.sRgn, t5.cScope, t5.cPyramid, t5.iItemID
from (
	select distinct cType, 0 as iRgn, 'National: All Regions' as sRgn from @Dyad
	where cType is not null --Drop empty data sets
) as rgn
left join (
	select cType, cScope, cPyramid, iItemID from @top5
) as t5 on t5.cType = rgn.cType and t5.cScope = 'N' and t5.cPyramid = 'N'
order by rgn.cType, rgn.iRgn, cScope, cPyramid

--select 'A'; select * from @Rollup where cScope = 'N' and cPyramid = 'N'
	
--Start pulling each month into the table.

set @nDate = @sDate
--Get Month 1
select @xYYYY = YEAR(@nDate), @xMM = MONTH(@nDate)
	
--Do the Insert for Month 1
update @Rollup set 
	m1Lbl = isnull(x.m_Lbl,CAST(@xYYYY as CHAR(4)) + '-' + right('0' + CAST(@xMM as varchar(2)),2) ),
	m1Ttl = isnull(x.m_Ttl,0), 
	m1FFS = isnull(x.m_FFS,0), 
	m1APD = x.m_APD, 
	m1Per = isnull(x.m_Per,0), 
	m1CPD = x.m_CPD
from @Rollup as ru
left join (
	select 
		r.cType, r.iRgn, r.cScope, r.cPyramid, r.iItemID, d.m_Lbl, d.m_Ttl, d.m_FFS, d.m_APD, d.m_Per, d.m_CPD
	from (
		select cType, iRgn, cScope, cPyramid, iItemID from @Rollup
	) as r
	join (
		select rgn.cType, rgn.iRgn, t5.cScope, t5.cPyramid, t5.iItemID,
			CAST(t5.iYYYY as CHAR(4)) + '-' + right('0' + CAST(t5.iMM as varchar(2)),2) as m_Lbl,
			isnull(t5.nTotal,0) as m_Ttl, isnull(t5.nFFS,0) as m_FFS, null as m_APD, 
			cast(ROUND(case when isnull(t5.nFFS,0) = 0 then 0 else isnull(t5.nTotal,0) / isnull(t5.nFFS,0) end, 3) as numeric(4,3)) as m_Per, 
			null as m_CPD
		from (
			select distinct cType, iRgn, sRgn from @Dyad
			where cType is not null --Drop empty data sets
		) as rgn
		left join (
			select cType, iRgn, cScope, cPyramid, iItemID, iYYYY, iMM, nTotal, nFFS 
			from @top5
		) as t5 on t5.iRgn = rgn.iRgn and t5.cType = rgn.cType
		where t5.iYYYY = @xYYYY and t5.iMM = @xMM
	) as d on r.cType = d.cType and r.iRgn = d.iRgn and r.cScope = d.cScope 
		and r.cPyramid = d.cPyramid and r.iItemID = d.iItemID
) as x on ru.cType = x.cType and ru.iRgn = x.iRgn and ru.cScope = x.cScope 
	and ru.cPyramid = x.cPyramid and ru.iItemID = x.iItemID


--More date forward a month
set @nDate = dateadd(m,1,@nDate)
--Get Month 2
select @xYYYY = YEAR(@nDate), @xMM = MONTH(@nDate)

--Do the Insert for Month 2
update @Rollup set 
	m2Lbl = isnull(x.m_Lbl,CAST(@xYYYY as CHAR(4)) + '-' + right('0' + CAST(@xMM as varchar(2)),2) ),
	m2Ttl = isnull(x.m_Ttl,0), 
	m2FFS = isnull(x.m_FFS,0), 
	m2APD = x.m_APD, 
	m2Per = isnull(x.m_Per,0), 
	m2CPD = x.m_CPD
from @Rollup as ru
left join (
	select 
		r.cType, r.iRgn, r.cScope, r.cPyramid, r.iItemID, d.m_Lbl, d.m_Ttl, d.m_FFS, d.m_APD, d.m_Per, d.m_CPD
	from (
		select cType, iRgn, cScope, cPyramid, iItemID from @Rollup
	) as r
	join (
		select rgn.cType, rgn.iRgn, t5.cScope, t5.cPyramid, t5.iItemID,
			CAST(t5.iYYYY as CHAR(4)) + '-' + right('0' + CAST(t5.iMM as varchar(2)),2) as m_Lbl,
			isnull(t5.nTotal,0) as m_Ttl, isnull(t5.nFFS,0) as m_FFS, null as m_APD, 
			cast(ROUND(case when isnull(t5.nFFS,0) = 0 then 0 else isnull(t5.nTotal,0) / isnull(t5.nFFS,0) end, 3) as numeric(4,3)) as m_Per, 
			null as m_CPD
		from (
			select distinct cType, iRgn, sRgn from @Dyad
			where cType is not null --Drop empty data sets
		) as rgn
		left join (
			select cType, iRgn, cScope, cPyramid, iItemID, iYYYY, iMM, nTotal, nFFS 
			from @top5
		) as t5 on t5.iRgn = rgn.iRgn and t5.cType = rgn.cType
		where t5.iYYYY = @xYYYY and t5.iMM = @xMM
	) as d on r.cType = d.cType and r.iRgn = d.iRgn and r.cScope = d.cScope 
		and r.cPyramid = d.cPyramid and r.iItemID = d.iItemID
) as x on ru.cType = x.cType and ru.iRgn = x.iRgn and ru.cScope = x.cScope 
	and ru.cPyramid = x.cPyramid and ru.iItemID = x.iItemID


--More date forward a month
set @nDate = dateadd(m,1,@nDate)
--Get Month 3
select @xYYYY = YEAR(@nDate), @xMM = MONTH(@nDate)

--Do the Insert for Month 3
update @Rollup set 
	m3Lbl = isnull(x.m_Lbl,CAST(@xYYYY as CHAR(4)) + '-' + right('0' + CAST(@xMM as varchar(2)),2) ),
	m3Ttl = isnull(x.m_Ttl,0), 
	m3FFS = isnull(x.m_FFS,0), 
	m3APD = x.m_APD, 
	m3Per = isnull(x.m_Per,0), 
	m3CPD = x.m_CPD
from @Rollup as ru
left join (
	select 
		r.cType, r.iRgn, r.cScope, r.cPyramid, r.iItemID, d.m_Lbl, d.m_Ttl, d.m_FFS, d.m_APD, d.m_Per, d.m_CPD
	from (
		select cType, iRgn, cScope, cPyramid, iItemID from @Rollup
	) as r
	join (
		select rgn.cType, rgn.iRgn, t5.cScope, t5.cPyramid, t5.iItemID,
			CAST(t5.iYYYY as CHAR(4)) + '-' + right('0' + CAST(t5.iMM as varchar(2)),2) as m_Lbl,
			isnull(t5.nTotal,0) as m_Ttl, isnull(t5.nFFS,0) as m_FFS, null as m_APD, 
			cast(ROUND(case when isnull(t5.nFFS,0) = 0 then 0 else isnull(t5.nTotal,0) / isnull(t5.nFFS,0) end, 3) as numeric(4,3)) as m_Per, 
			null as m_CPD
		from (
			select distinct cType, iRgn, sRgn from @Dyad
			where cType is not null --Drop empty data sets
		) as rgn
		left join (
			select cType, iRgn, cScope, cPyramid, iItemID, iYYYY, iMM, nTotal, nFFS 
			from @top5
		) as t5 on t5.iRgn = rgn.iRgn and t5.cType = rgn.cType
		where t5.iYYYY = @xYYYY and t5.iMM = @xMM
	) as d on r.cType = d.cType and r.iRgn = d.iRgn and r.cScope = d.cScope 
		and r.cPyramid = d.cPyramid and r.iItemID = d.iItemID
) as x on ru.cType = x.cType and ru.iRgn = x.iRgn and ru.cScope = x.cScope 
	and ru.cPyramid = x.cPyramid and ru.iItemID = x.iItemID


--More date forward a month
set @nDate = dateadd(m,1,@nDate)
--Get Month 4
select @xYYYY = YEAR(@nDate), @xMM = MONTH(@nDate)

--Do the Insert for Month 4
update @Rollup set 
	m4Lbl = isnull(x.m_Lbl,CAST(@xYYYY as CHAR(4)) + '-' + right('0' + CAST(@xMM as varchar(2)),2) ),
	m4Ttl = isnull(x.m_Ttl,0), 
	m4FFS = isnull(x.m_FFS,0), 
	m4APD = x.m_APD, 
	m4Per = isnull(x.m_Per,0), 
	m4CPD = x.m_CPD
from @Rollup as ru
left join (
	select 
		r.cType, r.iRgn, r.cScope, r.cPyramid, r.iItemID, d.m_Lbl, d.m_Ttl, d.m_FFS, d.m_APD, d.m_Per, d.m_CPD
	from (
		select cType, iRgn, cScope, cPyramid, iItemID from @Rollup
	) as r
	join (
		select rgn.cType, rgn.iRgn, t5.cScope, t5.cPyramid, t5.iItemID,
			CAST(t5.iYYYY as CHAR(4)) + '-' + right('0' + CAST(t5.iMM as varchar(2)),2) as m_Lbl,
			isnull(t5.nTotal,0) as m_Ttl, isnull(t5.nFFS,0) as m_FFS, null as m_APD, 
			cast(ROUND(case when isnull(t5.nFFS,0) = 0 then 0 else isnull(t5.nTotal,0) / isnull(t5.nFFS,0) end, 3) as numeric(4,3)) as m_Per, 
			null as m_CPD
		from (
			select distinct cType, iRgn, sRgn from @Dyad
			where cType is not null --Drop empty data sets
		) as rgn
		left join (
			select cType, iRgn, cScope, cPyramid, iItemID, iYYYY, iMM, nTotal, nFFS 
			from @top5
		) as t5 on t5.iRgn = rgn.iRgn and t5.cType = rgn.cType
		where t5.iYYYY = @xYYYY and t5.iMM = @xMM
	) as d on r.cType = d.cType and r.iRgn = d.iRgn and r.cScope = d.cScope 
		and r.cPyramid = d.cPyramid and r.iItemID = d.iItemID
) as x on ru.cType = x.cType and ru.iRgn = x.iRgn and ru.cScope = x.cScope 
	and ru.cPyramid = x.cPyramid and ru.iItemID = x.iItemID


--More date forward a month
set @nDate = dateadd(m,1,@nDate)
--Get Month 5
select @xYYYY = YEAR(@nDate), @xMM = MONTH(@nDate)

--Do the Insert for Month 5
update @Rollup set 
	m5Lbl = isnull(x.m_Lbl,CAST(@xYYYY as CHAR(4)) + '-' + right('0' + CAST(@xMM as varchar(2)),2) ),
	m5Ttl = isnull(x.m_Ttl,0), 
	m5FFS = isnull(x.m_FFS,0), 
	m5APD = x.m_APD, 
	m5Per = isnull(x.m_Per,0), 
	m5CPD = x.m_CPD
from @Rollup as ru
left join (
	select 
		r.cType, r.iRgn, r.cScope, r.cPyramid, r.iItemID, d.m_Lbl, d.m_Ttl, d.m_FFS, d.m_APD, d.m_Per, d.m_CPD
	from (
		select cType, iRgn, cScope, cPyramid, iItemID from @Rollup
	) as r
	join (
		select rgn.cType, rgn.iRgn, t5.cScope, t5.cPyramid, t5.iItemID,
			CAST(t5.iYYYY as CHAR(4)) + '-' + right('0' + CAST(t5.iMM as varchar(2)),2) as m_Lbl,
			isnull(t5.nTotal,0) as m_Ttl, isnull(t5.nFFS,0) as m_FFS, null as m_APD, 
			cast(ROUND(case when isnull(t5.nFFS,0) = 0 then 0 else isnull(t5.nTotal,0) / isnull(t5.nFFS,0) end, 3) as numeric(4,3)) as m_Per, 
			null as m_CPD
		from (
			select distinct cType, iRgn, sRgn from @Dyad
			where cType is not null --Drop empty data sets
		) as rgn
		left join (
			select cType, iRgn, cScope, cPyramid, iItemID, iYYYY, iMM, nTotal, nFFS 
			from @top5
		) as t5 on t5.iRgn = rgn.iRgn and t5.cType = rgn.cType
		where t5.iYYYY = @xYYYY and t5.iMM = @xMM
	) as d on r.cType = d.cType and r.iRgn = d.iRgn and r.cScope = d.cScope 
		and r.cPyramid = d.cPyramid and r.iItemID = d.iItemID
) as x on ru.cType = x.cType and ru.iRgn = x.iRgn and ru.cScope = x.cScope 
	and ru.cPyramid = x.cPyramid and ru.iItemID = x.iItemID

--More date forward a month
set @nDate = dateadd(m,1,@nDate)
--Get Month 6
select @xYYYY = YEAR(@nDate), @xMM = MONTH(@nDate)

--Do the Insert for Month 6
update @Rollup set 
	m6Lbl = isnull(x.m_Lbl,CAST(@xYYYY as CHAR(4)) + '-' + right('0' + CAST(@xMM as varchar(2)),2) ),
	m6Ttl = isnull(x.m_Ttl,0), 
	m6FFS = isnull(x.m_FFS,0), 
	m6APD = x.m_APD, 
	m6Per = isnull(x.m_Per,0), 
	m6CPD = x.m_CPD
from @Rollup as ru
left join (
	select 
		r.cType, r.iRgn, r.cScope, r.cPyramid, r.iItemID, d.m_Lbl, d.m_Ttl, d.m_FFS, d.m_APD, d.m_Per, d.m_CPD
	from (
		select cType, iRgn, cScope, cPyramid, iItemID from @Rollup
	) as r
	join (
		select rgn.cType, rgn.iRgn, t5.cScope, t5.cPyramid, t5.iItemID,
			CAST(t5.iYYYY as CHAR(4)) + '-' + right('0' + CAST(t5.iMM as varchar(2)),2) as m_Lbl,
			isnull(t5.nTotal,0) as m_Ttl, isnull(t5.nFFS,0) as m_FFS, null as m_APD, 
			cast(ROUND(case when isnull(t5.nFFS,0) = 0 then 0 else isnull(t5.nTotal,0) / isnull(t5.nFFS,0) end, 3) as numeric(4,3)) as m_Per, 
			null as m_CPD
		from (
			select distinct cType, iRgn, sRgn from @Dyad
			where cType is not null --Drop empty data sets
		) as rgn
		left join (
			select cType, iRgn, cScope, cPyramid, iItemID, iYYYY, iMM, nTotal, nFFS 
			from @top5
		) as t5 on t5.iRgn = rgn.iRgn and t5.cType = rgn.cType
		where t5.iYYYY = @xYYYY and t5.iMM = @xMM
	) as d on r.cType = d.cType and r.iRgn = d.iRgn and r.cScope = d.cScope 
		and r.cPyramid = d.cPyramid and r.iItemID = d.iItemID
) as x on ru.cType = x.cType and ru.iRgn = x.iRgn and ru.cScope = x.cScope 
	and ru.cPyramid = x.cPyramid and ru.iItemID = x.iItemID

/*--------------------------------------------------------------------------*\
|   Done with the bulk data now lets get national rollup                     |
\*--------------------------------------------------------------------------*/

--Nationals are a sum of parts so update the NN and RX records.
update @Rollup set
	m1Ttl = x.m1Ttl, m1FFS = x.m1FFS, 
	m2Ttl = x.m2Ttl, m2FFS = x.m2FFS, 
	m3Ttl = x.m3Ttl, m3FFS = x.m3FFS, 
	m4Ttl = x.m4Ttl, m4FFS = x.m4FFS, 
	m5Ttl = x.m5Ttl, m5FFS = x.m5FFS, 
	m6Ttl = x.m6Ttl, m6FFS = x.m6FFS 
from @Rollup as r
join (
	select cType, cScope, cPyramid, iItemID, 
		SUM(m1Ttl) as m1Ttl, SUM(m1FFS) as m1FFS, 
		SUM(m2Ttl) as m2Ttl, SUM(m2FFS) as m2FFS, 
		SUM(m3Ttl) as m3Ttl, SUM(m3FFS) as m3FFS, 
		SUM(m4Ttl) as m4Ttl, SUM(m4FFS) as m4FFS, 
		SUM(m5Ttl) as m5Ttl, SUM(m5FFS) as m5FFS, 
		SUM(m6Ttl) as m6Ttl, SUM(m6FFS) as m6FFS 
	from @Rollup 
	where cScope = 'N' and cPyramid = 'R'
	group by cType, cScope, cPyramid, iItemID 
) as x on r.cType = x.cType and r.cScope = x.cScope and r.cPyramid = 'N' and r.iItemID = x.iItemID 

--select 'Rollup N Scope'; select * from @Rollup where cScope = 'N' and cPyramid = 'N' 

--Calculate national Percentages
update @Rollup set
	m1Per = cast(ROUND(case when isnull(m1FFS,0) = 0 then 0 else isnull(m1Ttl,0) / isnull(m1FFS,0) end, 3) as numeric(4,3)), 
	m2Per = cast(ROUND(case when isnull(m2FFS,0) = 0 then 0 else isnull(m2Ttl,0) / isnull(m2FFS,0) end, 3) as numeric(4,3)), 
	m3Per = cast(ROUND(case when isnull(m3FFS,0) = 0 then 0 else isnull(m3Ttl,0) / isnull(m3FFS,0) end, 3) as numeric(4,3)), 
	m4Per = cast(ROUND(case when isnull(m4FFS,0) = 0 then 0 else isnull(m4Ttl,0) / isnull(m4FFS,0) end, 3) as numeric(4,3)), 
	m5Per = cast(ROUND(case when isnull(m5FFS,0) = 0 then 0 else isnull(m5Ttl,0) / isnull(m5FFS,0) end, 3) as numeric(4,3)), 
	m6Per = cast(ROUND(case when isnull(m6FFS,0) = 0 then 0 else isnull(m6Ttl,0) / isnull(m6FFS,0) end, 3) as numeric(4,3)) 
where cScope = 'N' and cPyramid = 'N'

--select 'Recalc N Scope'; select * from @Rollup where cScope = 'N' and cPyramid = 'N' 

--Nationals are a sum of parts so update the NN and RX records.





--Need to load the mXTtl index this is the total of the item for all 6 months (so we can sort them)
update @Rollup
set mXTtl = m1Ttl + m2Ttl + m3Ttl + m4Ttl + m5Ttl + m6Ttl

--select 'Total N Scope'; select * from @Rollup where cScope = 'N' and cPyramid = 'N' 



--We have the data spread over 6 mnths, lets attach an item name.
update @Rollup
set sItemName = ltrim(rtrim(i.sName))
from @Rollup as r
join ss.tblItem as i on r.iItemID = i.iItemID 

/*--------------------------------------------------------------------------*\
|   Regional Records could have less then 5 items, fix!                      |
\*--------------------------------------------------------------------------*/

--Cursor Loop
--Declare Loop Vars
DECLARE @z_cType char(3), @z_xCnt int, @z_sRgn varchar(128) --, @z_iRgn int
--Declare Cursor
DECLARE missing_cursor CURSOR FOR
--Select Loop Data

--This is the list of locations that need blank items inserted in to fill up our list of 5 items.
select cType, iRgn, sRgn, xCnt
from (
	--We want there to be 5 items for each Rgn
	select cType, iRgn, sRgn, 5 - SUM(1) as xCnt
	from @Rollup 
	where cScope = 'R' and cPyramid = 'X'
	group by cType, iRgn, sRgn
) as x
where xCnt > 0

--Open Loop
OPEN missing_cursor
-- Perform the first fetch and store the values in variables.
FETCH NEXT FROM missing_cursor INTO @z_cType, @z_iRgn, @z_sRgn, @z_xCnt
-- Check @@FETCH_STATUS to see if there are any more rows to fetch.
WHILE @@FETCH_STATUS = 0
BEGIN
	--Do Stuff

	--Loop the xCnt and add 1 per missing record	
	while @z_xCnt >= 1 begin
		insert into @Rollup (
			cType, iRgn, sRgn, cScope, cPyramid, iItemID,
			m1Lbl, m1Ttl, m1FFS, m1APD, m1Per, m1CPD,
			m2Lbl, m2Ttl, m2FFS, m2APD, m2Per, m2CPD,
			m3Lbl, m3Ttl, m3FFS, m3APD, m3Per, m3CPD,
			m4Lbl, m4Ttl, m4FFS, m4APD, m4Per, m4CPD,
			m5Lbl, m5Ttl, m5FFS, m5APD, m5Per, m5CPD,
			m6Lbl, m6Ttl, m6FFS, m6APD, m6Per, m6CPD,
			sItemName, mXTtl
		)
		--Do the Insert for item needing to be added
		select @z_cType as cType, @z_iRgn as iRgn, @z_sRgn as sRgn, 'R' as cScope, 'R' as cPyramid, 0 as iItemID,
			'' as m1Lbl, 0 as m1Ttl, 0 as m1FFS, null as m1APD, 0 as m1Per, 0 as m1CPD,
			'' as m2Lbl, 0 as m2Ttl, 0 as m2FFS, null as m2APD, 0 as m2Per, 0 as m2CPD,
			'' as m3Lbl, 0 as m3Ttl, 0 as m3FFS, null as m3APD, 0 as m3Per, 0 as m3CPD,
			'' as m4Lbl, 0 as m4Ttl, 0 as m4FFS, null as m4APD, 0 as m4Per, 0 as m4CPD,
			'' as m5Lbl, 0 as m5Ttl, 0 as m5FFS, null as m5APD, 0 as m5Per, 0 as m5CPD,
			'' as m6Lbl, 0 as m6Ttl, 0 as m6FFS, null as m6APD, 0 as m6Per, 0 as m6CPD,
			'Space Holder ' + cast(@z_xCnt as char(1)) as sItemName, 0 as mXTtl
		--More date forward a month
		set @z_xCnt = @z_xCnt - 1
		--Repeate as needed
	end

	-- This is executed as long as the previous fetch succeeds.
   	FETCH NEXT FROM missing_cursor INTO @z_cType, @z_iRgn, @z_sRgn, @z_xCnt
END
--Close the loop
CLOSE missing_cursor
DEALLOCATE missing_cursor

--select * from @Rollup where cScope = 'R' and cPyramid = 'R' and iItemID = 0 --Added Records with iItemID = 0


/*--------------------------------------------------------------------------*\
|   Ready to Dump Data                                                       |
\*--------------------------------------------------------------------------*/

select 'Report Labels' as info
--Get National Scope top 5 data by Contract Type.
select top 1
	'Contract' as 'Contract', 'Scope' as 'Scope', 'Report' as 'Report',
	'Region Name (R)' as 'Region Name (R)', 
	'Top 5 Items (I)' as 'Top 5 Item (I)', 
	m1Lbl as 'Month 1', m2Lbl as 'Month 2', m3Lbl as 'Month 3', 
	m4Lbl as 'Month 4', m5Lbl as 'Month 5', m6Lbl as 'Month 6'
from @Rollup 
where cScope = 'N' and cPyramid = 'N'

 IF OBJECT_ID('reports_bic.dbo.Top5ItemsNathan', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.Top5ItemsNathan;
CREATE TABLE reports_bic.dbo.Top5ItemsNathan(
	[Contract] [varchar](15) NOT NULL,
	[Scope] [varchar](14) NOT NULL,
	[Report] [varchar](8) NOT NULL,
	[Region Name] [varchar](149) NULL,
	[Top 5 Item] [varchar](149) NULL,
	[m1Per] [numeric](4, 3) NULL,
	[m2Per] [numeric](4, 3) NULL,
	[m3Per] [numeric](4, 3) NULL
) ON [PRIMARY]

insert into reports_bic.dbo.Top5ItemsNathan
--Get National Scope top 5 data by Contract Type.
select case cType 
		when 'B&M' then 'B&M'
		when 'NET' then 'NET'
		when 'SWC' then 'SWC'
		when 'BN-' then 'B&M + NET'
		when 'B-S' then 'B&M + SWC'
		when '-NS' then 'NET + SWC'
		when 'BNS' then 'B&M + NET + SWC'
	else 'Unknown Type' end as 'Contract', 
	'National Level' as 'Scope', '% of FFS' as 'Report',
	sRgn + '   (' + CAST(iRgn as varchar(16)) + ')' as 'Region Name (r)', 
	--cScope, cPyramid, 
	sItemName + '   (' + CAST(iItemID as varchar(16)) + ')' as 'Top 5 Item (i)', 
	m1Per, m2Per, m3Per--, mXTtl 
from @Rollup 
where cScope = 'N' and cPyramid = 'N'
order by cType, sRgn, cScope, cPyramid, mXTtl desc, sItemName 

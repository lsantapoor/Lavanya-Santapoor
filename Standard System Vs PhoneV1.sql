use reports

declare @iHOS as int, @iDME as int, @cTime as char(1), @iOffset as int
set @cTime = 'M' --'Y'early, 'Q'uarterly, 'M'onthly, 'W'eekly (Su-Sa), 'I'SO Week (Mo-Su),  'D'aily
set @iOffset = -3 --0 for Last (day, week, etc) Negative for older reports, +1 is current time span

/*-------------------------------------------------------------*\
|  Part 1: User Variables                                       |
\*-------------------------------------------------------------*/

IF OBJECT_ID('reports_bic.dbo.iHOS_SystemlistBizReview', 'U') IS NULL 
begin
declare @table_text char(100)
set @table_text = 'Hospice List Table Not present. Creating the table.... '
print @table_text

--  DROP TABLE reports_bic.dbo.iHOS_SystemlistBizReview; 

 

create table reports_bic.dbo.iHOS_SystemlistBizReview(
iHOS_SEQ_NO int,
iHOS_ID int,
iHOS_name varchar(100)
)

--Usage of insert below:
--insert into reports_bic.dbo.iHOS_SystemlistBizReview values(sequence_number,hospice id, Hospice Name)

insert into reports_bic.dbo.iHOS_SystemlistBizReview values(1,10,'Optum Palliative and Hospice Care') --Optum Palliative and Hospice Care
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(2,12,'Alacare Home Health & Hospice')  --Alacare Home Health & Hospice
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(3,257,'Harbor Light Hospice') --Harbor Light Hospice
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(4,238,'SouthernCare, Inc {Curo}') --SouthernCare, Inc {Curo}
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(5,187,'Hospice of Santa Cruz County') --Hospice of Santa Cruz County
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(6,269,'Suncrest Health Services') --Suncrest Health Services
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(7,1057,'Sta-Home Health & Hospice, Inc.') --Sta-Home Health & Hospice, Inc.
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(8,120,'Banner Hospice') --Banner Hospice
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(9,232,'Hospice Partners of America') --Hospice Partners of America
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(10,295,'Encompass Home Health & Hospice') 
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(11,227,'Delaware Hospice')-- Delaware Hospice
insert into reports_bic.dbo.iHOS_SystemlistBizReview values(12,144,'Signature Hospice')-- Signature Hospice 

end

Declare @iHOSCount as int , @iHOS_step as int , @iHOS_ID as int,@iHOS_SEQ_NO as int,@iHOSNAME as char(100)
select @iHOScount= count(*) from reports_bic.dbo.iHOS_SystemlistBizReview
print @iHOScount

select * from reports_bic.dbo.iHOS_SystemlistBizReview
set @iHOS_step=1

while (@iHOS_step <= @iHOScount)
begin

select @iHOS=iHOS_ID from reports_bic.dbo.iHOS_SystemlistBizReview where iHOS_SEQ_NO = @iHOS_step -- read Hospice id from the list 
select @iHOSNAME=iHOS_name from reports_bic.dbo.iHOS_SystemlistBizReview where iHOS_SEQ_NO = @iHOS_step
-----------
----your coode starts here
print @iHOS


/*-------------------------------------------------------------*\
|  Part 2: Get Date Data                                        |
\*-------------------------------------------------------------*/

	--Defaults will get last month

	declare @dS as datetime, @dE as datetime, @dNow as datetime, @iDOW as int, @sTitle as varchar(32), @iDOWOffset as int, @iMM as int
										
	set @dS = DATEADD(mm, DATEDIFF(mm, 0, GETDATE()) - 3, 0)
    set @dE = CONVERT(VARCHAR(25),DATEADD(dd,-(DAY(GETDATE())),GETDATE()),101)
	   
	set @sTitle = 'Month of ' + cast(Month(@dS) as varCHAR(2)) + '/' + cast(YEAR(@dS) as CHAR(4))
   
    print @ds
	print @dE


	--if @iDebug >= 1 begin
		select @sTitle as Title, @dS as dStart, @dE as dEnd, MAX(dtDateStamp) as dOldest, cast(ss.fn_Date(@dE,null,2) as char(10)) as dLabel,
		    case when @dE > MAX(dtDateStamp) then 'WARNING UPDATE DATABASE' else 'DB OKAY' end as info, @dS as dStartPrior, @dE as dEndPrior
		from ss.tblOrder

	--end

	

/*-------------------------------------------------------------*\
|  Part 3: Required Census compiled data                        |
\*-------------------------------------------------------------*/
declare @iYYYYMM as int, @iSY int, @iSM int, @iEY int, @iEM int, @iSYYYYMM int, @iEYYYYMM int
select @iSY = year(@dS), @iSM = month(@dS), @iEY = year(@dE), @iEM = month(@dE)	--Prior Start to Current End
select @iSYYYYMM = @iSY * 100 + @iSM, @iEYYYYMM = @iEY * 100 + @iEM
set @iYYYYMM = @iSY * 100 + @iSM

print @iYYYYMM
--select 'Loop Dates' as info, @iSYYYYMM as iStartYYYYMM, @iEYYYYMM as iEndYYYYMM

--We are going to loop the date span from priors start month to currents end month. 
--Checking for SiteLevel Acting having been done in the last 24 hours, rerunning as needed.
declare @dChk_Patient_DMEDays as datetime
while @iYYYYMM <= @iEY * 100 + @iEM begin
	--Current Record.
--	select @iYYYYMM
	--Check for data
	IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ss].[tblPatient_DMEDays]') AND type in (N'U'))
	begin select @dChk_Patient_DMEDays = min(dAdded) from reports.ss.tblPatient_DMEDays where iYYYYMM = @iYYYYMM end
	if isnull(@dChk_Patient_DMEDays, '1900-01-01 00:00:00.000') = '1900-01-01 00:00:00.000' begin set @dChk_Patient_DMEDays = '1900-01-01 00:00:00.000' end
	--Pull data if not fresh
	if datediff(d,@dChk_Patient_DMEDays,@dNow) > 1 begin
		--Force rebuild of Acting Day Data
		exec ss.sp_SiteLevel_ActingDays @iSY,@iSM
--		select 'x' as i, @iYYYYMM
--	end else begin
--		select 'y' as i, @iYYYYMM
	End
	--Get Next Record
	set @iSM = @iSM + 1
	if @iSM > 12 begin select @iSM = 1, @iSY = @iSY + 1 end
	set @iYYYYMM = @iSY * 100 + @iSM
end

/*-------------------------------------------------------------*\
|  Part 4: Store Average Census Data for Target Span(s)         |
\*-------------------------------------------------------------*/
--Min 1 month, if weekly and it breaks over a month boundry then average of both months is used.
--If Quarterly or Yearly its an average of target months in Date Span.

--Need to store the target census data for the month(s) in question
declare @t_DyadCensus as table (
	bSwitch int,				--1 = current, 0 = prior
	iHOS int,					--Hospice ID
	iRgn int,					--Region ID
	iCID int,					--Client ID (note IPUs are rolled into Client Data)
	iSID int,					--Site ID
	iDME int,					--DME ID
	nCensus numeric(9,6),		--Sum of all Census from (Dyad + IPU) divided by Months in Count
	iCntMnth int				--Count of Months
)

--Current Span Census Data
select @iSY = year(@dS), @iSM = month(@dS), @iEY = year(@dE), @iEM = month(@dE)	--Prior Start to Current End
select @iSYYYYMM = @iSY * 100 + @iSM, @iEYYYYMM = @iEY * 100 + @iEM

print @iSM
print @iEM
print @iSYYYYMM
print @iEYYYYMM

insert into @t_DyadCensus
--This is Census Data we need to average it out if spanning more than one month.
select 1 as bSwitch, iHOS, iRegion, iCID, iSID, iDME, 
	cast(sum(iCensus)/Sum(1.0) as numeric(9,6)) as nCensus, 
	Sum(1) as iMonthSpan
from (
	--We group without IPU to Join it to the Dyad Level first.
	select iHOS, iRegion, iCID, iSID, iDME, iYYYYMM, sum(iDMEPatientCnt) as iCensus
	from reports.ss.tblPatient_DMEDays
	where iYYYYMM >= @iSYYYYMM
	and iYYYYMM <= @iEYYYYMM
	group by iHOS, iRegion, iCID, iSID, iDME, iYYYYMM
) as x
group by iHOS, iRegion, iCID, iSID, iDME

--Prior Span Census Data
select @iSY = year(@dS), @iSM = month(@dS), @iEY = year(@dE), @iEM = month(@dE)	--Prior Start to Current End
select @iSYYYYMM = @iSY * 100 + @iSM, @iEYYYYMM = @iEY * 100 + @iEM

insert into @t_DyadCensus
--This is Census Data we need to average it out if spanning more than one month.
select 0 as bSwitch, iHOS, iRegion, iCID, iSID, iDME, 
	cast(sum(iCensus)/Sum(1.0) as numeric(9,6)) as nCensus, 
	Sum(1) as iMonthSpan
from (
	--We group without IPU to Join it to the Dyad Level first.
	select iHOS, iRegion, iCID, iSID, iDME, iYYYYMM, sum(iDMEPatientCnt) as iCensus
	from reports.ss.tblPatient_DMEDays
	where iYYYYMM >= @iSYYYYMM
	and iYYYYMM <= @iEYYYYMM
	group by iHOS, iRegion, iCID, iSID, iDME, iYYYYMM
) as x
group by iHOS, iRegion, iCID, iSID, iDME


--select * from @t_DyadCensus

/*-------------------------------------------------------------*\
|  Part 5: Load Phn v Sys Table with Raw Data                   |
\*-------------------------------------------------------------*/

Declare @tmpRpt_PhnSys_Raw TABLE (
	bWeek bit NOT NULL,
	iHOS int NOT NULL,
	sHospice varchar(128) NULL,
	iRID int NOT NULL,
	sRegion varchar(128) NULL,
	iCID int NOT NULL,
	sClient varchar(128) NULL,
	iDME int NOT NULL,
	sProvider varchar(128) NULL,
	iSID int NOT NULL,
	sSite varchar(128) NOT NULL,
	iUID_OrderedBy int NOT NULL,	--tblUser.iUserID reference for person placing order.
	iUserCRef int NULL,				--Company the user belongs to
	cUserType char(1) NOT NULL,		--tblUser.cType = Type of User (Pyramid Ref) D = DME, S = Site, C = Client, H = Hospice
	cUserLType char(1) NULL,		--tblUserLocation.cType
	iPhnNET int not null,			--Not System Orders placed by DME Company
	iPhnSSM int not null,			--Not System Orders placed by SSM Corp users (ie customer service)
	iPhn int NOT NULL,				--Not System Orders
	iSys int NOT NULL,				--Syetem Orders (ie placed by Hospice)
	iOID int NOT NULL,				--Order ID
	iOrderedBy int Not Null,		--Who Ordered It
	dWhen datetime not null			--When it was ordered
)

	--Get Current Time Windows Data - HOSPICE or DME as nulls flip to other.
	insert into @tmpRpt_PhnSys_Raw
	--System vs Phone Call Report
	Select	1 as bWeek,
			h.iCompanyID as iHOS, @iHOSNAME as sHospice,
			isnull(x.iRID,0) as iRID, case when isnull(x.iRID,0) = 0 then rtrim((ltrim(x.sState + ' Region'))) else rtrim(ltrim(r.sName)) end as sRegion,
			x.iCID, x.sClient as sClient,
			d.iCompanyID as iDME, d.sName as sProvider,
			x.iSID, s.sName as sSite,
			x.iOrderedBy as iUID_OrderedBy, null as iUserCRef, usr.cType as cUserType, null as cUserLType, 0 as iPhnNET, 0 as iPhnSSM,
			case 
				when usr.cType in ('D','S') then 1
				else 
					case lower(usr.sFirst) 
						when 'stateserv' then 1
						else 0 
					end 
				end as [Phn], 
			case 
				when usr.cType in ('D','S') then 0
				else 
					case lower(usr.sFirst) 
						when 'stateserv' then 0
						else 1 
					end 
				end as [Sys],
			x.iOrderID,
			x.iOrderedBy,
			x.dtDateStamp
	From (	
		--Get Current Weeks Data
		select
			c.sName as sClient,
			p.iClientRef as iCID, 
			c.iCompanyRef, 
			p.iSiteRef as iSID, 
			o.iOrderedBy,
			c.iSetRef as iRID, c.sState,
			o.iOrderID,
			o.dtDateStamp  
		from ss.tblorder o
		join ss.tblPatient p on o.iPatientID = p.iPatientID
		join ss.tblLocation c on p.iClientRef = c.iLocationID
		join ss.tblLocation s on p.iSiteRef = s.iLocationID
		where o.dtDateStamp between @dS and @dE
		and o.cStatusID in ('D','P')					--Drop bad orders 
		and c.iCompanyRef = isnull(@iHOS,c.iCompanyRef)	--filter by DME Company
		and s.iCompanyRef = isnull(@iDME,s.iCompanyRef)	--filter by DME Company
		and c.cBillingMode <> 'H'						--No Homecare
		and o.cReason not in ('X','S','W','V')			--Drop D&D, Standing O2, Switchout and Conversions
	) as x
	join ss.tblCompany as h on x.iCompanyRef = h.iCompanyID
	join ss.tblLocation as s on x.iSID = s.iLocationID
	join ss.tblCompany as d on s.iCompanyRef = d.iCompanyID
	join ss.tblUser as usr on x.iOrderedBy = usr.iUserID
	left join ss.tblSet as r on x.iRID = r.iSetID

/*-------------------------------------------------------------*\
|  Part 6: Find Missing Phn v Sys Records                       |
\*-------------------------------------------------------------*/
--Find Missing Things
--Load any active Dyads in target Prior or Current records that is missing a record in Raw Table


	insert into @tmpRpt_PhnSys_Raw
	--System vs Phone Call Report
	Select	0 as bWeek,
			h.iCompanyID as iHOS, @iHOSNAME as sHospice,
			isnull(x.iRID,0) as iRID, case when isnull(x.iRID,0) = 0 then x.sState + ' Region' else r.sName end as sRegion,
			x.iCID, x.sClient as sClient,
			d.iCompanyID as iDME, d.sName as sProvider,
			x.iSID, s.sName as sSite,
			x.iOrderedBy as iUID_OrderedBy, null as iUserCRef, usr.cType as cUserType, null as cUserLType, 0 as iPhnNET, 0 as iPhnSSM,
			case 
				when usr.cType in ('D','S') then 1
				else 
					case lower(usr.sFirst) 
						when 'stateserv' then 1
						else 0 
					end 
				end as [Phn], 
			case 
				when usr.cType in ('D','S') then 0
				else 
					case lower(usr.sFirst) 
						when 'stateserv' then 0
						else 1 
					end 
				end as [Sys],
			x.iOrderID,
			x.iOrderedBy,
			x.dtDateStamp
	From (	
		--Get Current Weeks Data
		select
			c.sName as sClient,
			p.iClientRef as iCID, 
			c.iCompanyRef, 
			p.iSiteRef as iSID, 
			o.iOrderedBy,
			c.iSetRef as iRID, c.sState,
			o.iOrderID,
			o.dtDateStamp
		from ss.tblorder o
		join ss.tblPatient p on o.iPatientID = p.iPatientID
		join ss.tblLocation c on p.iClientRef = c.iLocationID
		join ss.tblLocation s on p.iSiteRef = s.iLocationID
		where o.dtDateStamp between @dS and @dE
		and o.cStatusID in ('D','P')					--Drop bad orders 
		and c.iCompanyRef = isnull(@iHOS,c.iCompanyRef)	--filter by DME Company
		and s.iCompanyRef = isnull(@iDME,s.iCompanyRef)	--filter by DME Company
		and c.cBillingMode <> 'H'						--No Homecare
		and o.cReason not in ('X','S','W','V')			--Drop D&D, Standing O2, Switchout and Conversions
	) as x
	join ss.tblCompany as h on x.iCompanyRef = h.iCompanyID
	join ss.tblLocation as s on x.iSID = s.iLocationID
	join ss.tblCompany as d on s.iCompanyRef = d.iCompanyID
	join ss.tblUser as usr on x.iOrderedBy = usr.iUserID
	left join ss.tblSet as r on x.iRID = r.iSetID

--select LEFT(sRegion,2) as ST, * from @tmpRpt_PhnSys_Raw where iRID = 0


/*-------------------------------------------------------------*\
|  Part 7: Update missing Raw Data                              |
\*-------------------------------------------------------------*/

UPDATE @tmpRpt_PhnSys_Raw
set iRID = 
	Case LEFT(sRegion,2)
		when 'AL' then -22	when 'AK' then -49	when 'AZ' then -48	when 'AR' then -25	when 'CA' then -31
		when 'CO' then -38	when 'CT' then -5	when 'DE' then -1	when 'FL' then -27	when 'GA' then -4
		when 'HI' then -50	when 'ID' then -43	when 'IL' then -21	when 'IN' then -19	when 'IA' then -29
		when 'KS' then -34	when 'KY' then -15	when 'LA' then -18	when 'ME' then -23	when 'MD' then -7
		when 'MA' then -6	when 'MI' then -26	when 'MN' then -32	when 'MS' then -20	when 'MO' then -24
		when 'MT' then -41	when 'NE' then -37	when 'NV' then -36	when 'NH' then -9	when 'NJ' then -3
		when 'NM' then -47	when 'NY' then -11	when 'NC' then -12	when 'ND' then -39	when 'OH' then -17
		when 'OK' then -46	when 'OR' then -33	when 'PA' then -2	when 'RI' then -13	when 'SC' then -8
		when 'SD' then -40	when 'TN' then -16	when 'TX' then -28	when 'UT' then -45	when 'VT' then -14
		when 'VA' then -10	when 'WA' then -42	when 'WV' then -35	when 'WI' then -30	when 'WY' then -44
		when 'DC' then -51
	else 0 end
where iRID = 0	

--Get User Company info

--select distinct u.*, case when ul.LocationId is null then 'D' else 'S' end as Type
--from ss.tbluser u
--join dbo.UserLocation ul on ul.UserId = u.iUserID
--order by iUserID
--where ul.CompanyId = 2 --and u.cStatus='A'

--Get Hospice Users
update @tmpRpt_PhnSys_Raw
set iUserCRef = CompanyID, --(958)
	cUserLType = cType
from @tmpRpt_PhnSys_Raw as x
join (
	select distinct u.iUserID, ul.CompanyID, ul.LocationID, ul.cType
	from ss.tbluser u
	join dbo.UserLocation ul on ul.UserId = u.iUserID
	group by u.iUserID, ul.CompanyID, ul.LocationID, ul.cType
) as u on u.iUserID = x.iUID_OrderedBy and u.CompanyID = iHOS
where iUserCRef is null

--Get DMEs Users
update @tmpRpt_PhnSys_Raw
set iUserCRef = CompanyID, --(958)
	cUserLType = cType
from @tmpRpt_PhnSys_Raw as x
join (
	select distinct u.iUserID, ul.CompanyID, ul.LocationID, ul.cType
	from ss.tbluser u
	join dbo.UserLocation ul on ul.UserId = u.iUserID
	group by u.iUserID, ul.CompanyID, ul.LocationID, ul.cType
) as u on u.iUserID = x.iUID_OrderedBy and u.CompanyID = iDME
where iUserCRef is null

--where ul.CompanyId = 2 --and u.cStatus='A'

--Calculate iPhnNET v iPhnSSM
update @tmpRpt_PhnSys_Raw set iPhnNET = iPhn														--Default all to iPhn
update @tmpRpt_PhnSys_Raw set iPhnNET = 0, iPhnSSM = iPhn where iUserCRef = 2 and cUserLType = 'D'  --Update if SSM and DME User

--select 'Raw'as i, * from @tmpRpt_PhnSys_Raw
--where iUserCRef is null

/*-------------------------------------------------------------*\
|  Part 8: Compile into output format                           |
\*-------------------------------------------------------------*/

/*
select 'Phn V. Sys Detail - Placed By' as info
select sHospice, sRegion, sClient, sProvider, sSite, iPhn, iSys, iOID, DATENAME(month ,dWhen) as smonth, u.sFull as sOrderedBy
from @tmpRpt_PhnSys_Raw as x
join ss.tblUser as u on u.iUserID = x.iOrderedBy
order by sHospice, sRegion, sClient, sProvider, sSite*/
IF OBJECT_ID('reports_bic.dbo.StandardSystemUtilization', 'U') IS NOT NULL 
  DROP TABLE reports_bic.dbo.StandardSystemUtilization; 

CREATE TABLE reports_bic.dbo.StandardSystemUtilization(
	[sHospice] [varchar](128) NULL,
	[sRegion] [varchar](128) NULL,
	[sClient] [varchar](128) NULL,
	[sProvider] [varchar](128) NULL,
	[sSite] [varchar](128) NOT NULL,
	[iPhn] [int] NOT NULL,
	[iSys] [int] NOT NULL,
	[iOID] [int] NOT NULL,
	[smonth] [varchar](12) NULL,
	[sOrderedBy] [varchar](128) NOT NULL
) ON [PRIMARY]

insert into reports_bic.dbo.StandardSystemUtilization
select distinct rtrim(ltrim(sHospice)), rtrim(ltrim(sRegion)), rtrim(ltrim(sClient)), rtrim(ltrim(sProvider)), sSite, iPhn, iSys, iOID, DATENAME(month ,dWhen) as smonth, rtrim(ltrim(u.sFull)) as sOrderedBy 
from @tmpRpt_PhnSys_Raw as x 
join ss.tblUser as u on u.iUserID = x.iOrderedBy
--order by sHospice, sRegion, sClient, sProvider, sSite


---your code ends here----
set @iHOS_step = @iHOS_step +1
end


GO

/****** Object:  UserDefinedFunction [dbo].[retornarPeriodoFuncionario]    Script Date: 26/11/2020 11:17:46 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






-- =============================================
-- Author:		Jean Paul
-- Create date: 23/05/2019
-- Description:	Trás a soma da carga horária do funcionário
-- =============================================
ALTER FUNCTION [dbo].[retornarPeriodoFuncionario] 
(
	-- Add the parameters for the function here
	@cartacodigo int,
	@periodo smallint
)
RETURNS 
@tempo table (
minuto int,interval int, entprev datetime, saidaprev datetime, toleranciaant_e datetime, 
toleranciapost_e datetime, toleranciaant_s datetime, toleranciapost_s datetime,cont int,date1 datetime, date2 datetime,afdtgdata datetime, data_aux datetime)
AS
BEGIN	
	declare @segundos int, @minutos int, @horas int
	declare @date1 datetime, @date2 datetime; -- E/S
	declare @interval int
	declare @contador int = 0 
	declare @jornadalivre bit -- Indica se o funcionário está marcado como jornada livre
	declare @entprev datetime, @saiprev datetime -- Entradas e saídas previstas
	declare @toleranciaanterior_e datetime, @toleranciaposterior_e datetime, @toleranciaanterior_s datetime, @toleranciaposterior_s datetime -- Entradas e saídas com tolerância 
	declare @funcicodigo int = (select funcicodigo from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
	declare @leimotorista bit = (select coalesce(funcileimotorista,0) from tbgabfuncionario (nolock) where funcicodigo = @funcicodigo)
	declare @cartadata datetime = (select cartadatajornada from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
	declare @pis varchar(11) = (select funcipis from tbgabfuncionario (nolock) where funcicodigo = @funcicodigo)
	set @jornadalivre = (select cartajornadalivre from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)

	-- ENTRADA/SAÍDA
	if @periodo = 1 
	begin
		set @date1 = (select carta_realizado_e1 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @date2 = (select carta_realizado_s1 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @entprev = (select carta_previsto_e1 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @saiprev = (select carta_previsto_s1 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaanterior_e = (select dateadd(minute,-carta_tolerancia_anterior_e1,carta_previsto_e1) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaposterior_e = (select dateadd(SECOND,carta_tolerancia_posterior_e1*60+59,carta_previsto_e1) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaanterior_s = (select dateadd(minute,-carta_tolerancia_anterior_s1,carta_previsto_s1) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaposterior_s = (select dateadd(SECOND,carta_tolerancia_posterior_s1*60+59,carta_previsto_s1) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
	end
	else if @periodo = 2
	begin
		set @date1 = (select carta_realizado_e2 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @date2 = (select carta_realizado_s2 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @entprev = (select carta_previsto_e2 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @saiprev = (select carta_previsto_s2 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaanterior_e = (select dateadd(minute,-carta_tolerancia_anterior_e2,carta_previsto_e2) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaposterior_e = (select dateadd(SECOND,carta_tolerancia_posterior_e2*60+59,carta_previsto_e2) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaanterior_s = (select dateadd(minute,-carta_tolerancia_anterior_s2,carta_previsto_s2) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaposterior_s = (select dateadd(SECOND,carta_tolerancia_posterior_s2*60+59,carta_previsto_s2) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
	end
	else if @periodo = 3
	begin
		set @date1 = (select carta_realizado_e3 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @date2 = (select carta_realizado_s3 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @entprev = (select carta_previsto_e3 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @saiprev = (select carta_previsto_s3 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaanterior_e = (select dateadd(minute,-carta_tolerancia_anterior_e3,carta_previsto_e3) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaposterior_e = (select dateadd(SECOND,carta_tolerancia_posterior_e3*60+59,carta_previsto_e3) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaanterior_s = (select dateadd(minute,-carta_tolerancia_anterior_s3,carta_previsto_s3) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaposterior_s = (select dateadd(SECOND,carta_tolerancia_posterior_s3*60+59,carta_previsto_s3) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
	end
	else if @periodo = 4
	begin
		set @date1 = (select carta_realizado_e4 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @date2 = (select carta_realizado_s4 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @entprev = (select carta_previsto_e4 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @saiprev = (select carta_previsto_s4 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaanterior_e = (select dateadd(minute,-carta_tolerancia_anterior_e4,carta_previsto_e4) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaposterior_e = (select dateadd(SECOND,carta_tolerancia_posterior_e4*60+59,carta_previsto_e4) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaanterior_s = (select dateadd(minute,-carta_tolerancia_anterior_s4,carta_previsto_s4) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
		set @toleranciaposterior_s = (select dateadd(SECOND,carta_tolerancia_posterior_s4*60+59,carta_previsto_s4) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
	end
	else if @periodo = 5
	begin
		set @date1 = (select apt from dbo.retornarApontamentosRealizadosLeiMotorista(@pis,@cartadata) where jornada = 2 and efeito = 1)
		set @date2 = (select apt from dbo.retornarApontamentosRealizadosLeiMotorista(@pis,@cartadata) where jornada = 2 and efeito = 8)
		set @entprev = @date1
		set @saiprev = @date2
		set @toleranciaanterior_e = @date1
		set @toleranciaposterior_e = @date1
		set @toleranciaanterior_s = @date2
		set @toleranciaposterior_s = @date2
	end

	if @date1 is not null and @date2 is not null
	begin
		set @segundos = datepart(second,@date1)
		set @date1 = dateadd(second,-@segundos,@date1)
		set @segundos = datepart(second,@date2)
		set @date2 = dateadd(second,-@segundos,@date2)
		
		if @jornadalivre = 1
		begin
			set @minutos = (select datediff(MINUTE,@date1,@date2));
		end
		else
		begin
			-- SE O APONTAMENTO REALIZADO ESTIVER DENTRO DA TOLERÂNCIA ANTERIOR E POSTERIOR
			if (@date1 <= @entprev and @date1 >= @toleranciaanterior_e) or (@date1 >= @entprev and @date1 <= @toleranciaposterior_e)
			begin
				set @date1 = @entprev
			end

			-- SE O APONTAMENTO REALIZADO ESTIVER DENTRO DA TOLERÂNCIA ANTERIOR E POSTERIOR
			if (@date2 <= @saiprev and @date2 >= @toleranciaanterior_s) or (@date2 >= @saiprev and @date2 <= @toleranciaposterior_s)
			begin
				set @date2 = @saiprev
			end
			set @minutos = (select datediff(MINUTE,@date1,@date2));
		end
		
		if @leimotorista = 1
		begin
			DECLARE @afdtdata datetime,@data_aux datetime
			set @interval = 0
			-- EVENTOS QUE NÃO CONTABILIZAM
			DECLARE eventos CURSOR FOR 
				select A.afdtgdata from tbgabafdt A 
				inner join tbgabeventotipo E (nolock) on A.tpevecodigo=E.tpevecodigo
				where afdtgpis = @pis and A.afdtgdata >= @date1 and A.afdtgdata <= @date2 and A.afdtgsituacao <> 4 and E.tpevecontabilizajornada = 0
				order by A.afdtgdata desc
			OPEN eventos
			FETCH NEXT FROM eventos INTO @afdtdata
				WHILE @@FETCH_STATUS = 0
				BEGIN
					set @data_aux = null
					set @data_aux = (select top 1 A.afdtgdata from tbgabafdt A 
									 inner join tbgabeventotipo E (nolock) on A.tpevecodigo=E.tpevecodigo
									 where afdtgpis = @pis and A.afdtgdata >= @date1 and A.afdtgdata <= dateadd(second,59,@date2) and A.afdtgsituacao <> 4 
									 and A.afdtgdata > @afdtdata
									 order by A.afdtgdata)
					if @data_aux is not null 
					begin
						set @interval = @interval + coalesce(datediff(minute,@afdtdata,@data_aux),0)
					end
				FETCH NEXT FROM eventos INTO @afdtdata
				END
			CLOSE eventos
			DEALLOCATE eventos
			set @minutos = @minutos - @interval
		end
	end
	else
	begin
		set @minutos = 0;
		--set @contador = 1
		if @date1 is null
		begin
			set @contador = @contador + 1;
		end
		if @date2 is null
		begin
			set @contador = @contador + 1;
		end
	end
	set @interval = @minutos;

	insert into @tempo values (@minutos,@interval,@entprev,@saiprev,@toleranciaanterior_e,@toleranciaposterior_e,
	@toleranciaanterior_s,@toleranciaposterior_s,@contador,@date1,@date2,@afdtdata,@data_aux)

	RETURN;
END
GO


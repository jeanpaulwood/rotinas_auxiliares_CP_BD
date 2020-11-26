
GO

/****** Object:  UserDefinedFunction [dbo].[retornarIntervalosFuncionario]    Script Date: 26/11/2020 11:18:14 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Jean Paul
-- Create date: 23/05/2019
-- Description:	Trás a soma da carga horária do funcionário
-- =============================================
ALTER FUNCTION [dbo].[retornarIntervalosFuncionario] 
(
	-- Add the parameters for the function here
	@cartacodigo int,
	@periodo smallint
)
RETURNS 
@tempo table (minuto int,saida varchar(20), s datetime, e datetime,contabiliza bit)
AS
BEGIN	
	declare @minutos int
	declare @s1 datetime, @e2 datetime, @s2 datetime, @e3 datetime, @s3 datetime, @e4 datetime; -- E/S
	declare @interval1 int, @interval2 int, @interval3 int -- Períodos
	declare @adn int = 0 -- Adicional noturno em minutos
	declare @saida varchar(20)
	declare @toleranciaanterior datetime, @toleranciaposterior datetime
	declare @jornadalivre bit
	declare @entprev datetime, @saiprev datetime
	declare @horarcodigo int
	declare @contabiliza bit
	declare @datajornada datetime
	declare @funcicodigo int

	select 
	@jornadalivre=cartajornadalivre,
	@horarcodigo=horarcodigo,
	@datajornada=cartadatajornada,
	@funcicodigo=funcicodigo,
	@s1=carta_realizado_s1,
	@e2=carta_realizado_e2,
	@s2=carta_realizado_s2,
	@e3=carta_realizado_e3,
	@s3=carta_realizado_s3,
	@e4=carta_realizado_e4 
	from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo

	set @interval1 = 0
	set @interval2 = 0
	set @interval3 = 0

	if @periodo = 1
	begin
		if @s1 is not null and @e2 is not null
		begin
			if @jornadalivre = 1
			begin
				set @interval1 = (select datediff(MINUTE,@s1,@e2));
			end
			else
			begin
				set @entprev = (select carta_previsto_s1 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				set @saiprev = (select carta_previsto_e2 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				set @toleranciaanterior = (select dateadd(minute,-carta_tolerancia_anterior_s1,carta_previsto_s1) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				-- ALTERAÇÃO 18/02/2020
				set @toleranciaposterior = (select dateadd(minute,carta_tolerancia_posterior_s1,carta_previsto_s1) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				-- BKP 18/02/2020
				--set @toleranciaposterior = (select dateadd(minute,carta_tolerancia_posterior_e2,carta_previsto_e2) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
			
				-- SE O APONTAMENTO REALIZADO ESTIVER DENTRO DA TOLERÂNCIA ANTERIOR E POSTERIOR
				if (@s1 <= @entprev and @s1 >= @toleranciaanterior) or (@s1 >= @entprev and @s1 <= @toleranciaposterior)
				begin
					set @s1 = @entprev
				end

				set @toleranciaanterior = (select dateadd(minute,-carta_tolerancia_anterior_e2,carta_previsto_e2) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				set @toleranciaposterior = (select dateadd(minute,carta_tolerancia_posterior_e2,carta_previsto_e2) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)

				-- SE O APONTAMENTO REALIZADO ESTIVER DENTRO DA TOLERÂNCIA ANTERIOR E POSTERIOR
				if (@e2 <= @saiprev and @e2 >= @toleranciaanterior) or (@e2 >= @saiprev and @e2 <= @toleranciaposterior)
				begin
					set @e2 = @saiprev
				end
				set @interval1 = (select datediff(MINUTE,@s1,@e2));
			end
			if @horarcodigo is not null and @horarcodigo <> 0
			begin
				-- APESAR DO NOME DO CAMPO ESTÁ 'DEDUZ', NA VERDADE QUANDO MARCADO, CONTABILIZA JORNADA
				set @contabiliza = (select horarintervalo1deduzjornada from tbgabhorario (nolock) where horarcodigo = @horarcodigo)
			end
			else
			begin
				set @horarcodigo = (select top 1 horarcodigo from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada < @datajornada and horarcodigo > 0 order by cartadatajornada desc)
				if @horarcodigo is null
				begin
					set @horarcodigo = (select top 1 horarcodigo from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada > @datajornada and horarcodigo > 0 order by cartadatajornada)
				end
				set @contabiliza = coalesce((select horarintervalo1deduzjornada from tbgabhorario (nolock) where horarcodigo = @horarcodigo),0)
			end
			set @saida = (select dbo.CONVERTE_MINUTO_HORA(@interval1))
			insert into @tempo values (@interval1,@saida,@s1,@e2,@contabiliza)
		end
	end
	else if @periodo = 2
	begin
		if @s2 is not null and @e3 is not null
		begin
			if @jornadalivre = 1
			begin
				set @interval2 = (select datediff(MINUTE,@s2,@e3));
			end
			else
			begin
				set @entprev = (select carta_previsto_s2 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				set @saiprev = (select carta_previsto_e3 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				set @toleranciaanterior = (select dateadd(minute,-carta_tolerancia_anterior_s2,carta_previsto_s2) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				-- ALTERAÇÃO 18/02/2020
				set @toleranciaposterior = (select dateadd(minute,carta_tolerancia_posterior_s2,carta_previsto_s2) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				-- BKP 18/02/2020
				--set @toleranciaposterior = (select dateadd(minute,carta_tolerancia_posterior_e3,carta_previsto_e3) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
			
				-- SE O APONTAMENTO REALIZADO ESTIVER DENTRO DA TOLERÂNCIA ANTERIOR E POSTERIOR
				if (@s2 <= @entprev and @s2 >= @toleranciaanterior) or (@s2 >= @entprev and @s2 <= @toleranciaposterior)
				begin
					set @s2 = @entprev
				end

				set @toleranciaanterior = (select dateadd(minute,-carta_tolerancia_anterior_e3,carta_previsto_e3) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				set @toleranciaposterior = (select dateadd(minute,carta_tolerancia_posterior_e3,carta_previsto_e3) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)

				-- SE O APONTAMENTO REALIZADO ESTIVER DENTRO DA TOLERÂNCIA ANTERIOR E POSTERIOR
				if (@e3 <= @saiprev and @e3 >= @toleranciaanterior) or (@e3 >= @saiprev and @e3 <= @toleranciaposterior)
				begin
					set @e3 = @saiprev
				end
				set @interval2 = (select datediff(MINUTE,@s2,@e3));
			end
			if @horarcodigo is not null and @horarcodigo <> 0
			begin
				-- APESAR DO NOME DO CAMPO ESTÁ 'DEDUZ', NA VERDADE QUANDO MARCADO, CONTABILIZA JORNADA
				set @contabiliza = (select horarintervalo2deduzjornada from tbgabhorario (nolock) where horarcodigo = @horarcodigo)
			end
			else
			begin
				set @horarcodigo = (select top 1 horarcodigo from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada < @datajornada and horarcodigo > 0 order by cartadatajornada desc)
				if @horarcodigo is null
				begin
					set @horarcodigo = (select top 1 horarcodigo from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada > @datajornada and horarcodigo > 0 order by cartadatajornada)
				end
				set @contabiliza = coalesce((select horarintervalo2deduzjornada from tbgabhorario (nolock) where horarcodigo = @horarcodigo),0)
			end
			set @saida = (select dbo.CONVERTE_MINUTO_HORA(@interval2))
			insert into @tempo values (@interval2,@saida,@s2,@e3,@contabiliza)
		end
	end
	else if @periodo = 3
	begin
		if @s3 is not null and @e4 is not null
		begin
			if @jornadalivre = 1
			begin
				set @interval3 = (select datediff(MINUTE,@s3,@e4));
			end
			else
			begin
				set @entprev = (select carta_previsto_s3 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				set @saiprev = (select carta_previsto_e4 from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				set @toleranciaanterior = (select dateadd(minute,-carta_tolerancia_anterior_s3,carta_previsto_s3) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				-- ALTERAÇÃO 18/02/2020
				set @toleranciaposterior = (select dateadd(minute,carta_tolerancia_posterior_s3,carta_previsto_s3) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				-- BKP 18/02/2020
				--set @toleranciaposterior = (select dateadd(minute,carta_tolerancia_posterior_s3,carta_previsto_s3) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
			
				-- SE O APONTAMENTO REALIZADO ESTIVER DENTRO DA TOLERÂNCIA ANTERIOR E POSTERIOR
				if (@s3 <= @entprev and @s3 >= @toleranciaanterior) or (@s3 >= @entprev and @s3 <= @toleranciaposterior)
				begin
					set @s3 = @entprev
				end

				set @toleranciaanterior = (select dateadd(minute,-carta_tolerancia_anterior_e4,carta_previsto_e4) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
				set @toleranciaposterior = (select dateadd(minute,carta_tolerancia_posterior_e4,carta_previsto_e4) from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)

				-- SE O APONTAMENTO REALIZADO ESTIVER DENTRO DA TOLERÂNCIA ANTERIOR E POSTERIOR
				if (@e4 <= @saiprev and @e4 >= @toleranciaanterior) or (@e4 >= @saiprev and @e4 <= @toleranciaposterior)
				begin
					set @e4 = @saiprev
				end
				set @interval3 = (select datediff(MINUTE,@s3,@e4));
			end
			if @horarcodigo is not null and @horarcodigo <> 0
			begin
				-- APESAR DO NOME DO CAMPO ESTÁ 'DEDUZ', NA VERDADE QUANDO MARCADO, CONTABILIZA JORNADA
				set @contabiliza = (select horarintervalo3deduzjornada from tbgabhorario (nolock) where horarcodigo = @horarcodigo)
			end
			else
			begin
				set @horarcodigo = (select top 1 horarcodigo from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada < @datajornada and horarcodigo > 0 order by cartadatajornada desc)
				if @horarcodigo is null
				begin
					set @horarcodigo = (select top 1 horarcodigo from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada > @datajornada and horarcodigo > 0 order by cartadatajornada)
				end
				set @contabiliza = coalesce((select horarintervalo3deduzjornada from tbgabhorario (nolock) where horarcodigo = @horarcodigo),0)
			end
			set @saida = (select dbo.CONVERTE_MINUTO_HORA(@interval3))
			insert into @tempo values (@interval3,@saida,@s3,@e4,@contabiliza)
		end
	end
	
	RETURN;
END
GO


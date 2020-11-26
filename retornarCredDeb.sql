SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






-- =============================================
-- Author:		Jean Paul
-- Create date: 01/07/2019
-- Description:	Trás os valores acumulados do período informado.
-- =============================================

-- ATUALIZAÇÕES
-- =============================================
-- Author:		Jean Paul
-- Create date: 30/07/2019
-- 1º Implementado o campo deduzmensal na função para retornar
-- =============================================
ALTER FUNCTION [dbo].[retornarCredDeb] 
(
	-- Add the parameters for the function here	
	@funcicodigo int,	
    @datajornada datetime
)
RETURNS 
-- TABELA DEBUG
@tempos table (
dia datetime, cred int, deb int, btotal int,
interval1_rea int, interval2_rea int, interval3_rea int, interval4_rea int, 
interval1_prev int, interval2_prev int, interval3_prev int, interval4_prev int,
parada1_rea int, parada2_rea int, parada3_rea int, 
parada1_prev int, parada2_prev int, parada3_prev int,
pre1 bit, pre2 bit, pre3 bit, desconsiderapre bit, adn int, ep1 datetime, sp1 datetime, horarcodigo int, d1n int, d2n int)
-- TABELA NORMAL
--@tempos table (dia datetime, cred int, deb int, btotal int)
AS
BEGIN
	declare @horarcodigo int, @desconsiderapre bit, @inicionoturno datetime, @fimnoturno datetime, @fatornoturno float, @estendenoturno bit, @jornadalivre bit, @chr int, @chp int, @ctococodigo int,@he int
	select 
	@horarcodigo=horarcodigo,
	@desconsiderapre=coalesce(cartadesconsiderapreassinalado,0),
	@jornadalivre=coalesce(cartajornadalivre,0),
	@chr=cartacargahorariarealizada,
	@chp=coalesce(cartacargahoraria,0),
	@inicionoturno=cartainicionoturno,@fimnoturno=cartafimnoturno,@fatornoturno=cartafatornoturno,
	@estendenoturno=cartaestendenoturno,@ctococodigo=ctococodigo,@he=coalesce(cartahorasextra,0)
	from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada = @datajornada
	declare @cred int = 0, @deb int = 0, @btotal int, @abonos int = 0, @adn int, @d1n int, @d2n int
	declare @interval1_prev int = 0, @interval2_prev int = 0, @interval3_prev int = 0, @interval4_prev int = 0
	declare @interval1_rea int = 0, @interval2_rea int = 0, @interval3_rea int = 0, @interval4_rea int = 0
	declare @parada1_prev int, @parada2_prev int, @parada3_prev int
	declare @parada1_rea int, @parada2_rea int, @parada3_rea int
	declare @ep1 datetime, @sp1 datetime,@ep2 datetime, @sp2 datetime,@ep3 datetime, @sp3 datetime,@ep4 datetime, @sp4 datetime
	declare @er1 datetime, @sr1 datetime,@er2 datetime, @sr2 datetime,@er3 datetime, @sr3 datetime,@er4 datetime, @sr4 datetime
	declare @preassinalado1 bit, @preassinalado2 bit, @preassinalado3 bit

	select @d1n=coalesce(adn,0),@d2n=coalesce(minutos,0) from dbo.retornarADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@datajornada,@estendenoturno)
	if @d1n > @d2n begin set @adn = @d1n - @d2n end

	if @jornadalivre = 0
	begin
		select 
		@preassinalado1=case when horarpreassinaladosaida1 = 1 and horarpreassinaladoentrada2 = 1 then 1 else 0 end, 
		@preassinalado2=case when horarpreassinaladosaida2 = 1 and horarpreassinaladoentrada3 = 1 then 1 else 0 end,
		@preassinalado3=case when horarpreassinaladosaida3 = 1 and horarpreassinaladoentrada4 = 1 then 1 else 0 end
		from tbgabhorario (nolock) where horarcodigo = @horarcodigo

		-- E/S PREVISTAS
		select @ep1=e1,@sp1=s1,@ep2=e2,@sp2=s2,@ep3=e3,@sp3=s3,@ep4=e4,@sp4=s4 from dbo.retornarHorariosPrevistos(@horarcodigo,@datajornada)
		-- E/S REALIZADAS
		select 
		@er1=carta_realizado_e1, @sr1=carta_realizado_s1, @er2=carta_realizado_e2, @sr2=carta_realizado_s2, 
		@er3=carta_realizado_e3, @sr3=carta_realizado_s3, @er4=carta_realizado_e4, @sr4=carta_realizado_s4 
		from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada = @datajornada
	
		-- PARADAS REALIZADAS
		if @sr1 is not null and @er2 is not null begin select @parada1_rea = minuto from dbo.retornarIntervalosFuncionario(@funcicodigo,@datajornada,1) end
		if @sr2 is not null and @er3 is not null begin select @parada2_rea = minuto from dbo.retornarIntervalosFuncionario(@funcicodigo,@datajornada,2) end
		if @sr3 is not null and @er4 is not null begin select @parada3_rea = minuto from dbo.retornarIntervalosFuncionario(@funcicodigo,@datajornada,3) end

		-- PARADAS PREVISTAS
		if @sp1 is not null and @ep2 is not null begin set @parada1_prev = datediff(minute,@sp1,@ep2) end
		if @sp2 is not null and @ep3 is not null begin set @parada2_prev = datediff(minute,@sp2,@ep3) end
		if @sp3 is not null and @ep4 is not null begin set @parada3_prev = datediff(minute,@sp3,@ep4) end

		-- INTERVALOS PREVISTOS
		if @ep1 is not null and @sp1 is not null and @desconsiderapre = 0 
		begin 
			set @interval1_prev = datediff(minute,@ep1,@sp1) 
		end
		else if @ep1 is not null and @sp1 is not null and @desconsiderapre = 1 
		begin 
			set @parada1_rea = 0
			set @parada2_rea = 0
			set @parada3_rea = 0
			if @preassinalado1 = 1 and @preassinalado2 = 0 and @preassinalado3 = 0
			begin
				set @interval1_prev = datediff(minute,@ep1,@sp2) 
			end
			else if @preassinalado1 = 1 and @preassinalado2 = 1 and @preassinalado3 = 0
			begin
				set @interval1_prev = datediff(minute,@ep1,@sp3) 
			end
			else if @preassinalado1 = 1 and @preassinalado2 = 1 and @preassinalado3 = 1
			begin
				set @interval1_prev = datediff(minute,@ep1,@sp4) 
			end
		end

		if @ep2 is not null and @sp2 is not null and @desconsiderapre = 0
		begin 
			set @interval2_prev = datediff(minute,@ep2,@sp2) 
		end

		if @ep3 is not null and @sp3 is not null and @desconsiderapre = 0 
		begin 
			set @interval3_prev = datediff(minute,@ep3,@sp3) 
		end

		if @ep4 is not null and @sp4 is not null and @desconsiderapre = 0 
		begin 
			set @interval4_prev = datediff(minute,@ep4,@sp4) 
		end

		-- INTERVALOS REALIZADOS
		select @interval1_rea=interval1,@interval2_rea=interval2,@interval3_rea=interval3,@interval4_rea=interval4 from dbo.retornarSomaHorasFuncionario(@funcicodigo,@datajornada)

		-- QUANDO HOUVER ATRASO NA PARADA 1 DA JORNADA
		if @parada1_prev < @parada1_rea --or @parada2_prev < @parada2_rea or @parada3_prev < @parada3_rea
		begin
			set @interval2_rea += coalesce(@parada1_rea,0)-coalesce(@parada1_prev,0)
		end
		-- QUANDO HOUVER ATRASO NA PARADA 2 DA JORNADA
		if @parada2_prev < @parada2_rea --or @parada2_prev < @parada2_rea or @parada3_prev < @parada3_rea
		begin
			set @interval3_rea += coalesce(@parada2_rea,0)-coalesce(@parada2_prev,0)
		end
		-- QUANDO HOUVER ATRASO NA PARADA 3 DA JORNADA
		if @parada3_prev < @parada3_rea --or @parada2_prev < @parada2_rea or @parada3_prev < @parada3_rea
		begin
			set @interval4_rea += coalesce(@parada3_rea,0)-coalesce(@parada3_prev,0)
		end

		-- APURAÇÃO INTERVALO 1
		if @interval1_rea > @interval1_prev begin set @cred += (@interval1_rea - @interval1_prev) end
		else if @interval1_prev > @interval1_rea begin set @deb += (@interval1_prev - @interval1_rea) end
		-- APURAÇÃO PARADA 1
		if @parada1_rea is not null and @parada1_prev is not null and @parada1_rea > @parada1_prev begin set @deb += (@parada1_rea - @parada1_prev) end
		else if @parada1_rea is not null and @parada1_prev is not null and @parada1_prev > @parada1_rea begin set @cred += (@parada1_prev - @parada1_rea) end

		-- APURAÇÃO INTERVALO 2
		if @interval2_rea > @interval2_prev begin set @cred +=  (@interval2_rea - @interval2_prev) /*+ ( coalesce(datediff(minute,@ep2,@er2),0) )*/ end
		else if @interval2_prev > @interval2_rea begin set @deb += (@interval2_prev - @interval2_rea) end
		-- APURAÇÃO PARADA 2
		if @parada2_rea is not null and @parada2_prev is not null and @parada2_rea > @parada2_prev begin set @deb += (@parada2_rea - @parada2_prev) end
		else if @parada2_rea is not null and @parada2_prev is not null and @parada2_prev > @parada2_rea begin set @cred += (@parada2_prev - @parada2_rea) end

		-- APURAÇÃO INTERVALO 3
		if @interval3_rea > @interval3_prev begin set @cred += (@interval3_rea - @interval3_prev) /*+ ( coalesce(datediff(minute,@ep3,@er3),0) )*/ end
		else if @interval3_prev > @interval3_rea begin set @deb += (@interval3_prev - @interval3_rea) end
		-- APURAÇÃO PARADA 3
		if @parada3_rea is not null and @parada3_prev is not null and @parada3_rea > @parada3_prev begin set @deb += (@parada3_rea - @parada3_prev) end
		else if @parada3_rea is not null and @parada3_prev is not null and @parada3_prev > @parada3_rea begin set @cred += (@parada3_prev - @parada3_rea) end

		-- APURAÇÃO INTERVALO 4
		if @interval4_rea > @interval4_prev begin set @cred += (@interval4_rea - @interval4_prev) /*+ ( coalesce(datediff(minute,@ep4,@er4),0) )*/ end
		else if @interval4_prev > @interval4_rea begin set @deb += (@interval4_prev - @interval4_rea) end

		set @abonos = ( select sum(ocorrvalor) from tbgabocorrencia O (nolock) 
					inner join tbgabocorrenciatipo OT (nolock) on O.tpococodigo=OT.tpococodigo
					where funcicodigo = @funcicodigo and convert(date,O.ocorrinicio) = @datajornada and OT.tpocotipo = 2 and OT.tpocosituacao = 1 
					and (OT.tpocointegravel = 0 or (OT.tpocointegravel = 1 and (O.sitme in (10,11) or OT.tpocoexigeaprovacao = 0))))
		if @abonos is null begin set @abonos = 0 end

		set @deb = @deb - @abonos
	end
	else if @jornadalivre = 1 and @ctococodigo <> 2
	begin
		if @chr - @chp > 0 begin set @cred = @chr - @chp end
		if @chr - @chp < 0 begin set @deb = @chp - @chr end
	end
	else if @ctococodigo = 2 and @he > 0
	begin
		set @cred = @he
		set @deb = 0
	end

	if coalesce(@he,0) > coalesce(@cred,0) begin set @cred = @he end

	set @btotal = @cred - @deb

	if @cred <= 0 begin set @cred = null end if @deb <= 0 begin set @deb = null end	

	-- INSERT DEBUG
	insert into @tempos 
	values (@datajornada,@cred,@deb,@btotal,@interval1_rea,@interval2_rea,@interval3_rea,@interval4_rea,@interval1_prev,@interval2_prev,
	@interval3_prev,@interval4_prev,@parada1_rea,@parada2_rea,@parada3_rea,@parada1_prev,@parada2_prev,@parada3_prev,@preassinalado1,@preassinalado2,
	@preassinalado3,@desconsiderapre, @adn, @ep1,@sp1,@horarcodigo,@d1n,@d2n)
	-- INSERT NORMAL
	--insert into @tempos values (@datajornada,@cred,@deb,@btotal)

	RETURN 
END
GO

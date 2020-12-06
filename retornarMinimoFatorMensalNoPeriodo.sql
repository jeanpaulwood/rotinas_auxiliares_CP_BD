SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[retornarMinimoFatorMensalNoPeriodo] 
(
	-- Add the parameters for the function here
	@funcicodigo bigint,
    @periodoinicio datetime,		
    @periodofim datetime	
)
RETURNS 
@tabela TABLE ( menor_fator int, menor_escala int, menor_regime smallint, dias_uteis int, horaprevistamensal int,vigencia datetime, ult_movimentacao datetime, fator_mensal int, feriasafastamento int )
AS
BEGIN
		
		declare 
		@dt datetime, @regime smallint, @menor_regime smallint, @dias_uteis int = 0, @escalcodigo int, @fatormensal int, @menor_fator int = 1440, 
		@vigencia_anterior datetime = '1900-01-01 00:00', @data_movimentacao datetime, @menor_escala int, 
		@ult_movimentacao datetime = '1900-01-01', @vigencia datetime = '1900-01-01 00:00', @previstomensal int

		declare escalas cursor for
			select E.escalfatorcargamensal, E.escalregime, FE.escalcodigo, FE.fuescdatainiciovigencia, FE.fuescdatamovimentacao from tbgabfuncionarioescala FE (nolock) 
			inner join tbgabescala E on E.escalcodigo = FE.escalcodigo 
			where funcicodigo = @funcicodigo and fuescdatainiciovigencia between @periodoinicio and @periodofim
			order by fuescdatainiciovigencia,fuescdatamovimentacao desc
		open escalas
			fetch next from escalas into @fatormensal,@regime,@escalcodigo,@dt,@data_movimentacao
			while @@FETCH_STATUS=0
			begin
				if @fatormensal < @menor_fator and @data_movimentacao > @ult_movimentacao 
				begin 
					set @menor_fator = @fatormensal set @menor_escala = @escalcodigo set @ult_movimentacao = @data_movimentacao set @vigencia = @dt set @menor_regime = @regime
				end
				else if @fatormensal < @menor_fator and @dt <> @vigencia_anterior
				begin
					set @menor_fator = @fatormensal set @menor_escala = @escalcodigo set @ult_movimentacao = @data_movimentacao set @vigencia = @dt set @menor_regime = @regime
				end
				set @vigencia_anterior = @dt
				fetch next from escalas into @fatormensal,@regime,@escalcodigo,@dt,@data_movimentacao
			end
		close escalas
		deallocate escalas

		if @menor_escala is null
		begin
			declare escalas cursor for
				select E.escalfatorcargamensal, E.escalregime, FE.escalcodigo, FE.fuescdatainiciovigencia, FE.fuescdatamovimentacao from tbgabfuncionarioescala FE (nolock) 
				inner join tbgabescala E on E.escalcodigo = FE.escalcodigo 
				where funcicodigo = @funcicodigo and fuescdatainiciovigencia <= @periodofim
				order by fuescdatainiciovigencia desc,fuescdatamovimentacao desc
			open escalas
				fetch next from escalas into @fatormensal,@regime,@escalcodigo,@dt,@data_movimentacao
				while @@FETCH_STATUS=0
				begin
					if @fatormensal < @menor_fator and @data_movimentacao > @ult_movimentacao 
					begin 
						set @menor_fator = @fatormensal set @menor_escala = @escalcodigo set @ult_movimentacao = @data_movimentacao set @vigencia = @dt set @menor_regime = @regime
					end
					else if @fatormensal < @menor_fator and @dt <> @vigencia_anterior and @data_movimentacao > @ult_movimentacao
					begin
						set @menor_fator = @fatormensal set @menor_escala = @escalcodigo set @ult_movimentacao = @data_movimentacao set @vigencia = @dt set @menor_regime = @regime
					end

					set @vigencia_anterior = @dt
					fetch next from escalas into @fatormensal,@regime,@escalcodigo,@dt,@data_movimentacao
				end
			close escalas
			deallocate escalas

		end

		if @menor_escala is null begin set @menor_fator = 0 end

		declare @diasemana smallint, @feriado bit, @indicacao smallint

		-- IMPLEMENTAÇÃO DEMANDA 280, 04/08/2020, JEAN PAUL.
		declare @acordcodigo int = 0, @cargahorariafixamensal bit = 0, @valorcargahorariafixamensal int = 0, @afastamentosOuFerias int = 0
		-- RETORNA O ÚLTIMO ACORDO DO CARTÃO DO FUNCIONÁRIO.
		select top 1 @acordcodigo=acordcodigo from tbgabcartaodeponto 
		where funcicodigo=@funcicodigo and acordcodigo is not null and cartadatajornada between @periodoinicio and @periodofim
		order by cartadatajornada desc

		-- VERIFICA SE O ACORDO POSSUI CARGA HORÁRIA FIXA
		select top 1 @cargahorariafixamensal=acordcargahorariamensalfixa, @valorcargahorariafixamensal=acordvalorcargahorariamensalfixa 
		from tbgabacordocoletivo 
		where acordcodigo=@acordcodigo
		-- SE A CARGA HORÁRIA PREVISTA MENSAL FOR BASEADA NA ESCALA, CONSIDERA OS FERIADOS.
		if coalesce(@cargahorariafixamensal,0) = 0 or coalesce(@valorcargahorariafixamensal,0) = 0
		begin
			declare dias cursor for
			select cartadiasemana,cartaflagferiado,ctococodigo from tbgabcartaodeponto (nolock) 
			where funcicodigo = @funcicodigo and cartadatajornada between @periodoinicio and @periodofim
		  
			open dias
				fetch next from dias into @diasemana, @feriado,@indicacao
				while @@FETCH_STATUS=0
				begin
				
					-- PLANTONISTA 07:20
					if @menor_regime = 2 and @diasemana <> 1 and @feriado = 0 and @indicacao <> 6 and @indicacao <> 5
					begin
						set @dias_uteis = @dias_uteis + 1
					end
					-- DIARISTA 08:48
					else if @menor_regime = 1 and @diasemana <> 1 and @diasemana <> 7 and @feriado = 0 and @indicacao <> 6 and @indicacao <> 5
					begin
						set @dias_uteis = @dias_uteis + 1
					end
					-- CONTABILIZADA FÉRIAS OU AFASTAMENTO
					if @indicacao = 5 or @indicacao = 6 begin set @afastamentosOuFerias = @afastamentosOuFerias + 1 end
				
					fetch next from dias into @diasemana, @feriado, @indicacao
				end
			close dias
			deallocate dias

			set @previstomensal = @dias_uteis * @menor_fator
		end
		-- SE A CARGA HORÁRIA MENSAL FOR BASEADA NO ACORDO COLETIVO (CARGA HORÁRIA FIXA), DESCONSIDERA OS FERIADOS.
		else
		begin
			declare dias cursor for
			select cartadiasemana,ctococodigo from tbgabcartaodeponto (nolock) 
			where funcicodigo = @funcicodigo and cartadatajornada between @periodoinicio and @periodofim
		  
			open dias
				fetch next from dias into @diasemana,@indicacao
				while @@FETCH_STATUS=0
				begin
				
					-- PLANTONISTA 07:20
					if @menor_regime = 2 and @diasemana <> 1 and @indicacao <> 6 and @indicacao <> 5
					begin
						set @dias_uteis = @dias_uteis + 1
					end
					-- DIARISTA 08:48
					else if @menor_regime = 1 and @diasemana <> 1 and @diasemana <> 7 and @indicacao <> 6 and @indicacao <> 5
					begin
						set @dias_uteis = @dias_uteis + 1
					end
					-- CONTABILIZADA FÉRIAS OU AFASTAMENTO
					if @indicacao = 5 or @indicacao = 6 begin set @afastamentosOuFerias = @afastamentosOuFerias + 1 end
				
					fetch next from dias into @diasemana, @indicacao
				end
			close dias
			deallocate dias

			set @previstomensal = @valorcargahorariafixamensal - (@afastamentosOuFerias * @menor_fator)
		end
		-- FIM DA IMPLEMENTAÇÃO, DEMANDA 280, 04/08/2020, JEAN PAUL.

		-- SE VALOR DA CARGA HORÁRIA MENSAL FOR MENOR DO QUE 0 ENTÃO ZERA O PREVISTO MENSAL PARA EVITAR DE GERAR HORA EXTRA
		if @previstomensal < 0 begin set @previstomensal = 0 end

		insert into @tabela values ( @menor_fator,@menor_escala,@menor_regime,@dias_uteis,@previstomensal,@vigencia,@ult_movimentacao,@fatormensal,@afastamentosOuFerias)

	RETURN 
END
GO

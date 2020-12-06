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
-- alter date: 30/07/2019
-- 1º Implementa a categoria de crédito de horas. Quando deduzir mensal = 1,
-- o valor acumulado dessa categoria será retirado do REALIZADO MENSAL.
-- alter date: 01/08/2019
-- 2º Implementado uma nova cláusula na função de retornar ocorrência. (inicio between @starDate and @endDate)
-- =============================================
ALTER FUNCTION [dbo].[retornarHoraPrevistaMensal] 
(
	-- Add the parameters for the function here
	@funcicodigo int,
    @startDate datetime,		
    @endDate datetime	
)
RETURNS int
AS
BEGIN
		declare 
		@horaprevistamensal int = 0, 
		@fatorhoramensal float,
		@cartacodigo int, 
		@diasemana int, 
		@escalcodigo int,
		@feriado bit, 
		@cartadatajornada datetime, 
		@indicacao int, 
		@dias_uteis int = 0, 
		@regime int, @horasabonadas int,
		@horasdeduzidasdomensal int,
		-- IMPLEMENTAÇÃO DEMADA 280, 04/08/2020, JEAN PAUL.
		@acordcodigo int = 0,
		@cargahorariafixamensal bit = 0,
		@valorcargahorariafixamensal int = 0,
		@feriasEOuAfastamento int = 0
		
		-- BKP 21/01/2019
		/*declare dias cursor for
		select cartacodigo,cartadiasemana,cartaflagferiado,cartadatajornada,ctococodigo from tbgabcartaodeponto (nolock) 
		where funcicodigo = @funcicodigo and cartadatajornada between @startDate and @endDate
		  
		open dias
			fetch next from dias into @cartacodigo, @diasemana, @feriado, @cartadatajornada,@indicacao
			while @@FETCH_STATUS=0
			begin
				
				set @escalcodigo = (select top 1 escalcodigo from tbgabfuncionarioescala (nolock) 
									where funcicodigo = @funcicodigo and fuescdatainiciovigencia <= @cartadatajornada order by fuescdatainiciovigencia desc, fuescdatamovimentacao desc)

				if @escalcodigo is null begin set @escalcodigo = 0 end
				set @regime = (select escalregime from tbgabescala (nolock) where escalcodigo = @escalcodigo)
				
				-- PLANTONISTA 07:20
				if @regime = 2 and @diasemana <> 1 and @feriado = 0 and @indicacao <> 6 and @indicacao <> 5
				begin
					set @dias_uteis = @dias_uteis + 1
				end
				-- DIARISTA 08:48
				else if @regime = 1 and @diasemana <> 1 and @diasemana <> 7 and @feriado = 0 and @indicacao <> 6 and @indicacao <> 5
				begin
					set @dias_uteis = @dias_uteis + 1
				end
				
				fetch next from dias into @cartacodigo, @diasemana, @feriado, @cartadatajornada, @indicacao
			end
		close dias
		deallocate dias

		set @fatorhoramensal = (select min(horarfatorcargamensal) from tbgabhorario H (nolock)
								inner join tbgabcartaodeponto CP (nolock) on H.horarcodigo=CP.horarcodigo 
								where funcicodigo = @funcicodigo and CP.cartadatajornada between @startDate and @endDate)*/
		select @fatorhoramensal = menor_fator,@dias_uteis = dias_uteis, @feriasEOuAfastamento = feriasafastamento from dbo.retornarMinimoFatorMensalNoPeriodo(@funcicodigo,@startDate,@endDate)
								
		if @fatorhoramensal is null begin set @fatorhoramensal = 0 end

		-- HORA PREVISTA MENSAL = 
		-- (FATOR DE HORA MENSAL x (QNTD DE DIAS ÚTEIS PARA O FUNCIONÁRIO - (QNTD DIAS C/ INDICAÇÃO DE AFASTAMENTO + INDICAÇÃO DE FÉRIAS))) - (HORAS ABONADAS DO PERÍODO + HORAS DEDUZIDAS DE FALTA)
		set @horasabonadas = (select sum(valor) from dbo.retornarOcorrencias(0,0,@funcicodigo) where categoriaocorrencia = 2 and inicio between @startDate and @endDate)
		-- HORAS DEDUZIDAS DO MENSAL DAS OCORRÊNCIAS DE FALTA
		set @horasdeduzidasdomensal = (select count(_funcicodigo) from dbo.retornarOcorrencias(0,0,@funcicodigo) 
		where categoriaocorrencia = 8 and deduzmensal = 1 and inicio between @startDate and @endDate)
		if @horasdeduzidasdomensal is null begin set @horasdeduzidasdomensal = 0 end
		set @horasdeduzidasdomensal = @fatorhoramensal * @horasdeduzidasdomensal
		if @horasabonadas is null begin set @horasabonadas = 0 end

		-- IMPLEMENTAÇÃO DEMANDA 280, 04/08/2020, JEAN PAUL.
		-- RETORNA O ÚLTIMO ACORDO DO CARTÃO DO FUNCIONÁRIO.
		select top 1 @acordcodigo=acordcodigo from tbgabcartaodeponto 
		where funcicodigo=@funcicodigo and acordcodigo is not null and cartadatajornada between @startDate and @endDate 
		order by cartadatajornada desc

		-- VERIFICA SE O ACORDO POSSUI CARGA HORÁRIA FIXA
		select top 1 @cargahorariafixamensal=acordcargahorariamensalfixa, @valorcargahorariafixamensal=acordvalorcargahorariamensalfixa 
		from tbgabacordocoletivo 
		where acordcodigo=@acordcodigo

		-- APURAÇÃO DE CARGA HORÁRIA MENSAL BASEADA NO ACORDO COLETIVO (CARGA HORÁRIA FIXA)
		if @cargahorariafixamensal = 1 and @valorcargahorariafixamensal > 0
		begin 
			set @horaprevistamensal = @valorcargahorariafixamensal - (@horasabonadas + @horasdeduzidasdomensal) - (@feriasEOuAfastamento * @fatorhoramensal)
		end
		-- APURAÇÃO DE CARGA HORÁRIA MENSAL BASEADA NA ESCALA
		else
		begin
			set @horaprevistamensal = (@fatorhoramensal * @dias_uteis) - (@horasabonadas + @horasdeduzidasdomensal)
		end
		-- FIM DA IMPLEMENTAÇÃO, DEMANDA 280, 04/08/2020, JEAN PAUL.

		-- SE VALOR DA CARGA HORÁRIA MENSAL FOR MENOR DO QUE 0 ENTÃO ZERA O PREVISTO MENSAL PARA EVITAR DE GERAR HORA EXTRA
		if @horaprevistamensal < 0 begin set @horaprevistamensal = 0 end

	RETURN @horaprevistamensal
END
GO

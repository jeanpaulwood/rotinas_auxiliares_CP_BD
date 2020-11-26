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
ALTER FUNCTION [dbo].[retornarAcumuladores] 
(
	-- Add the parameters for the function here
	@funcicodigo bigint,
    @startDate datetime,		
    @endDate datetime	
)
RETURNS 
@tabela TABLE 
(
  horaprevistaescala int,
  horadia int,
  horafaltamensal int,
  horainterval int, 
  dias_uteis int, 
  horaextramensal int, 
  horaprevistamensal int, 
  horanoturna int,
  horafatormensal int
)
AS
BEGIN
		declare 
		@horaprevistaescala int, 
		@horadia int, 
		@horafalta int, 
		@horainterval int = 0, 
		@horaextra int, 
		@horanoturna int, 
		@horaprevistamensal int = 0,
		@dias_uteis int = 0, 
		@diasemana int, 
		@feriado bit, 
		@regime int = 0, 
		@cartadatajornada datetime, 
		@fatorhoramensal int, 
		@indicacao smallint, 
		@horasabonadas int, 
		@horasdeduzidasdomensal int, 
		@escalcodigo int,
		-- IMPLEMENTAÇÃO DEMADA 280, 04/08/2020, JEAN PAUL.
		@acordcodigo int = 0,
		@cargahorariafixamensal bit = 0,
		@valorcargahorariafixamensal int = 0,
		@feriasEOuAfastamento int = 0

		-- HORA PREVISTA MENSAL
		set @horaprevistaescala = (select sum(cartacargahoraria) from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada between @startDate and @endDate)
		-- HORA REALIZADA MENSAL = HORA REALIZADA MENSAL - VALOR ACUMULADO DAS OCORRÊNCIAS DE CRÉDITO DE HORAS COM DEDUZ MENSAL MARCADO COMO SIM
		set @horadia = (select sum(cartacargahorariarealizada) from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada between @startDate and @endDate)
		--set @horadia = @horadia - (select coalesce(sum(valor),0) from dbo.retornarOcorrencias(0,0,@funcicodigo) where categoriaocorrencia = 3 and deduzmensal = 1)
		-- HORA FALTA
		set @horafalta = (select sum(cartahorasfalta) from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada between @startDate and @endDate)
		-- HORA NOTURNA
		set @horanoturna = (select sum(cartaadn) from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada between @startDate and @endDate)

		select @fatorhoramensal = menor_fator,@dias_uteis = dias_uteis, @feriasEOuAfastamento = feriasafastamento from dbo.retornarMinimoFatorMensalNoPeriodo(@funcicodigo,@startDate,@endDate)

		if @fatorhoramensal is null begin set @fatorhoramensal = 0 end

		-- HORA PREVISTA MENSAL = (FATOR DE HORA MENSAL x (QNTD DE DIAS ÚTEIS PARA O FUNCIONÁRIO - (QNTD DIAS C/ INDICAÇÃO DE AFASTAMENTO + INDICAÇÃO DE FÉRIAS))) - (HORAS ABONADAS DO PERÍODO + HORAS DEDUZIDAS DE FALTA)
		set @horasabonadas = (select sum(valor) from dbo.retornarOcorrencias(0,0,@funcicodigo) where categoriaocorrencia = 2 and inicio between @startDate and @endDate)
		set @horasdeduzidasdomensal = (select count(_funcicodigo) from dbo.retornarOcorrencias(0,0,@funcicodigo) where categoriaocorrencia = 8 and deduzmensal = 1 and inicio between @startDate and @endDate)
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

		-- HORA FALTA MENSAL = HORA PREVISTA MENSAL - HORA DIA DO MÊS
		set @horafalta = @horaprevistamensal - @horadia
		if @horafalta < 0 begin set @horafalta = 0 end

		-- HORA EXTRA MENSAL = HORA DIA DO MÊS - HORA PREVISTA MENSAL
		set @horaextra = @horadia - @horaprevistamensal
		if @horaextra <= 0 begin set @horaextra = 0 end

		insert into @tabela values (@horaprevistaescala,@horadia,@horafalta,@horainterval,@dias_uteis,@horaextra,@horaprevistamensal,@horanoturna,@fatorhoramensal)
		

	RETURN 
END
GO

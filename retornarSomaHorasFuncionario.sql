


/****** Object:  UserDefinedFunction [dbo].[retornarSomaHorasFuncionario]    Script Date: 26/11/2020 11:17:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO







-- =============================================
-- Author:		Jean Paul
-- Create date: 23/05/2019
-- Description:	Trás a soma da carga horária do funcionário
-- =============================================
-- ATUALIZAÇÃO
-- =============================================
-- Author:		Jean Paul
-- Create date: 14/08/2019
-- Description:	Implementado melhoria no código através da nova função criada de retornar períodos do funcionário
-- =============================================
ALTER FUNCTION [dbo].[retornarSomaHorasFuncionario] 
(
	-- Add the parameters for the function here
	@cartacodigo bigint
)
RETURNS 
@tempo table (minuto int,saida varchar(20),interval1 int, interval2 int, interval3 int, interval4 int,adn int,adnsemfator int, horasfalta int, horasprevistas int, adnocorrencia int)
AS
BEGIN	
	declare @minutos int, @horas int
	declare @interval1 int, @interval2 int, @interval3 int, @interval4 int -- Períodos
	declare @periodo1 int, @periodo2 int, @periodo3 int -- Intervalos
	declare @contador int = 0 
	declare @adn int = 0 -- Adicional noturno em minutos
	declare @saida varchar(20), @ctocodescricao varchar(20);
	declare @jornadalivre bit -- Indica se o funcionário está marcado como jornada livre
	declare @entprev datetime, @saiprev datetime -- Entradas e saídas previstas
	declare @horasfalta int = 0 -- Faltas e atrasos do funcionário
	declare @horasprevistas int -- Carga horária prevista para o funcionário 
	declare @funcicodigo int
	declare @inicionoturno datetime
	declare @fimnoturno datetime
	declare @fatornoturno float
	declare @cartadata datetime
	declare @estendenoturno bit
	declare @adnsemfator int
	declare @adnocorrencia int

	select 
	@horasprevistas=cartacargahoraria,
	@funcicodigo=funcicodigo,
	@inicionoturno=cartainicionoturno,
	@fimnoturno=cartafimnoturno,
	@fatornoturno=cartafatornoturno,
	@cartadata=cartadatajornada,
	@estendenoturno=cartaestendenoturno,
	@jornadalivre=cartajornadalivre,
	@adn=cartaadn
	from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo

	set @adnocorrencia = (select sum(cartovaloracumulado) from tbgabcartaototalizador (nolock) where funcicodigo = @funcicodigo and cartodatajornada = @cartadata and catcartocodigo in (114,115))

	if @inicionoturno is not null and @fimnoturno is not null
	begin
		set @adnsemfator = (select coalesce(minutos,0) from dbo.retornarADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
	end
	else
	begin
		set @adnsemfator = 0
	end

	if @horasprevistas is null
	begin
		set @horasprevistas = 0
	end

	select @interval1 = coalesce(minuto,0),@contador=@contador+cont from dbo.retornarPeriodoFuncionario(@cartacodigo,1)
	select @interval2 = coalesce(minuto,0),@contador=@contador+cont from dbo.retornarPeriodoFuncionario(@cartacodigo,2)
	select @interval3 = coalesce(minuto,0),@contador=@contador+cont from dbo.retornarPeriodoFuncionario(@cartacodigo,3)
	select @interval4 = coalesce(minuto,0),@contador=@contador+cont from dbo.retornarPeriodoFuncionario(@cartacodigo,4)
	
	set @periodo1 = coalesce((select minuto from dbo.retornarIntervalosFuncionario(@cartacodigo,1) where contabiliza = 1),0)
	set @periodo2 = coalesce((select minuto from dbo.retornarIntervalosFuncionario(@cartacodigo,2) where contabiliza = 1),0)
	set @periodo3 = coalesce((select minuto from dbo.retornarIntervalosFuncionario(@cartacodigo,3) where contabiliza = 1),0)

	if @contador % 2 = 0
	begin -- NÚMERO PAR DE APONTAMENTOS
		set @minutos = @interval1 + @interval2 + @interval3 + @interval4 + @periodo1 + @periodo2 + @periodo3;
		
		if @minutos > 0
		begin
			--set @adn = (select cartaadn from tbgabcartaodeponto (nolock) where cartacodigo = @cartacodigo)
			if @adn is null begin set @adn = 0 end
			if @adnocorrencia is null begin set @adnocorrencia = 0 end
			set @minutos = @minutos - @adnsemfator
			
			set @minutos = @minutos + (@adn - @adnocorrencia);
			set @saida = (select dbo.CONVERTE_MINUTO_HORA(@minutos))
		end
		else
		begin
			set @saida = 'INCONSISTÊNCIA';	
		end
	end
	else
	begin -- NÚMERO ÍMPAR DE APONTAMENTOS
		set @minutos = 0;
		set @saida = 'INCONSISTÊNCIA';
	end

	if @contador = 8 
	begin -- SEM APONTAMENTOS NO DIA
		set @minutos = 0;
		set @ctocodescricao = (select ctocodescricao from tbgabcartaodeponto CA (nolock) 
		left join tbgabcartaoocorrencia CO (nolock) on CA.ctococodigo=CO.ctococodigo where CA.cartacodigo = @cartacodigo)
		if @ctocodescricao = 'Trabalho'
		begin 
			set @saida = 'FALTA';
		end
		else
		begin
			set @saida = '';
		end
	end

	if @minutos < @horasprevistas
	begin
		declare @compensacao int = 0
		select @compensacao = coalesce(cartovaloracumulado,0) from tbgabcartaototalizador (nolock) where funcicodigo = @funcicodigo and cartodatajornada = @cartadata and catcartocodigo = 16
		if @compensacao is null begin set @compensacao = 0 end
		set @horasfalta = @horasprevistas - @minutos - @compensacao
		if @horasfalta < 0 or @horasfalta is null begin set @horasfalta = 0 end
	end

	insert into @tempo values (@minutos,@saida,@interval1,@interval2,@interval3,@interval4,@adn,@adnsemfator,@horasfalta,@horasprevistas,@adnocorrencia)

	RETURN;
END
GO


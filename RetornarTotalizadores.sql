SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[RetornarTotalizadores](@acordcodigo bigint,@funcicodigo bigint, @datajornada datetime)
RETURNS 
/*@totalizador_teste TABLE (
minutos int,dom bit,seg bit,ter bit,qua bit,qui bit,sex bit,sab bit,folga bit,feriado bit,dsr bit, categoria int, m1 int, m2 int, operador bit,flag bit, 
totalcodigo int, dia smallint, faixainicio int, faixafim int, rubrica int, percentual float)*/

@totalizador TABLE (minutos int,categoria int,flag bit, totalcodigo int, faixainicio int, faixafim int, rubrica int, percentual float, horarealizada int)
AS
BEGIN
	DECLARE @dom bit, @seg bit, @ter bit, @qua bit, @qui bit, @sex bit, @sab bit -- DIAS
	DECLARE @dsr bit, @folga bit, @feriado bit -- OCORRÊNCIAS
	DECLARE @ordem1 int, @categoria int, @faixainicio int, @faixafim int -- ORDEM, CLASSE E FAIXAS DOS TOTALIZADORES
	DECLARE @m1 int = 0, @m2 int = 0, @m3 int = 0, @m4 int = 0 -- REGISTRADORES
	DECLARE @inicionoturno datetime, @fimnoturno datetime, @fatornoturno float, @estendenoturno bit -- VALORES PARA RECUPERAR ADN
	DECLARE @minutos int -- SAÍDA
	DECLARE @dia int, @ocorrencia int -- OCORRÊNCIA
	DECLARE @flag bit -- FLAG PARA LIBERAR OU NÃO O CÁLCULO DO TOTALIZADOR
	DECLARE @operador bit -- VÁRIAVEL PARA DEFINIR A CLÁUSULA
	DECLARE @totalcodigo int
	declare @flagferiado bit
	declare @rubricodigo int
	declare @percentual float
	
	select 
	@flagferiado=cartaflagferiado,
	@dia=cartadiasemana,
	@ocorrencia=ctococodigo from tbgabcartaodeponto (nolock) 
	where funcicodigo = @funcicodigo and cartadatajornada = @datajornada

    DECLARE totalizadores CURSOR FOR
		select 
		/*totalflagdiadom,
		totalflagdiaseg,
		totalflagdiater,
		totalflagdiaqua,
		totalflagdiaqui,
		totalflagdiasex,
		totalflagdiasab,
		totalflagsituacaofolga,
		totalflagsituacaoferiado,
		totalflagsituacaodsr,
		totalfaixainicio,
		totalfaixafim,
		totalcolunarubrica,
		totcacodigo,
		totaloperadorlogico,
		T.totalcodigo,
		T.rubricodigo,
		totalpercentualagrupamento*/
		
		totalfaixainicio,
		totalfaixafim,
		totcacodigo,
		totaloperadorlogico,
		T.totalcodigo,
		T.rubricodigo,
		totalpercentualagrupamento

		from tbgabtotalizadortipo T (nolock)
		inner join tbgabtotalizadoracordocoletivo TA (nolock) on T.totalcodigo=TA.totalcodigo
		inner join tbgabacordocoletivo A (nolock) on TA.acordcodigo=A.acordcodigo
		where A.acordcodigo = @acordcodigo and T.totalflagvisualizacartao = 1 and T.totaltipoapuracao = 1
	OPEN totalizadores
	--FETCH NEXT FROM totalizadores INTO @dom,@seg,@ter,@qua,@qui,@sex,@sab,@folga,@feriado,@dsr,@faixainicio,@faixafim,@ordem1,@categoria,@operador,@totalcodigo,@rubricodigo,@percentual -- CURSOR PARA DEBUG
	FETCH NEXT FROM totalizadores INTO @faixainicio,@faixafim,@categoria,@operador,@totalcodigo,@rubricodigo,@percentual
	WHILE @@FETCH_STATUS = 0
	BEGIN
		set @minutos = 0
		set @m1 = 0
		set @m2 = 0
		set @m3 = 0
		set @m4 = 0
		set @flag = (select dbo.retornarTotalizadorAtivo(@funcicodigo,@datajornada,@operador,@totalcodigo))
		
		if @flag = 1
		begin
			-- CATEGORIA ADN
			if @categoria = 2
			begin
				
				select 
				@inicionoturno=cartainicionoturno,
				@fimnoturno=cartafimnoturno,
				@fatornoturno=cartafatornoturno,
				@estendenoturno=cartaestendenoturno 
				from tbgabcartaodeponto (nolock) where funcicodigo=@funcicodigo and cartadatajornada=@datajornada

				-- RECUPERA VALOR DE ADN
				set @m1 = (select adn from dbo.retornarADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@datajornada,@estendenoturno))
				-- VERIFICA SE O VALOR RETORNADO ESTÁ DENTRO DA FAIXA
				if @faixainicio < @m1 and @m1 <= @faixafim
				begin
					set @m1 = @m1 - @faixainicio
				end
				-- VERIFICA SE O VALOR NÃO ALCANÇA A FAIXA
				else if @m1 <= @faixainicio
				begin
					set @m1 = 0
				end
				-- VERIFICA SE O VALOR ULTRAPASSA A FAIXA
				else if @faixafim <= @m1
				begin
					set @m1 = @faixafim - @faixainicio
				end
				set @minutos = @m1
			end -- END @categoria = 2

			-- CATEGORIA HORA REALIZADA
			else if @categoria = 6
			begin
				-- RECUPERAR HORA REALIZADA
				set @m1 = (select minuto from dbo.retornarSomaHorasFuncionario(@funcicodigo,@datajornada))
				-- VERIFICA SE O VALOR RETORNADO ESTÁ DENTRO DA FAIXA
				if @faixainicio < @m1 and @m1 <= @faixafim
				begin
					set @m2 = @m1 - @faixainicio
					set @m1 = @m1 - @m2
				end
				-- VERIFICA SE O VALOR NÃO ALCANÇA A FAIXA
				else if @m1 <= @faixainicio
				begin
					set @m2 = 0
				end
				-- VERIFICA SE O VALOR ULTRAPASSA A FAIXA
				else if @faixafim <= @m1
				begin
					set @m2 = @faixafim - @faixainicio
					set @m1 = @m1 - @m2
				end
				set @minutos = @m2
			end -- END if @categoria = 6
			
			-- CATEGORIA HORA EXTRA
			else if @categoria = 1
			begin
				-- RECUPERAR HORA REALIZADA
				set @m1 = (select minuto from dbo.retornarSomaHorasFuncionario(@funcicodigo,@datajornada))
	
				-- RECUPERA HORA PREVISTA
				set @m2 = (select coalesce(horasprevistas,0) from dbo.retornarSomaHorasFuncionario(@funcicodigo,@datajornada))
				-- VERIFICA SE A HORA REALIZADA É MAIOR DO QUE A HORA PREVISTA
				if @m1 > @m2
				begin
					set @m3 = @m1 - @m2
					-- VERIFICA SE O VALOR RETORNADO ESTÁ DENTRO DA FAIXA
					if @faixainicio < @m3 and @m3 <= @faixafim
					begin
						-- HORA EXTRA
						set @m4 = @m3 - @faixainicio
						-- HORA REALIZADA
						set @m1 = @m1 - @m4
					end
					-- VERIFICA SE O VALOR NÃO ALCANÇA A FAIXA
					else if @m3 <= @faixainicio
					begin
						set @m4 = NULL
					end
					-- VERIFICA SE O VALOR ULTRAPASSA A FAIXA
					else if @faixafim <= @m3
					begin
						-- HORA EXTRA
						set @m4 = @faixafim - @faixainicio
						-- HORA REALIZADA
						set @m1 = @m1 - @m4
					end
					-- HORA EXTRA PARA SER INCLUÍDA NO TOTALIZADOR
					set @minutos = @m4

				end -- if @m1 > @m2
				
			end -- END if @categoria = 1
			
		end -- END if @flag = 1
		
		--insert into @totalizador_teste values (@minutos,@dom,@seg,@ter,@qua,@qui,@sex,@sab,@folga,@flagferiado,@dsr,@categoria,@m1,@m2,@operador,@flag,@totalcodigo,@dia,@faixainicio,@faixafim,@rubricodigo,@percentual)
		insert into @totalizador values (@minutos,@categoria,@flag,@totalcodigo,@faixainicio,@faixafim,@rubricodigo,@percentual,@m1)
	--FETCH NEXT FROM totalizadores INTO @dom,@seg,@ter,@qua,@qui,@sex,@sab,@folga,@feriado,@dsr,@faixainicio,@faixafim,@ordem1,@categoria,@operador,@totalcodigo,@rubricodigo,@percentual -- CURSOR PARA DEBUG
	FETCH NEXT FROM totalizadores INTO @faixainicio,@faixafim,@categoria,@operador,@totalcodigo,@rubricodigo,@percentual
	END
	CLOSE totalizadores
	DEALLOCATE totalizadores  
    RETURN;
END
GO




/****** Object:  StoredProcedure [dbo].[spug_incluirTotalizadores]    Script Date: 26/11/2020 11:15:53 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Jean Paul
-- Create date: 16/07/2019
-- Description:	Lista os totalizadores diário e insere na tabela de cartão totalizadores
-- =============================================
-- ATUALIZAÇÕES
-- =============================================
-- Author:		Jean Paul
-- Alter date: 31/07/2019
-- Description:	Implementado um novo campo (ocorrcodigo) na tabela de cartão totalizador.
-- Author:		Jean Paul
-- Alter date: 03/08/2019
-- Description:	Implementado um novo campo (cartohgmensalcomplementar) na tabela de cartão totalizador.
-- Alter date: 05/08/2019
-- Description:	Retirado o campo cartohgmensalcomplementar da tabela de cartão totalizador e 
-- implementado um novo campo (catcartocodigo) na tabela de cartão totalizador.
-- Alter date: 12/08/2019
-- Description: Adicionado na clausula order by o campo totalpercentualagrupamento desc
-- Description: Implementado uma crítica de caso posteriormente seja adicionado um novo totalizador de valor de agrupamento maior
-- e já exista um totalizador de mesma categoria na base de dados, exclua o totalizador antigo para se colocar o novo. 
-- Alter date: 16/08/2019
-- Description: Separado a forma de apurar os totalizadores principais, de garantia e de banco de horas
-- Alter date: 19/08/2019
-- Description: Implementado a função que faz a verificação de totalizadores para o mesmo dia para melhor legibilidade de código e
-- alterado a query do cursor que traz os totalizadores, para que traga os mesmos que tenham valor maior que 0, ordenando por minutos desc
-- Alter date: 21/08/2019
-- Description: Implementado critica para verificar se cursor tem valor, se não existe, apaga por precaução.
-- =============================================

ALTER PROCEDURE [dbo].[spug_incluirTotalizadores](@acordcodigo int,@funcicodigo int, @datajornada datetime,@origem varchar(150)) -- ATUAL
AS
BEGIN
	DECLARE @faixainicio int, @faixafim int -- FAIXAS DOS TOTALIZADORES
	DECLARE @m1 int, @m2 int, @m3 int, @m4 int -- REGISTRADORES
	--DECLARE @inicionoturno datetime, @fimnoturno datetime, @fatornoturno float, @estendenoturno bit -- VALORES PARA RECUPERAR ADN
	DECLARE @cartacodigo bigint-- VALORES PARA RECUPERAR HORAS REALIZADAS E HORAS FALTA
	DECLARE @minutos int, @complementar float, @leidomotorista bit -- SAÍDA
	DECLARE @flag bit -- FLAG PARA LIBERAR OU NÃO O CÁLCULO DO TOTALIZADOR
	DECLARE @flag2 int -- FLAG PARA VERIFICAR SE EXISTE MAIS DE UM TOTALIZADOR DE MESMA CATEGORIA PARA O MESMO DIA
	DECLARE @operador bit -- VÁRIAVEL PARA DEFINIR A CLÁUSULA
	DEClARE @totalcodigo int, @rubricodigo int, @percentualagrupamento float, @mes int, @ano int, @count int, @funcionariobh bit = 0,@totalcodigoaux int = null, @ctococodigo int
	DECLARE @totalcompensavel smallint, @tipocompensacao smallint,@totalfatorcompensacao float, @totalabsolutoinicio int, @totalabsolutofim int,@totalproporcionalvalor float
	DECLARE @valor int,@faltas int, @pis varchar(11), @categoria smallint, @tp float = 0, @horasfalta int
	DECLARE @periodoiniciodatabase datetime, @periodofimdatabase datetime

	select @mes=cartamesbase,@ano=cartaanobase,@cartacodigo=cartacodigo ,@ctococodigo=ctococodigo from tbgabcartaodeponto (nolock) 
	where funcicodigo = @funcicodigo and cartadatajornada = @datajornada

	select @periodoiniciodatabase=min(cartadatajornada),@periodofimdatabase=max(cartadatajornada) from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartaanobase = @ano and cartamesbase = @mes
	
	-- FLAG PARA INDICAR SE O FUNCIONÁRIO PARTICIPA DE BANCO DE HORAS
	--select @leidomotorista=coalesce(funcileimotorista,0) from tbgabfuncionario (nolock) where funcicodigo = @funcicodigo
	select @leidomotorista=dbo.retornarSituacaoLeiMotoristaFuncionario(@funcicodigo,@periodoiniciodatabase,@periodofimdatabase)
	select @funcionariobh=dbo.retornarSituacaoBhFuncionario(@funcicodigo,@datajornada)
	
	-- LIMPA TODOS OS CARTÕES TOTALIZADORES DIÁRIOS DO DIA
	delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and cartodatajornada = @datajornada and totalcodigo > 0
	--set @m1 = (select valor from dbo.retornarTotalTotalizadoresDia(@funcicodigo,@datajornada))
	--select @m1
	set @m1 = null
	update tbgabcartaodeponto set cartahorasextra = @m1, cartasaldoanteriorbh = null,cartacreditobh = null,cartadebitobh = null ,cartasaldoatualbh = null  
	where funcicodigo = @funcicodigo and cartadatajornada = @datajornada
	set @m1 = 0
	-- ===========================================================
	-- TOTALIZADORES PRINCIPAIS                                  =
	-- ===========================================================
	
		-- TOTALIZADORES PRINCIPAIS ADN,HR,HE
		DECLARE totalizadores CURSOR FOR
			--select totalcodigo,minutos,flag,faixainicio,faixafim,rubrica,categoria,percentual from dbo.RetornarTotalizadores(@acordcodigo,@funcicodigo,@datajornada) /*where minutos > 0*/ order by CASE WHEN categoria=2 THEN 0 ELSE 2 END, percentual desc,minutos desc
			select TT.totalcodigo,TT.totalfaixainicio,TT.totalfaixafim,TT.rubricodigo,TT.totcacodigo,TT.totalpercentualagrupamento,TT.totaloperadorlogico 
			from tbgabtotalizadortipo TT (nolock) 
			where TT.totalcodigo in
			(select totalcodigo from tbgabtotalizadoracordocoletivo TA (nolock) where acordcodigo = @acordcodigo) and TT.totaltipoapuracao = 1
			order by CASE WHEN TT.totcacodigo=2 THEN 0 ELSE 2 END, TT.totalpercentualagrupamento desc
		OPEN totalizadores
		--FETCH NEXT FROM totalizadores INTO @totalcodigo,@minutos,@flag,@faixainicio,@faixafim,@rubricodigo,@categoria,@percentualagrupamento
		FETCH NEXT FROM totalizadores INTO @totalcodigo,@faixainicio,@faixafim,@rubricodigo,@categoria,@percentualagrupamento,@operador
		WHILE @@FETCH_STATUS = 0
		BEGIN
			set @totalcodigoaux = null
			set @m1 = 0
			set @m2 = 0
			set @m3 = 0
			set @m4 = 0
			set @flag = 0
			set @flag = (select dbo.retornarTotalizadorAtivo(@funcicodigo,@datajornada,@operador,@totalcodigo))
			-- SE TOTALIZADOR ATIVO
			if @flag = 1
			begin	
				-- ADN
				if @categoria = 2
				begin
					select @minutos=minutos,@m1=horarealizada from dbo.RetornarTotalizadores(@acordcodigo,@funcicodigo,@datajornada) where totalcodigo = @totalcodigo
					-- VERIFICA SE POSSUI TOTALIZADOR DE MESMA CATEGORIA COM FAIXAS DE HORÁRIO CONFLITANTE E VALOR DE AGRUPAMENTO MAIOR 
					set @flag2 = (select count(totalcodigo) from dbo.verificaTotalizadoresDiariosComMesmoDiaFaixa(@funcicodigo,@datajornada,@acordcodigo,@totalcodigo,@faixainicio,@faixafim,@percentualagrupamento,1))
		
					if @minutos > 0 and @flag2 = 0
					begin

						-- VERIFICA SE POSSUI TOTALIZADOR DE MESMA CATEGORIA COM FAIXAS DE HORÁRIO CONFLITANTES E VALOR DE AGRUPAMENTO MENOR 
						/*set @flag2 = (select count(totalcodigo) from dbo.verificaTotalizadoresDiariosComMesmoDiaFaixa(@funcicodigo,@datajornada,@acordcodigo,@totalcodigo,@faixainicio,@faixafim,@percentualagrupamento,0))

						if @flag2 > 0 begin 
							-- VERIFICA SE HÁ UM CARTÃO TOTALIZADOR DO TIPO HE OU HR REALIZADA, CASO TENHA, APAGA.
							set @totalcodigoaux = (select top 1 CT.totalcodigo from tbgabcartaototalizador CT 
							left join tbgabtotalizadortipo TT (nolock) on CT.totalcodigo=TT.totalcodigo
							where cartodatajornada = @datajornada and funcicodigo = @funcicodigo and TT.totcacodigo = 2)
							if @totalcodigoaux is not null 
							begin 
								delete from tbgabcartaototalizador 
								where cartodatajornada = @datajornada and funcicodigo = @funcicodigo and totalcodigo = @totalcodigoaux
							end
							-- LIMPA A VÁRIAVEL
							set @totalcodigoaux = null
						end*/
						/*delete from tbgabcartaototalizador 
						where cartodatajornada = @datajornada and funcicodigo = @funcicodigo and totalcodigo = @totalcodigo*/
						begin try
							-- INSERE O VALOR DO TOTALIZADOR NA TABELA DE CARTÃO TOTALIZADOR
							insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
							cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
							@funcicodigo,@totalcodigo,@rubricodigo,@minutos,@mes,@ano,@percentualagrupamento,@datajornada,4)
						
							-- PEGA O VALOR JÁ EXISTENTE NO REGISTRO DO DIA CORRENTE NA TABELA DE CARTÃO DE PONTO DO FUNCIONÁRIO.
							set @m1 = (select coalesce(cartaadn,0) from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada = @datajornada)
				
							-- AGREGA O VALOR JÁ EXISTENTE COM UM EVENTUAL NOVO TOTALIZADOR DE MESMA CATEGORIA
							update tbgabcartaodeponto set cartaadn = @minutos where cartacodigo = @cartacodigo

							-- ATUALIZA O VALOR DA HORA DIA
							set @m1 = (select minuto from dbo.retornarSomaHorasFuncionario(@cartacodigo))
							update tbgabcartaodeponto set cartacargahorariarealizada = @m1 where cartacodigo = @cartacodigo
						end try
						begin catch
							insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,error)
							values (@funcicodigo,@datajornada,@origem,ERROR_MESSAGE())
						end catch;
					end -- END if @minutos > 0 and @flag2 = 0
				end

				-- REALIZADA
				else if @categoria = 6
				begin
					select @minutos=minutos,@m1=horarealizada from dbo.RetornarTotalizadores(@acordcodigo,@funcicodigo,@datajornada) where totalcodigo = @totalcodigo
					-- VERIFICA SE POSSUI TOTALIZADOR DE MESMA CATEGORIA COM FAIXAS DE HORÁRIO CONFLITANTE E VALOR DE AGRUPAMENTO MAIOR 
					set @flag2 = (select count(totalcodigo) from dbo.verificaTotalizadoresDiariosComMesmoDiaFaixa(@funcicodigo,@datajornada,@acordcodigo,@totalcodigo,@faixainicio,@faixafim,@percentualagrupamento,1))

					-- SE HÁ VALOR A TOTALIZAR
					if @minutos > 0 and @flag2 = 0
					begin

						-- VERIFICA SE POSSUI TOTALIZADOR DE MESMA CATEGORIA COM FAIXAS DE HORÁRIO CONFLITANTES E VALOR DE AGRUPAMENTO MENOR 
						/*set @flag2 = (select count(totalcodigo) from dbo.verificaTotalizadoresDiariosComMesmoDiaFaixa(@funcicodigo,@datajornada,@acordcodigo,@totalcodigo,@faixainicio,@faixafim,@percentualagrupamento,0))

						if @flag2 > 0 
						begin 
							-- VERIFICA SE HÁ UM CARTÃO TOTALIZADOR DO TIPO HE OU HR REALIZADA, CASO TENHA, APAGA.
							set @totalcodigoaux = (select top 1 CT.totalcodigo from tbgabcartaototalizador CT 
							left join tbgabtotalizadortipo TT (nolock) on CT.totalcodigo=TT.totalcodigo
							where cartodatajornada = @datajornada and funcicodigo = @funcicodigo and TT.totcacodigo in (1,6))
							if @totalcodigoaux is not null 
							begin 
								delete from tbgabcartaototalizador 
								where cartodatajornada = @datajornada and funcicodigo = @funcicodigo and totalcodigo = @totalcodigoaux
							end
							-- LIMPA A VÁRIAVEL
							set @totalcodigoaux = null
						end*/

						-- ABATER AS HORAS A MAIS DAS HORAS REALIZADAS
						--update tbgabcartaodeponto set cartacargahorariarealizada = @m1 where cartacodigo = @cartacodigo

						/*delete from tbgabcartaototalizador 
						where cartodatajornada = @datajornada and funcicodigo = @funcicodigo and totalcodigo = @totalcodigo*/

						begin try
							-- CARTÃO TOTALIZADOR PRINCIPAL
							insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
							cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
							@funcicodigo,@totalcodigo,@rubricodigo,@minutos,@mes,@ano,@percentualagrupamento,@datajornada,4)

							-- AGREGA O VALOR JÁ EXISTENTE COM UM EVENTUAL NOVO TOTALIZADOR DE CATEGORIA HORA EXTRA OU CATEGORIA HORA REALIZADA
							set @minutos = (select valor from dbo.retornarTotalTotalizadoresDia(@funcicodigo, @datajornada))
							update tbgabcartaodeponto set cartahorasextra = @minutos, cartacargahorariarealizada = @m1 where cartacodigo = @cartacodigo
						end try
						begin catch
							insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,error)
							values (@funcicodigo,@datajornada,@origem,ERROR_MESSAGE())
						end catch;	
					end
				end

				-- EXTRA
				else if @categoria = 1
				begin
					select @minutos=minutos,@m1=horarealizada from dbo.RetornarTotalizadores(@acordcodigo,@funcicodigo,@datajornada) where totalcodigo = @totalcodigo
					-- VERIFICA SE POSSUI TOTALIZADOR DE MESMA CATEGORIA COM FAIXAS DE HORÁRIO CONFLITANTE E VALOR DE AGRUPAMENTO MAIOR 
					set @flag2 = (select count(totalcodigo) from dbo.verificaTotalizadoresDiariosComMesmoDiaFaixa(@funcicodigo,@datajornada,@acordcodigo,@totalcodigo,@faixainicio,@faixafim,@percentualagrupamento,1))
					
					-- VERIFICA SE HÁ HORA EXTRA
					if @minutos > 0 and @flag2 = 0
					begin
						
						-- VERIFICA SE POSSUI TOTALIZADOR DE MESMA CATEGORIA COM FAIXAS DE HORÁRIO CONFLITANTE E VALOR DE AGRUPAMENTO MENOR 
						/*set @flag2 = (select count(totalcodigo) from dbo.verificaTotalizadoresDiariosComMesmoDiaFaixa(@funcicodigo,@datajornada,@acordcodigo,@totalcodigo,@faixainicio,@faixafim,@percentualagrupamento,0))
						
						if @flag2 > 0 
						begin 
							-- VERIFICA SE HÁ UM CARTÃO TOTALIZADOR DO TIPO HE OU HR REALIZADA, CASO TENHA, APAGA.
							set @totalcodigoaux = (select top 1 CT.totalcodigo from tbgabcartaototalizador CT 
							left join tbgabtotalizadortipo TT (nolock) on CT.totalcodigo=TT.totalcodigo
							where cartodatajornada = @datajornada and funcicodigo = @funcicodigo and TT.totcacodigo in (1,6))
							if @totalcodigoaux is not null 
							begin 
								delete from tbgabcartaototalizador 
								where cartodatajornada = @datajornada and funcicodigo = @funcicodigo and totalcodigo = @totalcodigoaux
							end
							-- LIMPA A VÁRIAVEL
							set @totalcodigoaux = null
						end*/
						/*delete from tbgabcartaototalizador 
						where cartodatajornada = @datajornada and funcicodigo = @funcicodigo and totalcodigo = @totalcodigo*/

						begin try
							-- CARTÃO TOTALIZADOR PRINCIPAL
							insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
							cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
							@funcicodigo,@totalcodigo,@rubricodigo,@minutos,@mes,@ano,@percentualagrupamento,@datajornada,4)
							-- AGREGA O VALOR JÁ EXISTENTE COM UM EVENTUAL NOVO TOTALIZADOR DE CATEGORIA HORA EXTRA OU CATEGORIA HORA REALIZADA
							set @minutos = (select valor from dbo.retornarTotalTotalizadoresDia(@funcicodigo, @datajornada))
							-- ABATER AS HORAS EXTRAS DAS HORAS REALIZADAS
							if @ctococodigo = 2
							begin
								--update tbgabcartaodeponto set cartacargahorariarealizada = @m1 where cartacodigo = @cartacodigo
								update tbgabcartaodeponto set cartahorasextra = @minutos, cartacargahorariarealizada = @m1 where cartacodigo = @cartacodigo
							end
							else
							begin
								update tbgabcartaodeponto set cartahorasextra = @minutos where cartacodigo = @cartacodigo
							end
						end try
						begin catch
							insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,error)
							values (@funcicodigo,@datajornada,@origem,ERROR_MESSAGE())
						end catch;
					end
				end

				-- FALTA
				else if @categoria = 3 and @ctococodigo = 1
				begin
					-- RECUPERAR HORA FALTA
					set @minutos = (select horasfalta from dbo.retornarSomaHorasFuncionario(@cartacodigo))

					if @minutos > 0
					begin
						begin try
							-- INSERE O VALOR DO TOTALIZADOR NA TABELA DE CARTÃO TOTALIZADOR
							insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
							cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
							@funcicodigo,@totalcodigo,@rubricodigo,@minutos,@mes,@ano,@percentualagrupamento,@datajornada,4)
						end try
						begin catch
							insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,error)
							values (@funcicodigo,@datajornada,@origem,error_message())
						end catch;
					end	
				end

			end -- END if @flag = 1
			
		--FETCH NEXT FROM totalizadores INTO @totalcodigo,@minutos,@flag,@faixainicio,@faixafim,@rubricodigo,@categoria,@percentualagrupamento
		FETCH NEXT FROM totalizadores INTO @totalcodigo,@faixainicio,@faixafim,@rubricodigo,@categoria,@percentualagrupamento,@operador
		END
		CLOSE totalizadores
		DEALLOCATE totalizadores  
		
		set @faixainicio = null set @faixafim = null set @m1 = null set @m2 = null set @m3 = null set @m4 = null 
		--set @inicionoturno = null set @fimnoturno = null set @fatornoturno = null set @estendenoturno = null 
	    set @minutos = null set @complementar = null set @flag = null set @flag2 = null set @operador = null 
		set @rubricodigo = null set @percentualagrupamento = null set @count = null set @totalcodigoaux = null
		
		-- TOTALIZADORES PRINCIPAIS DUPLA JORNADA
		if @leidomotorista = 1
		begin
			declare @iniciojornadadupla datetime
			declare @fimjornadadupla datetime
			declare @tipodj int = 0
			DECLARE totalizadores CURSOR FOR
				select 
				totaloperadorlogico,
				T.totalcodigo,
				rubricodigo,
				totalpercentualagrupamento,
				totaltipodj
				from tbgabtotalizadortipo T (nolock)
				inner join tbgabtotalizadoracordocoletivo TA (nolock) on T.totalcodigo=TA.totalcodigo
				inner join tbgabacordocoletivo A (nolock) on TA.acordcodigo=A.acordcodigo
				where A.acordcodigo = @acordcodigo and T.totalflagvisualizacartao = 1 and T.totaltipoapuracao = 1 and T.totcacodigo = 8
				order by totalpercentualagrupamento desc
			OPEN totalizadores
			FETCH NEXT FROM totalizadores INTO @operador,@totalcodigo,@rubricodigo,@percentualagrupamento,@tipodj
			WHILE @@FETCH_STATUS = 0
			BEGIN
				set @minutos = 0
				set @flag = (select dbo.retornarTotalizadorAtivo(@funcicodigo,@datajornada,@operador,@totalcodigo))

				-- SE TOTALIZADOR ATIVO
				if @flag = 1
				begin
					
					--set @cartacodigo = (select cartacodigo from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada = @datajornada)
					set @minutos = 0
					set @pis = (select funcipis from tbgabfuncionario (nolock) where funcicodigo = @funcicodigo)
					-- RECUPERAR DUPLA JORNADA
					set @iniciojornadadupla = (select apt from dbo.retornarApontamentosRealizadosLeiMotorista(@pis,@datajornada) where jornada = 2 and efeito = 1)
					set @fimjornadadupla = (select apt from dbo.retornarApontamentosRealizadosLeiMotorista(@pis,@datajornada) where jornada = 2 and efeito = 8)
					if @iniciojornadadupla is not null and @fimjornadadupla is not null 
					begin
						set @minutos = (select minuto from dbo.retornarPeriodoFuncionario(@cartacodigo,5))
						set @minutos = @minutos + coalesce((select dbo.retornaADNdoPeriodo(@funcicodigo,@iniciojornadadupla,@fimjornadadupla,1)),0)
					end
					
					if @minutos > 0
					begin
						-- DUPLA JORNADA TIPO HORA EXTRA
						if @tipodj = 1
						begin
							begin try
							-- INSERE O VALOR DO TOTALIZADOR NA TABELA DE CARTÃO TOTALIZADOR
							insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
							cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
							@funcicodigo,@totalcodigo,@rubricodigo,@minutos,@mes,@ano,@percentualagrupamento,@datajornada,4)
							end try
							begin catch
								insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,error)
								values (@funcicodigo,@datajornada,@origem,error_message())
							end catch;
						end

						-- DUPLA JORNADA TIPO HORA DIA
						if @tipodj = 2
						begin
							-- RECUPERAR HORA REALIZADA
							set @m1 = (select minuto from dbo.retornarSomaHorasFuncionario(@cartacodigo))
							set @minutos = @minutos + @m1
							update tbgabcartaodeponto set cartacargahorariarealizada = @minutos where cartacodigo = @cartacodigo
						end
						-- AGREGA O VALOR JÁ EXISTENTE COM UM EVENTUAL NOVO TOTALIZADOR DE CATEGORIA HORA EXTRA OU CATEGORIA HORA REALIZADA
						set @minutos = (select valor from dbo.retornarTotalTotalizadoresDia(@funcicodigo, @datajornada))
						update tbgabcartaodeponto set cartahorasextra = @minutos where cartacodigo = @cartacodigo
					end				
				end -- END if @flag = 1

			FETCH NEXT FROM totalizadores INTO @operador,@totalcodigo,@rubricodigo,@percentualagrupamento,@tipodj
			END
			CLOSE totalizadores
			DEALLOCATE totalizadores 
		end

	-- ===========================================================
	-- TOTALIZADORES HORAS GARANTIDAS                            =
	-- ===========================================================
		
		declare @totalgarantia int, @totalrubricagarantida int

		set @m1 = null set @m2 = null set @m3 = null set @m4 = null set @minutos = null set @complementar = null 
		set @flag = null set @flag2 = null set @operador = null set @totalcodigo = null set @rubricodigo = null set @percentualagrupamento = null set @count = null
	
		-- TOTALIZADORES HORA GARANTIDA HORA REALIZADA
		DECLARE totalizadores CURSOR FOR
			select 
			T.totalcodigo,
			totalgarantia,
			T.totalrubricagarantido,
			T.totalpercentualagrupamento
			from tbgabtotalizadortipo T (nolock)
			inner join tbgabtotalizadoracordocoletivo TA (nolock) on T.totalcodigo=TA.totalcodigo
			inner join tbgabacordocoletivo A (nolock) on TA.acordcodigo=A.acordcodigo
			where A.acordcodigo = @acordcodigo and T.totalflagvisualizacartao = 1 and T.totaltipoapuracao = 1 and T.totcacodigo = 6 
			and (T.totalgarantia > 0 and T.totalgarantia is not null) and T.totalapuracaogarantia = 1
			order by totalpercentualagrupamento desc
		OPEN totalizadores
		FETCH NEXT FROM totalizadores INTO @totalcodigo,@totalgarantia,@totalrubricagarantida,@percentualagrupamento
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- PEGA O VALOR DO CARTÃO TOTALIZADOR PRINCIPAL PARA O DIA
			set @minutos = (select cartovaloracumulado from tbgabcartaototalizador (nolock) 
							where funcicodigo = @funcicodigo and totalcodigo = @totalcodigo and catcartocodigo = 4 and cartodatajornada = @datajornada)

			if @minutos > 0 and @minutos is not null
			begin
				-- SE O VALOR DO TOTALIZADOR PRINCIPAL NÃO ATINGIU A HORA GARANTIDA, INSERE.
				if @minutos < @totalgarantia
				begin
					set @complementar = @totalgarantia - @minutos
					begin try
						insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
						cartomesbase,cartoanobase,cartovaloragrupamento,catcartocodigo,cartodatajornada) values (
						@funcicodigo,@totalcodigo,@totalrubricagarantida,@complementar,@mes,@ano,@percentualagrupamento,5,@datajornada)
					end try
					begin catch
						insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,usuarcadastro)
						values (@funcicodigo,@datajornada,'spug_incluirTotalizadores_HG',0)
					end catch;
				end
				set @minutos = (select valor from dbo.retornarTotalTotalizadoresDia(@funcicodigo,@datajornada))
				update tbgabcartaodeponto set cartahorasextra = @minutos where cartadatajornada = @datajornada and funcicodigo = @funcicodigo
			end
		FETCH NEXT FROM totalizadores INTO @totalcodigo,@totalgarantia,@totalrubricagarantida,@percentualagrupamento
		END
		CLOSE totalizadores
		DEALLOCATE totalizadores  
		
		set @faixainicio = null set @faixafim = null set @m1 = null set @m2 = null set @m3 = null set @m4 = null 
		--set @inicionoturno = null set @fimnoturno = null set @fatornoturno = null set @estendenoturno = null 
	    set @minutos = null set @complementar = null set @flag = null set @flag2 = null set @operador = null 
		set @rubricodigo = null set @percentualagrupamento = null set @count = null set @totalcodigoaux = null
		set @totalproporcionalvalor = null set @totalgarantia = null set @totalrubricagarantida = null

		-- TOTALIZADORES HORA GARANTIDA HORA EXTRA
		DECLARE totalizadores CURSOR FOR
			select 
			T.totalcodigo,
			totalgarantia,
			T.totalrubricagarantido,
			T.totalpercentualagrupamento
			from tbgabtotalizadortipo T (nolock)
			inner join tbgabtotalizadoracordocoletivo TA (nolock) on T.totalcodigo=TA.totalcodigo
			inner join tbgabacordocoletivo A (nolock) on TA.acordcodigo=A.acordcodigo
			where A.acordcodigo = @acordcodigo and T.totalflagvisualizacartao = 1 and T.totaltipoapuracao = 1 and T.totalapuracaogarantia = 1 and T.totcacodigo = 1
			and (T.totalgarantia > 0 and T.totalgarantia is not null)
			order by totalpercentualagrupamento desc
		OPEN totalizadores
		FETCH NEXT FROM totalizadores INTO @totalcodigo,@totalgarantia,@totalrubricagarantida,@percentualagrupamento
		WHILE @@FETCH_STATUS = 0
		BEGIN
			
			-- PEGA O VALOR DO CARTÃO TOTALIZADOR PRINCIPAL PARA O DIA
			set @minutos = (select cartovaloracumulado from tbgabcartaototalizador (nolock) 
							where funcicodigo = @funcicodigo and totalcodigo = @totalcodigo and catcartocodigo = 4 and cartodatajornada = @datajornada)

			if @minutos > 0 and @minutos is not null
			begin
				-- SE NÃO EXISTE E O VALOR DO TOTALIZADOR PRINCIPAL NÃO ATINGIU A HORA GARANTIDA, INSERE.
				if @minutos < @totalgarantia
				begin
					set @complementar = @totalgarantia - @minutos
					begin try
					insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
					cartomesbase,cartoanobase,cartovaloragrupamento,catcartocodigo,cartodatajornada) values (
					@funcicodigo,@totalcodigo,@totalrubricagarantida,@complementar,@mes,@ano,@percentualagrupamento,5,@datajornada)
					end try
					begin catch
						insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,usuarcadastro)
						values (@funcicodigo,@datajornada,'spug_incluirTotalizadores_HG',0)
					end catch;
				end
				set @minutos = (select valor from dbo.retornarTotalTotalizadoresDia(@funcicodigo,@datajornada))
				update tbgabcartaodeponto set cartahorasextra = @minutos where cartadatajornada = @datajornada and funcicodigo = @funcicodigo
			end

		FETCH NEXT FROM totalizadores INTO @totalcodigo,@totalgarantia,@totalrubricagarantida,@percentualagrupamento
		END
		CLOSE totalizadores
		DEALLOCATE totalizadores  
		
		set @m1 = null set @m2 = null set @m3 = null set @m4 = null 
		--set @inicionoturno = null set @fimnoturno = null set @fatornoturno = null set @estendenoturno = null
	    set @minutos = null set @complementar = null set @flag = null set @flag2 = null set @operador = null
		set @rubricodigo = null set @percentualagrupamento = null set @count = null set @totalcodigoaux = null
	
	-- ===========================================================
	-- TOTALIZADORES BANCO DE HORAS                              =
	-- ===========================================================

		if @funcionariobh = 1
		begin
			declare @cred int, @deb int, @fatorhoramensal int = 0, @startDate datetime, @endDate datetime
			-- TRAZ O VALOR DO TOTALIZADOR PRINCIPAL
			select @complementar = btotal, @cred = cred, @deb = deb from dbo.retornarCredDeb(@cartacodigo,@funcicodigo,@datajornada)
			-- PEGA HORAS FALTA DO DIA CASO TENHA.
			select @horasfalta = @deb--horasfalta from dbo.retornarSomaHorasFuncionario(@cartacodigo)
			--print '1 - FALTA ' + convert(varchar,@horasfalta)
			-- PEGA OS ABONOS DO DIA CASO TENHA.
			declare @abonos int = ( select sum(ocorrvalor) from tbgabocorrencia O (nolock) 
									inner join tbgabocorrenciatipo OT (nolock) on O.tpococodigo=OT.tpococodigo
									where funcicodigo = @funcicodigo and convert(date,O.ocorrinicio) = @datajornada and OT.tpocotipo = 2 and OT.tpocosituacao = 1 
									and (OT.tpocointegravel = 0 or (OT.tpocointegravel = 1 and (O.sitme in (10,11) or OT.tpocoexigeaprovacao = 0))))
			if @abonos is null begin set @abonos = 0 end
			--print '2 - ABONO ' + convert(varchar,@abonos)
			-- VERIFICA SE HÁ DÉBITO DE BH A SER COMPENSADO
			declare @debitos int = (select sum(ocorrvalor)
			from tbgabocorrencia O (nolock) 
			inner join tbgabocorrenciatipo OT (nolock) on O.tpococodigo=OT.tpococodigo
			where funcicodigo = @funcicodigo and OT.tpocosituacao = 1 and convert(date,O.ocorrinicio) = @datajornada and OT.tpocotipo = 4 
			and (OT.tpocointegravel = 0 or (OT.tpocointegravel = 1 and O.sitme in (10,11) or OT.tpocoexigeaprovacao = 0)))
			if @debitos is null begin set @debitos = 0 end
			--print '3 - DÉBITO DE BH A SER COMPENSADO ' + convert(varchar,@debitos)
			if (@abonos + @debitos) >= @horasfalta begin set @horasfalta = null end else begin set @horasfalta = @horasfalta - (@abonos + @debitos) end
			--print '4 - FALTA ABATIDA OS ABONOS ' + coalesce(convert(varchar,@horasfalta),'0')

			if ((select saida from dbo.retornarSomaHorasFuncionario(@cartacodigo)) = 'FALTA' or (select saida from dbo.retornarSomaHorasFuncionario(@cartacodigo)) = 'INCONSISTÊNCIA' ) and @ctococodigo <> 2
			begin 
				select @startDate = min(cartadatajornada), @endDate = max(cartadatajornada) 
				from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartamesbase = @mes and cartaanobase = @ano
				select @fatorhoramensal=menor_fator from dbo.retornarMinimoFatorMensalNoPeriodo(@funcicodigo,@startDate,@endDate)
				set @horasfalta = @fatorhoramensal 
				set @deb = @fatorhoramensal 
			end
			-- SE INDICAÇÃO FOR DIFERENTE DE TRABALHO, DÉBITO RECEBE VALOR NULL
			if @ctococodigo <> 1 begin set @deb = null end
			-- TOTALIZADORES BANCO DE HORAS HORA EXTRA
			DECLARE totalizadores_BH CURSOR FOR
				select 
				T.totalcodigo,
				totalcompensavel,
				totaltipocompensacao,
				totalfatorcompensacao,
				totalabsolutoinicio,
				totalabsolutofim,
				totalproporcionalvalor,
				totaloperadorlogico,
				totalpercentualagrupamento,
				totalfaixainicio,totalfaixafim
				from tbgabtotalizadortipo T (nolock)
				inner join tbgabtotalizadoracordocoletivo TA (nolock) on T.totalcodigo=TA.totalcodigo
				inner join tbgabacordocoletivo A (nolock) on TA.acordcodigo=A.acordcodigo
				where A.acordcodigo = @acordcodigo and T.totalflagvisualizacartao = 1 and T.totaltipoapuracao = 1 and T.totcacodigo = 1
				and T.totalcompensavel = 2 and T.totalfatorcompensacao > 0
				order by totalpercentualagrupamento desc
			OPEN totalizadores_BH
			FETCH NEXT FROM totalizadores_BH INTO @totalcodigo,@totalcompensavel,@tipocompensacao,@totalfatorcompensacao,@totalabsolutoinicio,
			@totalabsolutofim,@totalproporcionalvalor,@operador,@percentualagrupamento,@faixainicio,@faixafim
			WHILE @@FETCH_STATUS = 0
			BEGIN
				set @flag = (select dbo.retornarTotalizadorAtivo(@funcicodigo,@datajornada,@operador,@totalcodigo))
				-- VERIFICA SE POSSUI TOTALIZADOR DE MESMA CATEGORIA COM FAIXAS DE HORÁRIO CONFLITANTE E VALOR DE AGRUPAMENTO MAIOR 
				set @flag2 = (select count(totalcodigo) from dbo.verificaTotalizadoresDiariosComMesmoDiaFaixa(@funcicodigo,@datajornada,@acordcodigo,@totalcodigo,@faixainicio,@faixafim,@percentualagrupamento,1))
				delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and totalcodigo = @totalcodigo and cartodatajornada = @datajornada and catcartocodigo = 6
				-- ALTERADO AQUI 26/05/2020 SE INDICAÇÃO FOR DIFERENTE DE FÉRIAS E AFASTAMENTO
				if @ctococodigo not in (0,5,6) and @flag = 1 and @flag2 = 0
				begin
					update tbgabcartaodeponto set cartacreditobh = @cred, cartadebitobh = @deb where cartacodigo = @cartacodigo
					
					-- ALTERADO AQUI 26/05/2020
					if @complementar > 0 
					begin
						set @complementar = @complementar + coalesce(@horasfalta,0)
					end
					--set @complementar = @complementar + coalesce(@horasfalta,0)

					set @tp = (select coalesce(cartovaloracumulado,0) from tbgabcartaototalizador (nolock) where funcicodigo = @funcicodigo and cartodatajornada = @datajornada and totalcodigo = @totalcodigo and catcartocodigo = 4)
					if coalesce(@tp,0) > @complementar 
					begin 
						set @complementar = @tp 
					end 
					else if coalesce(@tp,0) <= @complementar 
					begin 
						declare @he int = null
						delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and totalcodigo = @totalcodigo and cartodatajornada = @datajornada and catcartocodigo = 4 
						select @he = sum(cartovaloracumulado) from tbgabcartaototalizador (nolock) 
						where funcicodigo = @funcicodigo and cartodatajornada = @datajornada and catcartocodigo in (14,15)
						update tbgabcartaodeponto set cartahorasextra = @he where cartacodigo = @cartacodigo
					end
					-- CARTÃO TOTALIZADOR BANCO DE HORAS (CRÉDITO)
					
					-- TIPO DE COMPENSAÇÃO VALOR ABSOLUTO
					if @tipocompensacao = 1
					begin
						-- VERIFICA SE O VALOR RETORNADO ESTÁ DENTRO DA FAIXA
						if @totalabsolutoinicio < @complementar and @complementar <= @totalabsolutofim
						begin
							set @complementar = @complementar - @totalabsolutoinicio
						end
						-- VERIFICA SE O VALOR NÃO ALCANÇA A FAIXA
						else if @complementar <= @totalabsolutoinicio
						begin
							set @complementar = 0
						end
						-- VERIFICA SE O VALOR ULTRAPASSA A FAIXA
						else if @totalabsolutofim <= @complementar
						begin
							set @complementar = @totalabsolutofim - @totalabsolutoinicio
						end
					end

					-- TIPO DE COMPENSAÇÃO VALOR PROPORCIONAL
					else if @tipocompensacao = 2
					begin
						set @totalproporcionalvalor = @totalproporcionalvalor / 100
						set @complementar = @complementar * @totalproporcionalvalor
					end
					--print '@complementar ' + convert(varchar,coalesce(@complementar,'0')) + ' @horasfalta ' + convert(varchar,coalesce(@horasfalta,'0')) + ' @cred ' + convert(varchar,coalesce(@cred,'0')) + ' @deb ' + convert(varchar,coalesce(@deb,'0'))
					-- SE HÁ VALOR A SER COMPENSADO EM BANCO DE HORAS
					if coalesce(@complementar,0) > 0 and coalesce(@horasfalta,0) <= 0
					begin
						--print '1 complementar ' + convert(varchar,@complementar)
						-- TRAZ O VALOR DO TOTALIZADOR PRINCIPAL
						--set @tp = (select coalesce(sum(cartovaloracumulado),0) from tbgabcartaototalizador (nolock) where funcicodigo = @funcicodigo and cartodatajornada = @datajornada and totalcodigo = @totalcodigo and catcartocodigo = 4)
						--print 'TP 1 '+ convert(varchar,@tp)
						-- ABATE OS VALORES DE BH DAS HE A SER PAGA
						set @tp = @tp - @complementar if @tp < 0 begin set @tp = 0 end
						set @tp = round(@tp,0)
						--print 'TP 2 '+ convert(varchar,@tp)
						update tbgabcartaototalizador set cartovaloracumulado = @tp where funcicodigo = @funcicodigo and cartodatajornada = @datajornada and catcartocodigo = 4 and totalcodigo = @totalcodigo

						set @complementar = round(@complementar,0) * @totalfatorcompensacao

						begin try
							insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
							cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
							@funcicodigo,@totalcodigo,0,@complementar,@mes,@ano,@totalfatorcompensacao,@datajornada,6)
						end try
						begin catch
							insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,usuarcadastro)
							values (@funcicodigo,@datajornada,'spug_incluirTotalizadores_BH',0)
						end catch;
						--update tbgabcartaodeponto set cartacreditobh = @complementar where funcicodigo = @funcicodigo and cartadatajornada = @datajornada
					end

					else if coalesce(@complementar,0) <= 0 and coalesce(@horasfalta,0) > 0
					begin
						--print '2 - '+convert(varchar,@complementar)+' '+convert(varchar,@horasfalta)
						begin try
							insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
							cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
							@funcicodigo,@totalcodigo,0,@horasfalta,@mes,@ano,0,@datajornada,16)
						end try
						begin catch
							insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,usuarcadastro)
							values (@funcicodigo,@datajornada,'spug_incluirTotalizadores_BH',0)
						end catch;
						--update tbgabcartaodeponto set cartadebitobh = @horasfalta, cartahorasfalta = null where funcicodigo = @funcicodigo and cartadatajornada = @datajornada
					end

					else if @complementar > 0 and coalesce(@horasfalta,0) > 0 and @complementar > coalesce(@horasfalta,0)
					begin
						--print '1.1 complementar ' + convert(varchar,@complementar)
						set @complementar = @complementar - @horasfalta
						-- TRAZ O VALOR DO TOTALIZADOR PRINCIPAL
						--set @tp = (select coalesce(sum(cartovaloracumulado),0) from tbgabcartaototalizador (nolock) where funcicodigo = @funcicodigo and cartodatajornada = @datajornada and totalcodigo = @totalcodigo and catcartocodigo = 4)
						--print 'TP 1 '+ convert(varchar,@tp)
						-- ABATE OS VALORES DE BH DAS HE A SER PAGA
						set @tp = @tp - @complementar if @tp < 0 begin set @tp = 0 end
						set @tp = round(@tp,0)
						--print 'TP 2 '+ convert(varchar,@tp)
						update tbgabcartaototalizador set cartovaloracumulado = @tp where funcicodigo = @funcicodigo and cartodatajornada = @datajornada and catcartocodigo = 4 and totalcodigo = @totalcodigo

						set @complementar = round(@complementar,0) * @totalfatorcompensacao

						begin try
							insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
							cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
							@funcicodigo,@totalcodigo,0,@complementar,@mes,@ano,@totalfatorcompensacao,@datajornada,6)
						end try
						begin catch
							insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,usuarcadastro)
							values (@funcicodigo,@datajornada,'spug_incluirTotalizadores_BH',0)
						end catch;
					end

					else if @complementar > 0 and coalesce(@horasfalta,0) > 0 and coalesce(@horasfalta,0) > @complementar
					begin
						set @horasfalta = @horasfalta - @complementar
						--print '2.1 - '+convert(varchar,@complementar)+' '+convert(varchar,@horasfalta)
						begin try
						insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
						cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
						@funcicodigo,@totalcodigo,0,@horasfalta,@mes,@ano,0,@datajornada,16)
						end try
						begin catch
							insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,usuarcadastro)
							values (@funcicodigo,@datajornada,'spug_incluirTotalizadores_BH',0)
						end catch;
					end

					if coalesce(@complementar,0) = 0 and @cred > 0
					begin
						--print '3'
						-- TRAZ O VALOR DO TOTALIZADOR PRINCIPAL
						--set @tp = (select coalesce(sum(cartovaloracumulado),0) from tbgabcartaototalizador (nolock) where funcicodigo = @funcicodigo and cartodatajornada = @datajornada and totalcodigo = @totalcodigo and catcartocodigo = 4)
		
						-- ABATE OS VALORES DE BH DAS HE A SER PAGA
						set @tp = @tp - @complementar if @tp < 0 begin set @tp = 0 end
						set @tp = round(@tp,0)
						update tbgabcartaototalizador set cartovaloracumulado = @tp where funcicodigo = @funcicodigo and cartodatajornada = @datajornada and catcartocodigo = 4

						set @complementar = round(@complementar,0) * @totalfatorcompensacao
						begin try
							insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
							cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
							@funcicodigo,@totalcodigo,0,@cred,@mes,@ano,@totalfatorcompensacao,@datajornada,6)
						end try
						begin catch
							insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,usuarcadastro)
							values (@funcicodigo,@datajornada,'spug_incluirTotalizadores_BH',0)
						end catch;
					end

					if coalesce(@horasfalta,0) = 0 and @deb > 0
					begin
						--print '4'
						begin try
							insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
							cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,catcartocodigo) values (
							@funcicodigo,@totalcodigo,0,@deb,@mes,@ano,0,@datajornada,16)
						end try
						begin catch
							insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem,usuarcadastro)
							values (@funcicodigo,@datajornada,'spug_incluirTotalizadores_BH',0)
						end catch;
					end

					--print '@complementar ' + convert(varchar,coalesce(@complementar,'0')) + ' @horasfalta ' + convert(varchar,coalesce(@horasfalta,'0')) + ' @cred ' + convert(varchar,coalesce(@cred,'0')) + ' @deb ' + convert(varchar,coalesce(@deb,'0'))
					-- ATUALIZA CARTÃO DE PONTO
					--exec dbo.spug_incluirCredDeb @cartacodigo, @funcicodigo, @datajornada, @totalcodigo
					
				end
			FETCH NEXT FROM totalizadores_BH INTO @totalcodigo,@totalcompensavel,@tipocompensacao,@totalfatorcompensacao,@totalabsolutoinicio,
			@totalabsolutofim,@totalproporcionalvalor,@operador,@percentualagrupamento,@faixainicio,@faixafim
			END
			CLOSE totalizadores_BH
			DEALLOCATE totalizadores_BH
		end

END
GO


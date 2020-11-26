


/****** Object:  StoredProcedure [dbo].[spug_incluirOcorrencias]    Script Date: 26/11/2020 11:15:03 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Jean Paul
-- Create date: 28/07/2019
-- Description:	Inclui as ocorrências do funcionário
-- =============================================
-- ATUALIZAÇÕES
-- =============================================
-- Author:		Jean Paul
-- alter date: 30/07/2019
-- 1º - Implementado a categoria de sobre aviso
-- alter date: 31/07/2019
-- 2º - Implementada a crítica de não incluir ocorrências de horários conflitantes
-- 3º - Implementado a categoria de HE forçada
-- 4º - Implementado a categoria de Sobre Aviso
-- 5º - Implementado a categoria de Notificação
-- 6º - Implementado a categoria de Férias
-- alter date: 05/08/2019
-- 7º - Implementado um novo campo (catcartocodigo) na tabela cartão totalizador
-- alter date: 20/08/2019
-- 8º - Implementado o teste de tipo de abono, se parcial ou total.
-- =============================================
ALTER PROCEDURE [dbo].[spug_incluirOcorrencias] 
	-- Add the parameters for the stored procedure here
	@mes smallint,
	@ano int,
	@funcicodigo int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- TABELA
	/*declare @tabela_ocorrencias 
	table 
	(_funcicodigo int, _totalcodigo int, _rubricodigo int, 
	mes smallint, ano int, agrupamento float, inicio datetime, 
	_tipoocorrencia int, _ocorrcodigo int, valor int, 
	categoriaocorrencia smallint)*/

	-- VARIÁVEIS
	declare 
	@totalcodigo int, @rubricodigo int,@agrupamento float, @inicio datetime,@fim datetime, 
	@tipoocorrencia int, @ocorrcodigo int, @valor int, @categoriaocorrencia smallint,@categoria smallint,
	@horasfalta int, @horaextra int, @count int, @acordcodigo int, @ocorrabono smallint, @horaescala int,@categoria_cartaototalizador int
	declare @dataocorrencia1 datetime, @dataocorrencia2 datetime, @indicacao int, @valorbh int, @valorbh_cartao int,@valor_he_cartao int,@valortotal_he int, @debito_bh int = null, @inicio_oco datetime, @fim_oco datetime

	select @inicio_oco=min(cartadatajornada),@fim_oco=max(cartadatajornada) from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartamesbase = @mes and cartaanobase = @ano
	set @fim_oco = dateadd(hour,23,@fim_oco)
	set @fim_oco = dateadd(minute,59,@fim_oco)
	set @dataocorrencia1 = '1900-01-01'
	set @dataocorrencia2 = '1900-01-01'
	set @count = 0
	declare @ctococodigo int, @ctococodigooriginal int, 
	@total_oco int = (select count(cartacodigo) from tbgabcartaodeponto where funcicodigo = @funcicodigo and cartamesbase = @mes and cartaanobase = @ano and ctococodigo in (5,6,7,8))
	
	-- LIMPA AS FLAG's DE OCORRÊNCIA 
	update tbgabcartaodeponto set cartaflagocorrencia = 0 where cartamesbase = @mes and cartaanobase = @ano and funcicodigo = @funcicodigo
	
	-- VOLTA AS INDICAÇÕES DO CARTÃO AO ESTADO ORIGINAL
	while @count <= @total_oco
	begin
		select top 1 @dataocorrencia2=cartadatajornada,@ctococodigo=ctococodigo,@ctococodigooriginal=ctococodigooriginal 
		from tbgabcartaodeponto where funcicodigo = @funcicodigo and cartaanobase = @ano and cartamesbase = @mes and cartadatajornada > @dataocorrencia1 and ctococodigo in (5,6,7,8)
		set @dataocorrencia1 = @dataocorrencia2
		--select @dataocorrencia1,@dataocorrencia2,@ctococodigo,@ctococodigooriginal,@ano,@mes
		update tbgabcartaodeponto set ctococodigo = @ctococodigooriginal where funcicodigo = @funcicodigo and cartadatajornada = @dataocorrencia1
		set @count += 1
	end
	set @count = null
	-- VARRE AS OCORRÊNCIAS
	DECLARE ocorrencias CURSOR FOR 
		select funcicodigo,0,O.rubricodigo,ocorrinicio,ocorrfim,O.tpococodigo,ocorrcodigo,ocorrvalor,OT.tpocotipo,OT.tpocovaloragrupamento,ocorrabono
		from tbgabocorrencia O (nolock) 
		inner join tbgabocorrenciatipo OT (nolock) on O.tpococodigo=OT.tpococodigo
		where funcicodigo = @funcicodigo and ((ocorrinicio between @inicio_oco and @fim_oco) or (ocorrfim between @inicio_oco and @fim_oco) or (ocorrinicio < @inicio_oco and ocorrfim > @fim_oco))
		and OT.tpocosituacao = 1 and (OT.tpocointegravel = 0 or (OT.tpocointegravel = 1 and (O.sitme in (10,11) or OT.tpocoexigeaprovacao = 0)))
		--order by ocorrinicio
		-- (OT.tpocointegravel = 1 and (O.sitme in (10,11) or OT.tpocoexigeaprovacao = 0))) <-- VERSÃO NOVA
		-- (OT.tpocointegravel = 1 and O.sitme in (10,11))) <-- VERSÃO ORIGINAL
	OPEN ocorrencias
	FETCH NEXT FROM ocorrencias INTO @funcicodigo,@totalcodigo,@rubricodigo,@inicio,@fim,@tipoocorrencia,@ocorrcodigo,@valor,@categoriaocorrencia,@agrupamento,@ocorrabono
		WHILE @@FETCH_STATUS = 0
		BEGIN
			set @inicio = convert(date,@inicio)
			set @fim = convert(date,@fim)
			-- CATEGORIA AFASTAMENTO
			if @categoriaocorrencia = 1
			begin
				-- ATUALIZADA A INDICAÇÃO NA TABELA CARTÃO DE PONTO, SETA PRA 0 AS COLUNAS DE FALTA E BH
				update tbgabcartaodeponto set 
				ctococodigo = 6, 
				cartahorasfalta = 0, 
				cartaflagocorrencia = 1,
				cartacreditobh = null,cartadebitobh = null,cartasaldoanteriorbh = null,cartasaldoatualbh = null
				where cartadatajornada between @inicio and @fim and funcicodigo = @funcicodigo and cartamesbase = @mes and cartaanobase = @ano
				-- DELETA OS POSSÍVEIS CARTÕES TOTALIZADORES QUE POSSAM TER CASO O FUNCIONÁRIO SEJA BH.
				delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and cartodatajornada between @inicio and @fim and catcartocodigo = 16
			end

			-- CATEGORIA ABONO
			else if @categoriaocorrencia = 2
			begin

				if @ocorrabono = 1
				begin
					set @horasfalta = 0
					-- Débito automático de totalizador de BH diário
					delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and cartodatajornada = @inicio and catcartocodigo = 16 
				end
				else
				begin
					set @horasfalta = (select cartahorasfalta from tbgabcartaodeponto (nolock) where cartadatajornada = @inicio and funcicodigo = @funcicodigo)
					set @horasfalta = @horasfalta - @valor
					
					if @horasfalta <= 0 
					begin 
						-- Débito automático de totalizador de BH diário
						delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and cartodatajornada = @inicio and catcartocodigo = 16
						set @horasfalta = 0 
					end
					else
					begin
						-- Débito automático de totalizador de BH diário
						update tbgabcartaototalizador set cartovaloracumulado = @horasfalta where funcicodigo = @funcicodigo and cartodatajornada = @inicio and catcartocodigo = 16
						set @debito_bh = @horasfalta
					end
				end
				exec dbo.spug_incluirSaldoBhCartaodePonto_DIA @funcicodigo,@mes,@ano,@inicio
				-- ATUALIZADA A INDICAÇÃO NA TABELA CARTÃO DE PONTO
				update tbgabcartaodeponto set ctococodigo = 7, cartaflagocorrencia = 1, cartahorasfalta = @horasfalta, cartadebitobh = @debito_bh
				where cartadatajornada between @inicio and @fim and funcicodigo = @funcicodigo 
				and cartamesbase = @mes and cartaanobase = @ano and ctococodigo <> 2
			end
			
			-- CATEGORIA SOBRE AVISO (INSERE NA TABELA DE RÚBRICAS - CATEGORIA 14) (ATUALIZA FLAG DE OCORRÊNCIA E COLUNA HE)
			else if @categoriaocorrencia = 3
			begin
				-- VERIFICA SE EXISTE OCORRÊNCIAS COM HORÁRIOS CONFLITANTES DE MAIOR VALOR
				set @count = (select count(ocorrcodigo) from tbgabocorrencia (nolock) where
				funcicodigo = @funcicodigo and ocorrcodigo <> @ocorrcodigo and ocorrvalor > @valor and
				-- FAIXA INÍCIO DENTRO E FAIXA FIM DENTRO
				(((ocorrinicio >= @inicio and ocorrinicio <= @fim) and (ocorrfim >= @inicio and ocorrfim <= @fim)) or 
				-- FAIXA INÍCIO MENOR E FAIXA FIM DENTRO
				((ocorrinicio < @inicio) and (ocorrfim > @inicio and ocorrfim <= @fim)) or
				-- FAIXA INÍCIO DENTRO E FAIXA FIM MAIOR
				((ocorrinicio >= @inicio and ocorrinicio < @fim) and (ocorrfim > @inicio and ocorrfim > @fim))))
		
				-- SE NÃO EXISTIR, SEGUE COM O PROCEDIMENTO
				if @count = 0
				begin
					-- LIMPA OCORRÊNCIA CASO JÁ EXISTA
					delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and ocorrcodigo = @ocorrcodigo

					-- INSERE UM CARTÃO TOTALIZADOR COM TOTALIZADOR = 0 
					begin try
						insert into tbgabcartaototalizador 
						(funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,cartomesbase,
						cartoanobase,cartovaloragrupamento,cartodatajornada,ocorrcodigo,catcartocodigo)
						values 
						(@funcicodigo,0,@rubricodigo,@valor,@mes,@ano,
						@agrupamento,@inicio,@ocorrcodigo,14)
					end try
					begin catch
						insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem)
						values (@funcicodigo,@inicio,'spug_incluirOcorrencias_SOBREAVISO')
					end catch;
					-- SOMA AS HORAS EXTRAS EXISTENTES INSERIDAS NO CARTÃO TOTALIZADOR ORIGINADAS DE OCORRÊNCIAS DE CATEGORIA SOBRE AVISO E/OU HE FORÇADA
					set @horaextra = (select coalesce(sum(cartovaloracumulado),0) from tbgabcartaototalizador (nolock) 
									  where cartodatajornada = @inicio and funcicodigo = @funcicodigo and totalcodigo = 0 and cartomesbase = @mes 
									  and cartoanobase = @ano and catcartocodigo not in (114,115) and
									  (select tpocotipo from tbgabocorrenciatipo (nolock) where tpococodigo in 
									  (select tpococodigo from tbgabocorrencia (nolock) where ocorrcodigo = tbgabcartaototalizador.ocorrcodigo)) in (3,7))

					-- SOMA AS HORAS EXTRAS EXISTENTES INSERIDAS NO CARTÃO TOTALIZADOR ORIGINADAS DE TOTALIZADORES		
					select top 1 @acordcodigo=coalesce(acordcodigo,0) from tbgabcartaodeponto (nolock) where funcicodigo=@funcicodigo and cartadatajornada=@inicio
					set @horaextra = @horaextra + (select coalesce(sum(cartovaloracumulado),0) from tbgabcartaototalizador (nolock) 
					where funcicodigo = @funcicodigo and cartodatajornada = @inicio and cartomesbase = @mes and cartoanobase = @ano and
					totalcodigo in (select totalcodigo from dbo.RetornarTotalizadores(@acordcodigo,@funcicodigo,@inicio) where categoria in (1,6)) and catcartocodigo not in (6,16))
					
					-- ATUALIZA O VALOR DA HORA EXTRA NO CARTÃO DE PONTO DO FUNCIONÁRIO E STATUS DE OCORRÊNCIA
					update tbgabcartaodeponto set cartahorasextra = @horaextra, cartaflagocorrencia = 1
					where funcicodigo = @funcicodigo and cartadatajornada = @inicio and cartamesbase = @mes and cartaanobase = @ano
				end
			end

			-- CATEGORIA DÉBITO DE BANCO DE HORAS (INSERE NA TABELA DE RÚBRICAS - CATEGORIA 9) (ATUALIZA FLAG DE OCORRÊNCIA E COLUNA DÉB DE BH)
			else if @categoriaocorrencia = 4
			begin
				
				-- VERIFICA SE EXISTE OCORRÊNCIAS COM HORÁRIOS CONFLITANTES DE MAIOR VALOR
				set @count = (select count(ocorrcodigo) from tbgabocorrencia (nolock) where
				funcicodigo = @funcicodigo and ocorrcodigo <> @ocorrcodigo and ocorrvalor > @valor and
				-- FAIXA INÍCIO DENTRO E FAIXA FIM DENTRO
				(((ocorrinicio >= @inicio and ocorrinicio <= @fim) and (ocorrfim >= @inicio and ocorrfim <= @fim)) or 
				-- FAIXA INÍCIO MENOR E FAIXA FIM DENTRO
				((ocorrinicio < @inicio) and (ocorrfim > @inicio and ocorrfim <= @fim)) or
				-- FAIXA INÍCIO DENTRO E FAIXA FIM MAIOR
				((ocorrinicio >= @inicio and ocorrinicio < @fim) and (ocorrfim > @inicio and ocorrfim > @fim))))

				if @count = 0
				begin
					-- LIMPA OCORRÊNCIA CASO JÁ EXISTA
					delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and ocorrcodigo = @ocorrcodigo

					-- INSERE UM CARTÃO TOTALIZADOR COM TOTALIZADOR = 0 
					begin try
						insert into tbgabcartaototalizador 
						(funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,ocorrcodigo,catcartocodigo)
						values 
						(@funcicodigo,0,@rubricodigo,@valor,@mes,@ano,
						0,convert(date,@inicio),@ocorrcodigo,9)
					end try
					begin catch
						insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem)
						values (@funcicodigo,@inicio,'spug_incluirOcorrencias_DEB_BH')
					end catch
					-- SOMA TODAS AS HORAS RELACIONADAS A DÉBITO DE BANCO DE HORAS DO DIA
					set @valor = (select sum(cartovaloracumulado) from tbgabcartaototalizador (nolock) where funcicodigo = @funcicodigo 
					and cartodatajornada = @inicio and cartomesbase = @mes and cartoanobase = @ano and catcartocodigo in (9,16))

					-- ATUALIZA REGISTRO DO FUNCIONÁRIO NO CP
					update tbgabcartaodeponto set cartaflagocorrencia = 1,cartadebitobh = @valor 
					where funcicodigo = @funcicodigo and cartadatajornada = @inicio
				end
			end
			
			-- CATEGORIA NOTIFICAÇÃO
			else if @categoriaocorrencia = 5
			begin
				-- ATUALIZADA A INDICAÇÃO NA TABELA CARTÃO DE PONTO
				update tbgabcartaodeponto set cartaflagocorrencia = 1
				where cartadatajornada between @inicio and @fim and funcicodigo = @funcicodigo and cartamesbase = @mes and cartaanobase = @ano
			end

			-- CATEGORIA FÉRIAS
			else if @categoriaocorrencia = 6
			begin
				-- ATUALIZADA A INDICAÇÃO NA TABELA CARTÃO DE PONTO
				update tbgabcartaodeponto set ctococodigo = 5, cartahorasfalta = 0, cartaflagocorrencia = 1
				where funcicodigo = @funcicodigo and cartadatajornada between @inicio and @fim and cartamesbase = @mes and cartaanobase = @ano
			end
			
			-- CATEGORIA HORA EXTRA FORÇADA (INSERE NA TABELA DE RÚBRICAS - CATEGORIA 15) (ATUALIZA COLUNA HE E FLAG DE OCORRÊNCIA)
			else if @categoriaocorrencia = 7
			begin
				-- VERIFICA SE EXISTE OCORRÊNCIAS COM HORÁRIOS CONFLITANTES DE MAIOR VALOR
				set @count = (select count(ocorrcodigo) from tbgabocorrencia (nolock) where
				funcicodigo = @funcicodigo and ocorrcodigo <> @ocorrcodigo and ocorrvalor > @valor and
				-- FAIXA INÍCIO DENTRO E FAIXA FIM DENTRO
				(((ocorrinicio >= @inicio and ocorrinicio <= @fim) and (ocorrfim >= @inicio and ocorrfim <= @fim)) or 
				-- FAIXA INÍCIO MENOR E FAIXA FIM DENTRO
				((ocorrinicio < @inicio) and (ocorrfim > @inicio and ocorrfim <= @fim)) or
				-- FAIXA INÍCIO DENTRO E FAIXA FIM MAIOR
				((ocorrinicio >= @inicio and ocorrinicio < @fim) and (ocorrfim > @inicio and ocorrfim > @fim))))

				if @count = 0
				begin
					-- LIMPA OCORRÊNCIA CASO JÁ EXISTA
					delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and ocorrcodigo = @ocorrcodigo

					-- INSERE UM CARTÃO TOTALIZADOR COM TOTALIZADOR = 0 
					begin try
						insert into tbgabcartaototalizador 
						(funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,ocorrcodigo,catcartocodigo)
						values 
						(@funcicodigo,0,@rubricodigo,@valor,@mes,
						@ano,@agrupamento,@inicio,@ocorrcodigo,15)
					end try
					begin catch
						insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem)
						values (@funcicodigo,@inicio,'spug_incluirOcorrencias_HE_FORCADA')
					end catch;
					-- BKP 08/01/2019
					-- SOMA TODAS AS HORAS RELACIONADAS A HORA EXTRA FORÇADA DO DIA
					/*set @valor = (select coalesce(sum(cartovaloracumulado),0) from tbgabcartaototalizador CT (nolock)
								  inner join tbgabocorrencia O (nolock) on CT.ocorrcodigo=O.ocorrcodigo
								  inner join tbgabocorrenciatipo OT (nolock) on O.tpococodigo=OT.tpococodigo
								  inner join tbgabocorrenciaclasse OC (nolock) on OT.tpocotipo=OC.tpocotipo
								  where CT.funcicodigo = @funcicodigo and CT.totalcodigo = 0
								  and CT.catcartocodigo not in (114,115) and
								  CT.cartodatajornada = @inicio and OC.tpocotipo = 7)*/

					-- ALTERAÇÃO 08/01/2019
					-- SOMA AS HORAS EXTRAS EXISTENTES INSERIDAS NO CARTÃO TOTALIZADOR ORIGINADAS DE OCORRÊNCIAS DE CATEGORIA SOBRE AVISO E/OU HE FORÇADA
					set @horaextra = (select coalesce(sum(cartovaloracumulado),0) from tbgabcartaototalizador (nolock) 
									  where cartodatajornada = @inicio and funcicodigo = @funcicodigo and totalcodigo = 0 and cartomesbase = @mes 
									  and cartoanobase = @ano and catcartocodigo not in (114,115) and
									  (select tpocotipo from tbgabocorrenciatipo (nolock) where tpococodigo in 
									  (select tpococodigo from tbgabocorrencia (nolock) where ocorrcodigo = tbgabcartaototalizador.ocorrcodigo)) in (3,7))

					-- SOMA AS HORAS EXTRAS EXISTENTES INSERIDAS NO CARTÃO TOTALIZADOR ORIGINADAS DE TOTALIZADORES		
					select top 1 @acordcodigo=coalesce(acordcodigo,0) from tbgabcartaodeponto (nolock) where funcicodigo=@funcicodigo and cartadatajornada=@inicio
					set @horaextra = @horaextra + (select coalesce(sum(cartovaloracumulado),0) from tbgabcartaototalizador (nolock) 
					where funcicodigo = @funcicodigo and cartodatajornada = @inicio and cartomesbase = @mes and cartoanobase = @ano and
					totalcodigo in (select totalcodigo from dbo.RetornarTotalizadores(@acordcodigo,@funcicodigo,@inicio) where categoria in (1,6)) and catcartocodigo not in (6,16))

					-- ATUALIZA REGISTRO DO FUNCIONÁRIO NO CP
					update tbgabcartaodeponto set cartahorasextra = @valor,cartaflagocorrencia = 1
					where cartadatajornada = @inicio and funcicodigo = @funcicodigo
				end
			end

			-- CATEGORIA DE FALTA (INSERE NA TABELA DE RÚBRICAS - CATEGORIA 10) (ATUALIZA INDICAÇÃO E FLAG DE OCORRÊNCIA)
			else if @categoriaocorrencia = 8
			begin
				-- ATUALIZADA A INDICAÇÃO NA TABELA CARTÃO DE PONTO
				update tbgabcartaodeponto set ctococodigo = 8, cartaflagocorrencia = 1
				where funcicodigo = @funcicodigo and cartadatajornada between @inicio and @fim and cartamesbase = @mes and cartaanobase = @ano

				-- ALTERAÇÃO 17/02/2020
				-- PEGA A HORA ESCALA DO FUNCIONÁRIO
				set @horaescala = (select top 1 menor_fator from dbo.retornarMinimoFatorMensalNoPeriodo(@funcicodigo,@inicio_oco,@fim_oco))

				-- BKP 17/02/2020
				-- PEGA A HORA ESCALA DO FUNCIONÁRIO
				/*set @horaescala = (select top 1 (select top 1 horarfatorcargamensal from tbgabhorario (nolock) where horarcodigo = CP.horarcodigo) from tbgabcartaodeponto CP (nolock)
								   where funcicodigo = @funcicodigo and cartadatajornada between @inicio
								   and @fim and cartamesbase = @mes and cartaanobase = @ano)*/
				if @horaescala is null begin set @horaescala = 0 end

				-- LIMPA OCORRÊNCIA CASO JÁ EXISTA
				delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and ocorrcodigo = @ocorrcodigo
					
				-- INSERE UM CARTÃO TOTALIZADOR COM TOTALIZADOR = 0 
				begin try
					insert into tbgabcartaototalizador 
					(funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,ocorrcodigo,catcartocodigo)
					values 
					(@funcicodigo,0,@rubricodigo,@horaescala,@mes,
					@ano,@agrupamento,@inicio,@ocorrcodigo,10)
				end try
				begin catch
					insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem)
					values (@funcicodigo,@inicio,'spug_incluirOcorrencias_FALTA')
				end catch;

				delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and cartodatajornada = @inicio and catcartocodigo = 16
				update tbgabcartaodeponto set cartadebitobh = @debito_bh from tbgabcartaodeponto where funcicodigo = @funcicodigo and cartadatajornada = @inicio
				exec dbo.spug_incluirSaldoBhCartaodePonto_DIA @funcicodigo,@mes,@ano,@inicio
				
			end
			
			-- CATEGORIA CRÉDITO DE BANCO DE HORAS (INSERE NA TABELA DE RÚBRICAS - CATEGORIA 9) (ATUALIZA FLAG DE OCORRÊNCIA E COLUNA CRÉD DE BH)
			else if @categoriaocorrencia = 9
			begin
				
				-- VERIFICA SE EXISTE OCORRÊNCIAS COM HORÁRIOS CONFLITANTES DE MAIOR VALOR
				set @count = (select count(ocorrcodigo) from tbgabocorrencia (nolock) where
				funcicodigo = @funcicodigo and ocorrcodigo <> @ocorrcodigo and ocorrvalor > @valor and
				-- FAIXA INÍCIO DENTRO E FAIXA FIM DENTRO
				(((ocorrinicio >= @inicio and ocorrinicio <= @fim) and (ocorrfim >= @inicio and ocorrfim <= @fim)) or 
				-- FAIXA INÍCIO MENOR E FAIXA FIM DENTRO
				((ocorrinicio < @inicio) and (ocorrfim > @inicio and ocorrfim <= @fim)) or
				-- FAIXA INÍCIO DENTRO E FAIXA FIM MAIOR
				((ocorrinicio >= @inicio and ocorrinicio < @fim) and (ocorrfim > @inicio and ocorrfim > @fim))))

				if @count = 0
				begin
					-- LIMPA OCORRÊNCIA CASO JÁ EXISTA
					delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and ocorrcodigo = @ocorrcodigo

					-- INSERE UM CARTÃO TOTALIZADOR COM TOTALIZADOR = 0 
					begin try
						insert into tbgabcartaototalizador 
						(funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,cartomesbase,cartoanobase,cartovaloragrupamento,cartodatajornada,ocorrcodigo,catcartocodigo)
						values 
						(@funcicodigo,0,@rubricodigo,@valor,@mes,@ano,@agrupamento,@inicio,@ocorrcodigo,17)
					end try
					begin catch
						insert into tbgabduplicados (funcicodigo,datajornada,rotina_origem)
						values (@funcicodigo,@inicio,'spug_incluirOcorrencias_CRED_BH')
					end catch;

					-- SOMA TODAS AS HORAS RELACIONADAS A CRÉDITO DE BANCO DE HORAS DO DIA
					set @valor = (select sum(cartovaloracumulado) from tbgabcartaototalizador where funcicodigo = @funcicodigo 
					and cartodatajornada = @inicio and cartomesbase = @mes and cartoanobase = @ano and catcartocodigo in(17,6))
					
					-- ATUALIZA REGISTRO DO FUNCIONÁRIO NO CP
					update tbgabcartaodeponto set cartaflagocorrencia = 1,cartacreditobh = @valor 
					where cartadatajornada = @inicio and funcicodigo = @funcicodigo
				end
			end

			--insert into @tabela_ocorrencias values(@funcicodigo, @totalcodigo, @rubricodigo, @mes, @ano, @agrupamento, @inicio, @tipoocorrencia, @ocorrcodigo, @valor, @categoriaocorrencia)
		FETCH NEXT FROM ocorrencias INTO @funcicodigo,@totalcodigo,@rubricodigo,@inicio,@fim,@tipoocorrencia,@ocorrcodigo,@valor,@categoriaocorrencia,@agrupamento,@ocorrabono
		END
	CLOSE ocorrencias
	DEALLOCATE ocorrencias

	-- LIMPA AS OCORRÊNCIAS EXCLUÍDAS DO CARTÃO E DA TABELA DE CARTÃO TOTALIZADOR
	--exec dbo.limpaOcorrencias @mes,@ano, @funcicodigo
END

GO


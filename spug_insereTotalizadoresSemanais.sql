SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




ALTER PROCEDURE [dbo].[spug_insereTotalizadoresSemanais]
	-- Add the parameters for the stored procedure here
	@acordcodigo int,
	@funcicodigo int, 
	@startDate datetime, 
	@endDate datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @totalizador TABLE (minutos int, categoria int, m1 int, m2 int, totalgarantia int, totalrubricagarantido int, complementar int, funcibh bit)
	--declare @totalizador_s table (num int)
	--VARIÁVEIS
	DECLARE
	@categoria int, @faixainicio int, @faixafim int, -- ORDEM, CLASSE E FAIXAS DOS TOTALIZADORES
	@m1 int = 0, @m2 int = 0, @m3 int = 0, @m4 int = 0, -- REGISTRADORES
	@minutos int, @complementar int, -- SAÍDA
	@totalcodigo int, @rubricodigo int, @valoragrupamento float, @totalgarantia int, @totalrubricagarantido int,
	@totalcompensavel smallint, @tipocompensacao smallint,@totalfatorcompensacao float, @totalabsolutoinicio int, @totalabsolutofim int,
	@totalproporcionalvalor float,@mes int, @ano int, @count int, @funcionariobh bit = 0

	select top 1 @mes=cartamesbase,@ano=cartaanobase from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada between @startDate and @endDate

	declare @inicio_semana datetime, @fim_semana datetime
	-- LIMPA CARTÕES TOTALIZADORES SEMANAIS
	/*delete from tbgabcartaototalizador 
	where funcicodigo = @funcicodigo and cartomesbase = @mes and cartoanobase = @ano 
	and totalcodigo in (select T.totalcodigo from tbgabtotalizadortipo T (nolock)
	inner join tbgabtotalizadoracordocoletivo TA (nolock) on T.totalcodigo=TA.totalcodigo
	inner join tbgabacordocoletivo A (nolock) on TA.acordcodigo=A.acordcodigo
	where A.acordcodigo = @acordcodigo and T.totaltipoapuracao = 2)*/
	delete from tbgabcartaototalizador where funcicodigo = @funcicodigo and cartomesbase = @mes and cartoanobase = @ano and cartonumerosemana is not null

	-- LISTA OS TOTALIZADORES SEMANAIS PARA O ACORDO COLETIVO INFORMADO
    DECLARE totalizadores CURSOR FOR
		select 
		totalfaixainicio,
		totalfaixafim,
		totcacodigo,
		T.totalcodigo,
		rubricodigo,
		T.totalpercentualagrupamento,
		totalgarantia,
		totalrubricagarantido,
		totalcompensavel,
		totaltipocompensacao,
		totalfatorcompensacao,
		totalabsolutoinicio,
		totalabsolutofim,
		totalproporcionalvalor
		from tbgabtotalizadortipo T (nolock)
		inner join tbgabtotalizadoracordocoletivo TA (nolock) on T.totalcodigo=TA.totalcodigo
		inner join tbgabacordocoletivo A (nolock) on TA.acordcodigo=A.acordcodigo
		where A.acordcodigo = @acordcodigo and T.totaltipoapuracao = 2 
	OPEN totalizadores
	FETCH NEXT FROM totalizadores INTO @faixainicio,@faixafim,@categoria,@totalcodigo,@rubricodigo,@valoragrupamento,@totalgarantia, @totalrubricagarantido, 
	@totalcompensavel,@tipocompensacao,@totalfatorcompensacao,@totalabsolutoinicio,@totalabsolutofim,@totalproporcionalvalor
	WHILE @@FETCH_STATUS = 0
	BEGIN
		set @minutos = 0
		set @m1 = 0
		set @m2 = 0

		DECLARE semanas CURSOR FOR
			select inicio_semana,fim_semana,case when (horadia-horaprevistasemanal) > 0 then horadia-horaprevistasemanal else 0 end,semana
			from dbo.retornarApuracaoSemanal(@funcicodigo,@startDate,@endDate)
		OPEN semanas
		FETCH NEXT FROM semanas INTO @inicio_semana,@fim_semana,@minutos,@m4
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- VERIFICA SE FUNCIONÁRIO É BH NA SEMANA.
			select @funcionariobh=dbo.retornarSituacaoBhFuncionario(@funcicodigo,@fim_semana)

			-- CATEGORIA HORA EXTRA
			if @categoria = 1
			begin

				-- SE HÁ VALOR A TOTALIZAR
				if @minutos > 0
				begin
					--insert into @totalizador_s values (1)
					--set @m4 = (select count(num) from @totalizador_s)
					-- CARTÃO TOTALIZADOR PRINCIPAL
					begin try
						insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
						cartomesbase,cartoanobase,cartovaloragrupamento,catcartocodigo,cartonumerosemana) values (
						@funcicodigo,@totalcodigo,@rubricodigo,@minutos,@mes,@ano,@valoragrupamento,11,@m4)
					end try
					begin catch
						insert into tbgabduplicados (funcicodigo,rotina_origem)
						values (@funcicodigo,'spug_insereTotalizadoresSemanais')
					end catch;
                end

                -- CARTÃO TOTALIZADOR HORA GARANTIDA
                if @totalgarantia is not null and @minutos < @totalgarantia 
                begin 
                    -- HORAS COMPLEMENTARARES DO TOTALIZADOR
                    set @complementar = @totalgarantia - @minutos
                    begin try
                        insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
                        cartomesbase,cartoanobase,cartovaloragrupamento,catcartocodigo,cartonumerosemana) values (
                        @funcicodigo,@totalcodigo,@totalrubricagarantido,@complementar,@mes,@ano,@valoragrupamento,12,@m4)
                    end try
                    begin catch
                        insert into tbgabduplicados (funcicodigo,rotina_origem)
                        values (@funcicodigo,'spug_insereTotalizadoresSemanais_HG')
                    end catch;
                    set @complementar = @totalgarantia
                end
                else
                begin
                    set @complementar = @minutos
                end

                -- CARTÃO TOTALIZADOR BANCO DE HORAS (CRÉDITO)
                if @totalcompensavel = 2 and @funcionariobh = 1 and @minutos > 0
                begin
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

                    -- SE HÁ VALOR A SER COMPENSADO EM BANCO DE HORAS
                    if @complementar > 0
                    begin
                        set @complementar = @complementar * @totalfatorcompensacao
                        -- INSERE CARTÃO TOTALIZADOR
                        begin try
                            insert into tbgabcartaototalizador (funcicodigo,totalcodigo,rubricodigo,cartovaloracumulado,
                            cartomesbase,cartoanobase,cartovaloragrupamento,catcartocodigo,cartonumerosemana) values (
                            @funcicodigo,@totalcodigo,0,@complementar,@mes,@ano,@totalfatorcompensacao,13,@m4)
                        end try
                        begin catch
                            insert into tbgabduplicados (funcicodigo,rotina_origem)
                            values (@funcicodigo,'spug_insereTotalizadoresSemanais_BH')
                        end catch;
                    end
                end
			end -- END if @categoria = 1	

		FETCH NEXT FROM semanas INTO @inicio_semana,@fim_semana,@minutos,@m4 END
		CLOSE semanas
		DEALLOCATE semanas
		
		insert into @totalizador values (@minutos,@categoria,@m1,@m2,@totalgarantia,@totalrubricagarantido,@complementar,@funcionariobh)
		
	FETCH NEXT FROM totalizadores INTO @faixainicio,@faixafim,@categoria,@totalcodigo,@rubricodigo,@valoragrupamento,@totalgarantia, @totalrubricagarantido,
	@totalcompensavel,@tipocompensacao,@totalfatorcompensacao,@totalabsolutoinicio,@totalabsolutofim,@totalproporcionalvalor
	END
	CLOSE totalizadores
	DEALLOCATE totalizadores

	-- SE NÃO HÁ TOTALIZADOR SEMANAL, DELETA POR SEGURANÇA.
	set @count = (select count(T.totalcodigo) from tbgabtotalizadortipo T (nolock)
				  inner join tbgabtotalizadoracordocoletivo TA (nolock) on T.totalcodigo=TA.totalcodigo
				  where TA.acordcodigo = @acordcodigo and T.totaltipoapuracao = 2)
	if @count = 0
	begin
		delete from tbgabcartaototalizador where cartoanobase = @ano and cartomesbase = @mes and funcicodigo = @funcicodigo and 
		totalcodigo in (select T.totalcodigo from tbgabtotalizadortipo T (nolock)
				  inner join tbgabtotalizadoracordocoletivo TA (nolock) on T.totalcodigo=TA.totalcodigo
				  where TA.acordcodigo = @acordcodigo and T.totaltipoapuracao = 2)
	end 

	-- CATEGORIA DE ESPERA INDENIZÁVEL
	exec dbo.insereEsperaIndenizavel @acordcodigo,@funcicodigo,@startDate,@endDate,2

END

GO

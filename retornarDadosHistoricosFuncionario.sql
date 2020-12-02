SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Jean Paul
-- Create date: 20/05/2019
-- Description:	Trás os dados históricos do funcionário
-- =============================================
ALTER FUNCTION [dbo].[retornarDadosHistoricosFuncionario] 
(
	-- Add the parameters for the function here
	@funcicodigo int,
    @startDate datetime,		
    @endDate datetime	
)
RETURNS 
@tabela TABLE 
(
  dia smallint,
  dt datetime,
  codigo_h bigint,
  indicacao varchar(50),
  cod_escala bigint,
  centccodigo bigint,
  feriado bit,
  feriatipo char(1),
  acordcodigo bigint,
  cargocodigo bigint,
  tpapocodigo int,
  flagocorrencia bit,
  regime int
)
AS
BEGIN
		declare @dt datetime = @startDate;
		declare @dia smallint;
		declare @posterior int = 0;
		declare @cod_escala bigint;
		declare @cod_cc bigint;
		declare @codigo_h bigint;
		declare @indicacao varchar(50);
		declare @feriado int;				-- CONTADOR DE FERIADOS 
		declare @feriatipo char(1);
		declare @dateini date
		declare @datefim date;
		declare @deduzferiado bit;
		declare @acordcodigo bigint;
		declare @cargocodigo bigint;
		declare @tpapocodigo int;
		declare @flagocorrencia bit = 0;	-- INDICA QUE EXISTE UMA OCORRÊNCIA PARA O FUNCIONÁRIO NO DIA
		declare @regime int; -- INDICA O REGIME DA ESCALA (1 DIARISTA, 2 PLANTONISTA)
        declare @table table (dt datetime, dia smallint)
        ;with dateRange as
        (
            select dt = @startDate
            where @startDate < @endDate
            union all
            select dateadd(dd, 1, dt)
            from dateRange
            where dateadd(dd, 1, dt) <= @endDate
        )
        insert into @table select dt,DATEPART(dw,dt) as dia from dateRange OPTION (MAXRECURSION 1000)
        declare @dataCurrent datetime = @startDate
        while @dt <= @endDate      		
		begin
            --RECUPERA A ESCALA DE DETERMINADA DATA
            set @cod_escala = (select top 1 escalcodigo from tbgabfuncionarioescala (nolock) 
                                where funcicodigo = @funcicodigo and fuescdatainiciovigencia <= @dt order by fuescdatainiciovigencia desc, fuescdatamovimentacao desc)

            -- RECUPERA O REGIME DA ESCALA
            set @regime = (select top 1 escalregime from tbgabescala (nolock) where escalcodigo = @cod_escala)

            --RECUPERA O HORÁRIO  E INDICAÇÃO DE DETERMINADA DATA  
            select  @codigo_h = codigohorario,  @indicacao = indicacao from cjRetornarHorarioEscala (@cod_escala,@dt,@dt)

            --RECUPERA O CENTRO DE CUSTO DE DETERMINADA DATA
            set @cod_cc = (select dbo.retornarCentroCustoPorData(@dt,@funcicodigo))
            if @cod_cc <> 0
            begin
                set @cargocodigo = (select top 1 cargocodigo from tbgabcentrocustofuncionario (nolock) where funcicodigo = @funcicodigo and cenfudatainicio <= @dt order by cenfudatainicio desc)
            end
            else
            begin
                set @cargocodigo = 0
            end

            --RECUPERA O ACORDO COLETIVO DE DETERMINADA DATA
            set @acordcodigo = (select dbo.retornarAcordoPorData(@dt,@funcicodigo))

            --RECUPERA O TIPO DE ENTRADA DE DADOS DE DETERMINADA DATA
            set @posterior = (select count(entfucodigo) from tbgabentradaapontamentofuncionario (nolock) where funcicodigo = @funcicodigo and entfudatavinculacao > @dt)

            if @posterior > 0
            begin
                set @tpapocodigo = (select top 1 tpapocodigo from tbgabentradaapontamentofuncionario (nolock) where funcicodigo = @funcicodigo and entfudatavinculacao <= @dt order by entfudatavinculacao desc)
            end
            else
            begin
                set @tpapocodigo = (select top 1 tpapocodigo from tbgabentradaapontamentofuncionario (nolock) where funcicodigo = @funcicodigo order by entfudatavinculacao desc)
            end

            -- VERIFICA SE PARA DETERMINADA ESCALA, O FERIADO É DEDUZIDO OU NÃO
            set @deduzferiado = (select top 1 fuescdeduzferiado from tbgabfuncionarioescala (nolock) where funcicodigo = @funcicodigo and escalcodigo = @cod_escala) 

            set @feriado = (select count(F.feriacodigo) from tbgabcentrocusto CC (nolock) 
            inner join tbgabtabelaferiadoferiado TF (nolock) on CC.fertbcodigo=tf.fertbcodigo
            inner join tbgabferiado F (nolock) on TF.feriacodigo=F.feriacodigo
            where CC.centccodigo = @cod_cc and F.feriames = DATEPART(month,@dt) and F.feriadia = DATEPART(day,@dt))

            --	set @indicacao = (select indicacao from cjRetornarHorarioEscala (@cod_escala,@dt,@dt))     -- FOI OTIMIZADO NO SELECT DE RECUPERACAO DE HORARIO E INDICACAO

            -- QUANDO DEDUZIR FERIADO INDICA QUE O FUNCIONÁRIO TRABALHA NO REGIME DIARISTA, CASO AO CONTRÁRIO PLANTONISTA.
            if @feriado > 0 --and @deduzferiado = 1
            begin
                set @feriado = 1;
                --set @indicacao = 'Feriado'
                set @feriatipo = (select top 1 F.fertpcodigo
                from tbgabcentrocusto CC (nolock) 
                inner join tbgabtabelaferiadoferiado TF (nolock) on CC.fertbcodigo=tf.fertbcodigo
                inner join tbgabferiado F (nolock) on TF.feriacodigo=F.feriacodigo
                where CC.centccodigo = @cod_cc and F.feriames = DATEPART(month,@dt) and F.feriadia = DATEPART(day,@dt))
            end
            else
            begin
                set @feriado = 0;
                set @feriatipo = '';
            end

            -- VERIFICA SE PARA O DIA HÁ UMA OU MAIS OCORRÊNCIAS
            set @flagocorrencia = (select case when count(ocorrcodigo) > 0 then 1 else 0 end from tbgabocorrencia where funcicodigo = @funcicodigo and convert(date,ocorrinicio) = @dt)

            insert into @tabela values ((select dia from @table where dt = @dt),@dt,@codigo_h,@indicacao,@cod_escala,@cod_cc,@feriado,@feriatipo,
            @acordcodigo,@cargocodigo,@tpapocodigo,@flagocorrencia,@regime)			

            set @dt = dateadd(day,1,@dt)
		end
	RETURN 
END
GO
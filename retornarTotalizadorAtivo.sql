SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--set dateformat ymd select dbo.retornarTotalizadorAtivo(12354,'2019-05-05',15,0)
-- =============================================
-- Author:		Jean Paul
-- alter date: 16/08/2019
-- Description: Retornar se totalizador está habilitado ou não para um dia específico
-- =============================================
ALTER FUNCTION [dbo].[retornarTotalizadorAtivo] (@funcicodigo int, @datajornada datetime, @operador bit, @totalcodigo int)
 
RETURNS INT--BIT
AS
BEGIN
	DECLARE @dom bit, @seg bit, @ter bit, @qua bit, @qui bit, @sex bit, @sab bit -- DIAS
	DECLARE @dsr bit, @folga bit, @feriado bit -- OCORRÊNCIAS
	DECLARE @flag bit, @dia smallint, @ocorrencia int, @flagferiado bit
	DECLARE @TESTE int = 0

	select 
    @flagferiado=cartaflagferiado,
    @dia=cartadiasemana,
    @ocorrencia=ctococodigo
    from tbgabcartaodeponto (nolock) 
    where funcicodigo = @funcicodigo and cartadatajornada = @datajornada
	
    select 
    @dsr=totalflagsituacaodsr,
    @folga=totalflagsituacaofolga,
    @feriado=totalflagsituacaoferiado,
    @dom=totalflagdiadom,
    @seg=totalflagdiaseg,
    @ter=totalflagdiater,
    @qua=totalflagdiaqua,
    @qui=totalflagdiaqui,
    @sex=totalflagdiasex,
    @sab=totalflagdiasab
    from tbgabtotalizadortipo (nolock) 
    where totalcodigo = @totalcodigo
	
	declare @flag2 int = 0
	set @flag = 0
		
	-- SE A SITUAÇÃO EM QUE OCORRE NÃO ESTIVER MARCADA, SÓ CONSIDERA OS DIAS.
	if @folga = 0 and @feriado = 0 and @dsr = 0
	begin
		-- SE ESTIVER MARCADO PARA TRABALHAR DOMINGO E FOR DOMINGO
		if @dia = 1 and @dom = 1
		begin
			set @flag = 1
		end
		-- SE ESTIVER MARCADO PARA TRABALHAR SEGUNDA E FOR SEGUNDA
		else if @dia = 2 and @seg = 1
		begin
			set @flag = 1
		end
		-- SE ESTIVER MARCADO PARA TRABALHAR TERÇA E FOR TERÇA
		else if @dia = 3 and @ter = 1
		begin
			set @flag = 1
		end
		-- SE ESTIVER MARCADO PARA TRABALHAR QUARTA E FOR QUARTA
		else if @dia = 4 and @qua = 1
		begin
			set @flag = 1
		end
		-- SE ESTIVER MARCADO PARA TRABALHAR QUINTA E FOR QUINTA
		else if @dia = 5 and @qui = 1
		begin
			set @flag = 1
		end
		-- SE ESTIVER MARCADO PARA TRABALHAR SEXTA E FOR SEXTA
		else if @dia = 6 and @sex = 1
		begin
			set @flag = 1
		end
		-- SE ESTIVER MARCADO PARA TRABALHAR SÁBADO E FOR SÁBADO
		else if @dia = 7 and @sab = 1
		begin
			set @flag = 1
		end
	end

	-- SE NÃO, VERIFICA EM QUAL OPERADOR LÓGICO A SITUAÇÃO SE ENCONTRA
	else
	begin 
	
		-- SE A SITUAÇÃO QUE OCORRE FOR "OU"
		if @operador = 0
		begin
			-- SE TRABALHAR NA FOLGA, TRABALHAR NO DSR OU TRABALHAR NO FERIADO 
			if (@ocorrencia = 2 or @ocorrencia = 3 or @ocorrencia = 4) and (@folga = 1 or @dsr = 1 or (@feriado = 1 and @flagferiado = 1))
			begin
				set @flag2 = 10
				-- SE ESTIVER MARCADO PARA TRABALHAR DOMINGO
				if @dia = 1 and @dom = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEGUNDA
				else if @dia = 2 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR TERÇA
				else if @dia = 3 and @ter = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUARTA
				else if @dia = 4 and @qua = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUINTA
				else if @dia = 5 and @qui = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEXTA
				else if @dia = 6 and @sex = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SÁBADO
				else if @dia = 7 and @sab = 1
				begin
					set @flag = 1
				end
			end
			-- SE TRABALHAR NO FERIADO 
			else if (@ocorrencia = 1 and @flagferiado = 1) and (@folga = 0  and @dsr = 0 and @feriado = 1)
			begin
				set @flag2 = 20
				-- SE ESTIVER MARCADO PARA TRABALHAR DOMINGO
				if @dia = 1 and @dom = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEGUNDA
				else if @dia = 2 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR TERÇA
				else if @dia = 3 and @ter = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUARTA
				else if @dia = 4 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUINTA
				else if @dia = 5 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEXTA
				else if @dia = 6 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SÁBADO
				else if @dia = 7 and @seg = 1
				begin
					set @flag = 1
				end
			end
		end
		-- SE A SITUAÇÃO QUE OCORRE FOR "E"
		else if @operador = 1 
		begin
			-- SE TRABALHAR NA FOLGA
			if (@ocorrencia = 2 and @flagferiado = 0) and (@folga = 1 and @feriado = 0) 
			begin
				set @flag2 = 10
				-- SE ESTIVER MARCADO PARA TRABALHAR DOMINGO
				if @dia = 1 and @dom = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEGUNDA
				else if @dia = 2 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR TERÇA
				else if @dia = 3 and @ter = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUARTA
				else if @dia = 4 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUINTA
				else if @dia = 5 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEXTA
				else if @dia = 6 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SÁBADO
				else if @dia = 7 and @seg = 1
				begin
					set @flag = 1
				end
			end
			-- SE TRABALHAR NA FOLGA E FERIADO 
			else if (@ocorrencia = 2 and @flagferiado = 1) and (@folga = 1 and @feriado = 1) 
			begin
				set @flag2 = 2
				-- SE ESTIVER MARCADO PARA TRABALHAR DOMINGO
				if @dia = 1 and @dom = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEGUNDA
				else if @dia = 2 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR TERÇA
				else if @dia = 3 and @ter = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUARTA
				else if @dia = 4 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUINTA
				else if @dia = 5 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEXTA
				else if @dia = 6 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SÁBADO
				else if @dia = 7 and @seg = 1
				begin
					set @flag = 1
				end
			end
			-- SE TRABALHAR NO DSR
			else if(@ocorrencia = 3 and @flagferiado = 0) and (@dsr = 1 and @folga = 0 and @feriado = 0)
			begin
				set @flag2 = 3
				-- SE ESTIVER MARCADO PARA TRABALHAR DOMINGO
				if @dia = 1 and @dom = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEGUNDA
				else if @dia = 2 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR TERÇA
				else if @dia = 3 and @ter = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUARTA
				else if @dia = 4 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUINTA
				else if @dia = 5 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEXTA
				else if @dia = 6 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SÁBADO
				else if @dia = 7 and @seg = 1
				begin
					set @flag = 1
				end
			end
			-- SE TRABALHAR NO DSR E FERIADO
			else if(@ocorrencia = 3 and @flagferiado = 1) and (@dsr = 1 and @feriado = 1) 
			begin
				set @flag2 = 4
				-- SE ESTIVER MARCADO PARA TRABALHAR DOMINGO
				if @dia = 1 and @dom = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEGUNDA
				else if @dia = 2 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR TERÇA
				else if @dia = 3 and @ter = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUARTA
				else if @dia = 4 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUINTA
				else if @dia = 5 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEXTA
				else if @dia = 6 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SÁBADO
				else if @dia = 7 and @seg = 1
				begin
					set @flag = 1
				end
			end
			-- SE TRABALHAR NO FERIADO SOMENTE
			else if (@flagferiado = 1 and @folga = 0 and @feriado = 0 and @dsr = 0) 
			begin
				set @flag2 = 5
				-- SE ESTIVER MARCADO PARA TRABALHAR DOMINGO
				if @dia = 1 and @dom = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEGUNDA
				else if @dia = 2 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR TERÇA
				else if @dia = 3 and @ter = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUARTA
				else if @dia = 4 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR QUINTA
				else if @dia = 5 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SEXTA
				else if @dia = 6 and @seg = 1
				begin
					set @flag = 1
				end
				-- SE ESTIVER MARCADO PARA TRABALHAR SÁBADO
				else if @dia = 7 and @seg = 1
				begin
					set @flag = 1
				end
			end
		end
	end
 
RETURN(@flag)
END
GO

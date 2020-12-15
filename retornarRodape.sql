SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[retornarRodape] (@funcicodigo int, @inicio datetime, @fim datetime)
 
RETURNS 
@footer table (
obs varchar(max),
table1 varchar(max),
table2 varchar(max)
)
AS
BEGIN
	declare 
	@acordcodigo int, @mes int, @ano int, @ocorrinicio datetime, @ocorrfim datetime,
	@ocorrmotivo varchar(max) = '', @observacoes varchar(max) = '', @observacoes2 varchar(max) = '', @tabela1 varchar(max) = '', 
	@tabela2 varchar (max) = '', @totalizador varchar (max) = '', @resumo varchar (max) = '', @texto varchar(200) = '', @valor varchar(10) = '',
	@acumulador varchar (max) = '', @ocorrencias varchar (max) = '', @dia1 char(3), @dia2 char(3), 
	@semana char(1), @inicio_semana datetime, @fim_semana datetime, @dias_uteis char(3), @realizada varchar(6), 
	@prevista varchar(6),@rubrica varchar(100),@sumtotalizadorsem char(6),
	@categoria int, @abonos int

	select top 1 @acordcodigo = acordcodigo,@mes = cartamesbase,@ano = cartaanobase from tbgabcartaodeponto (nolock) where cartadatajornada between @inicio and @fim and funcicodigo = @funcicodigo
 
	-- OCORRÊNCIAS DE AFASTAMENTO
	DECLARE afastamentos CURSOR FOR  
	select O.ocorrinicio,O.ocorrfim,O.ocorrmotivo,OC.tpocotipo from tbgabocorrencia O (nolock) 
	inner join tbgabocorrenciatipo OT (nolock) on O.tpococodigo=OT.tpococodigo
	inner join tbgabocorrenciaclasse OC (nolock) on OT.tpocotipo=OC.tpocotipo
	where O.funcicodigo = @funcicodigo and OC.tpocotipo in (1) and OT.tpocosituacao = 1 and
	(OT.tpocointegravel = 0 or (OT.tpocointegravel = 1 and (O.sitme in (10,11) or OT.tpocoexigeaprovacao = 0))) and
	(
	(O.ocorrinicio between @inicio and @fim)
	or
	(O.ocorrfim between @inicio and @fim)
	-- IMPLEMENTAÇÃO DEMANDA 292, 06/08/2020, JEAN PAUL.
	or
	(ocorrinicio < @inicio and ocorrfim > @fim)
	-- FIM IMPLEMENTAÇÃO.
	);
	OPEN afastamentos;  
	FETCH NEXT FROM afastamentos INTO @ocorrinicio,@ocorrfim,@ocorrmotivo,@categoria;  
	WHILE @@FETCH_STATUS = 0  
	   BEGIN  
		  if @categoria = 1
		  begin
			  if convert(date,@ocorrinicio) <> convert(date,@ocorrfim)
			  begin
				set @observacoes += 'Afastamento de '+
				convert(varchar,datepart(day,@ocorrinicio))+'/'+convert(varchar,datepart(month,@ocorrinicio))+'/'+convert(varchar,datepart(year,@ocorrinicio))
				+' até '+
				convert(varchar,datepart(day,@ocorrfim))+'/'+convert(varchar,datepart(month,@ocorrfim))+'/'+convert(varchar,datepart(year,@ocorrfim))+'. Motivo: '+@ocorrmotivo+'<br>';
			  end
			  else
			  begin
				set @observacoes += 'Afastamento de '+convert(varchar,datepart(day,@ocorrinicio))+'/'+convert(varchar,datepart(month,@ocorrinicio))+'/'+convert(varchar,datepart(year,@ocorrinicio))+'. Motivo: '+@ocorrmotivo+'<br>';
			  end
		  end
		  FETCH NEXT FROM afastamentos INTO @ocorrinicio,@ocorrfim,@ocorrmotivo,@categoria;  
	   END;  
	CLOSE afastamentos;  
	DEALLOCATE afastamentos;  
	
	/*set @abonos = ( select sum(ocorrvalor) from tbgabocorrencia O (nolock) 
					inner join tbgabocorrenciatipo OT (nolock) on O.tpococodigo=OT.tpococodigo
					where funcicodigo = @funcicodigo and convert(date,O.ocorrinicio) between @inicio and @fim  and OT.tpocotipo = 2 and OT.tpocosituacao = 1 
					and (OT.tpocointegravel = 0 or (OT.tpocointegravel = 1 and (O.sitme in (10,11) or OT.tpocoexigeaprovacao = 0))))
	if @abonos is not null and @abonos > 0 begin set @observacoes2 = 'TOTAL DE ABONO: '+ dbo.CONVERTE_MINUTO_HORA(@abonos)+' HORA(S) <br>' end else begin set @observacoes2 = '' end*/
	--set @observacoes += @observacoes2
	if @observacoes <> '' begin set @observacoes = '<fieldset class="fieldset"><legend class="legend">Observações:</legend>'+@observacoes+'</fieldset><br><br>'; end

	-- VERIFICA SE HÁ TOTALIZADOR SEMANAL
	if (select count(TA.totalcodigo) from tbgabtotalizadoracordocoletivo TA (nolock)
	inner join tbgabtotalizadortipo T on TA.totalcodigo=T.totalcodigo
	where TA.acordcodigo = @acordcodigo and T.totaltipoapuracao = 2) > 0
	begin
		DECLARE apuracao_semanal CURSOR FOR  
		select 
		semana,inicio_semana,fim_semana,dias_uteis,
		dbo.CONVERTE_MINUTO_HORA(horadia),
		dbo.CONVERTE_MINUTO_HORA(horaprevistasemanal),
		case 
		when dia_inicio = 1 then 'Dom'
		when dia_inicio = 2 then 'Seg'
		when dia_inicio = 3 then 'Ter'
		when dia_inicio = 4 then 'Qua'
		when dia_inicio = 5 then 'Qui'
		when dia_inicio = 6 then 'Sex'
		when dia_inicio = 7 then 'Sáb' end as dia1,
		case 
		when dia_fim = 1 then 'Dom'
		when dia_fim = 2 then 'Seg'
		when dia_fim = 3 then 'Ter'
		when dia_fim = 4 then 'Qua'
		when dia_fim = 5 then 'Qui'
		when dia_fim = 6 then 'Sex'
		when dia_fim = 7 then 'Sáb' end as dia2
		from retornarApuracaoSemanal(@funcicodigo,@inicio,@fim)  
		OPEN apuracao_semanal;  
		FETCH NEXT FROM apuracao_semanal INTO @semana,@inicio_semana,@fim_semana,@dias_uteis,@realizada,@prevista,@dia1,@dia2;
		WHILE @@FETCH_STATUS = 0  
		   BEGIN  
				set @resumo += '<tr><th>Semana: '+@semana+'</th>';
				set @resumo += '<th>Início: '+convert(varchar,datepart(day,@inicio_semana))+'/'+convert(varchar,datepart(month,@inicio_semana))+'/'+convert(varchar,datepart(year,@inicio_semana))+' '+@dia1+'</th>';
				set @resumo += '<th>Fim: '+convert(varchar,datepart(day,@fim_semana))+'/'+convert(varchar,datepart(month,@fim_semana))+'/'+convert(varchar,datepart(year,@fim_semana))+' '+@dia2+'</th>';
				set @resumo += '<th>Dias Úteis: '+@dias_uteis+'</th>';
				set @resumo += '<th>Carga Horária Semanal: '+@prevista+'</th>';
				set @resumo += '<th>Carga Horária Realizada: '+@realizada+'</th>';

				--set @totalizador += '<tr>'
				DECLARE totalizadoresPorSemana CURSOR FOR  
				select R.rubridescricao,dbo.CONVERTE_MINUTO_HORA(sum(cartovaloracumulado)) from tbgabcartaototalizador (nolock) CT
				inner join tbgabtotalizadortipo TT (nolock) on CT.totalcodigo = TT.totalcodigo
				inner join tbgabrubrica R (nolock) on CT.rubricodigo = R.rubricodigo
				where cartodatajornada between @inicio_semana and @fim_semana and funcicodigo = @funcicodigo
				group by CT.totalcodigo,R.rubricodigo,R.rubridescricao;  
				OPEN totalizadoresPorSemana;  
				FETCH NEXT FROM totalizadoresPorSemana INTO @rubrica,@sumtotalizadorsem;  
				WHILE @@FETCH_STATUS = 0  
				   BEGIN  
					 set @resumo += '<th>'+@rubrica+': '+@sumtotalizadorsem+'</th>';
					  FETCH NEXT FROM totalizadoresPorSemana INTO @rubrica,@sumtotalizadorsem;  
				   END;  
				CLOSE totalizadoresPorSemana;  
				DEALLOCATE totalizadoresPorSemana;
				--set @totalizador += '</tr>'
				set @totalizador += '</tr>'
			  FETCH NEXT FROM apuracao_semanal INTO @semana,@inicio_semana,@fim_semana,@dias_uteis,@realizada,@prevista,@dia1,@dia2;  
		   END;  
		CLOSE apuracao_semanal;  
		DEALLOCATE apuracao_semanal; 
		
		set @tabela1 +=	'<fieldset class="fieldset"><legend class="legend">Resumo Semanal:</legend>'+
						'<table id="main_table_semanal">'+
							'<tr>'+
								'<td style="vertical-align: top;">'+
									'<table class="acumuladores">'+@resumo+'</table>'+
								'</td>'+
								/*'<td style="vertical-align: top;">'+
									'<table class="acumuladores">'+@totalizador+'</table>'+
								'</td>'+*/
							'</tr>'+
						'</table>'+
						'</fieldset><br><br>';
	end	

	-- TABELA 2
	set @totalizador = '';
	-- LISTA TOTALIZADORES DIÁRIOS, MENSAIS, DIÁRIOS COM APURAÇÕES DE HR GARANTIDA MENSAL E COMPLEMENTAR
	DECLARE totalizadores CURSOR FOR  
	select texto,valor from dbo.retornarResumoTotalizadores(@funcicodigo,@mes,@ano) where categoria <> 2;  
	OPEN totalizadores;  
	FETCH NEXT FROM totalizadores INTO @texto,@valor;  
	WHILE @@FETCH_STATUS = 0  
	   BEGIN  
		  if @valor <> '00:00'
		  begin
			set @totalizador +='<tr><th>'+@texto+'</th><td>'+@valor+'</td></tr>'; 
		  end
		  FETCH NEXT FROM totalizadores INTO @texto,@valor;  
	   END;  
	CLOSE totalizadores;  
	DEALLOCATE totalizadores;

	-- LISTA POR CATEGORIA DE TOTALIZADOR
	DECLARE acumuladores CURSOR FOR  
	select texto,valor from dbo.retornarTotalCategoriaResumo(@funcicodigo,@mes,@ano);  
	OPEN acumuladores;  
	FETCH NEXT FROM acumuladores INTO @texto,@valor;  
	WHILE @@FETCH_STATUS = 0  
	   BEGIN  
		  if @valor <> '00:00'
		  begin
			set @acumulador +='<tr><th>'+@texto+'</th><td>'+@valor+'</td></tr>'; 
		  end
		  FETCH NEXT FROM acumuladores INTO @texto,@valor;  
	   END;  
	CLOSE acumuladores;  
	DEALLOCATE acumuladores;

	-- HORA PREVISTA MENSAL ESCALA
	select @prevista = dbo.CONVERTE_MINUTO_HORA(horaprevistamensal), @realizada = dbo.CONVERTE_MINUTO_HORA(horadia), @dias_uteis = dias_uteis from dbo.retornarAcumuladores(@funcicodigo,@inicio,@fim);  
	set @resumo = '<tr><th>Carga Horária Mensal</th><td>'+@prevista+'</td></tr>';
	set @resumo += '<tr><th>Carga Horária Realizada</th><td>'+@realizada+'</td></tr>';
	set @resumo += '<tr><th>Dias Úteis</th><td>'+@dias_uteis+'</td></tr>';

	-- OCORRÊNCIAS
	DECLARE ocorrencias CURSOR FOR  
	select coalesce('Ocorrência ' + OC.tpococlassedescricao + ' - '+R.rubridescricao,'Ocorrência '+OC.tpococlassedescricao + ' - Sem Rubrica'),dbo.CONVERTE_MINUTO_HORA(sum(CT.cartovaloracumulado)) from tbgabcartaototalizador CT (nolock) 
	inner join tbgabocorrencia O (nolock) on CT.ocorrcodigo = O.ocorrcodigo
	inner join tbgabocorrenciatipo OT (nolock) on O.tpococodigo = OT.tpococodigo
	inner join tbgabocorrenciaclasse OC (nolock) on OT.tpocotipo = OC.tpocotipo
	left join tbgabrubrica R (nolock) on CT.rubricodigo = R.rubricodigo
	where CT.funcicodigo = @funcicodigo and CT.catcartocodigo <> 114 and CT.catcartocodigo <> 115 and cartodatajornada between @inicio and @fim and CT.totalcodigo = 0 group by OT.tpocotipo,OC.tpococlassedescricao,R.rubridescricao
	OPEN ocorrencias;  
	FETCH NEXT FROM ocorrencias INTO @texto, @valor;  
	WHILE @@FETCH_STATUS = 0  
	   BEGIN  
		  set @ocorrencias +='<tr><th>'+@texto+'</th><td>'+@valor+'</td></tr>';
		  FETCH NEXT FROM ocorrencias INTO @texto, @valor;  
	   END;  
	CLOSE ocorrencias;  
	DEALLOCATE ocorrencias;

	set @tabela2 =  '<fieldset class="fieldset"><legend class="legend">Resumo:</legend>'+
						'<table id="main_table">'+
							'<tr>'+
								'<td style="vertical-align: top;"><table class="acumuladores">'+@totalizador+'</table></td>'+
								'<td style="vertical-align: top;"><table class="acumuladores">'+@ocorrencias+'</table></td>'+
								'<td style="vertical-align: top;"><table class="acumuladores">'+@acumulador+'</table></td>'+
								'<td style="vertical-align: top;"><table class="acumuladores">'+@resumo+'</table></td>'+
							'</tr>'+
						'</table>'+
					'</fieldset><br>';

	insert into @footer values (@observacoes,@tabela1,@tabela2)
	RETURN;
END


GO

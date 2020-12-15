SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Jean Paul
-- Create date: 20/05/2019
-- Description:	Trás os dados históricos do funcionário
-- =============================================
ALTER FUNCTION [dbo].[retornarApuracaoSemanal] 
(
	-- Add the parameters for the function here
	@funcicodigo bigint,
    @startDate datetime,		
    @endDate datetime	
)
RETURNS 
@tabela TABLE 
(
  semana smallint,
  inicio_semana datetime,
  dia_inicio smallint,
  fim_semana datetime,
  dia_fim smallint,
  horaprevistaescala int,
  horadia int,
  horafaltasemanal int,
  dias_uteis smallint,
  horaextrasemanal int,
  horaprevistasemanal int,
  horanoturna int
)
AS
BEGIN
		
		declare @semana smallint = 0, @inicio_semana datetime = '1900-01-01', @fim_semana datetime = '1900-01-01', @dia_inicio smallint, @dia_fim smallint,
		@horaprevistaescala int,@horadia int, @horafaltasemanal int, @dia_uteis int, @horaextrasemanal int, @horaprevistasemanal int, @horanoturna int

		select @horaprevistaescala = menor_fator from dbo.retornarMinimoFatorMensalNoPeriodo(@funcicodigo,@startDate,@endDate)

		declare dias cursor for
			WITH CTE_SEMANAS(CODIGO) AS
				(
				SELECT 1
				UNION ALL
				SELECT CODIGO +1 FROM CTE_SEMANAS
				WHERE CODIGO < 6 -- o numero maximo
				)
				select 
				CODIGO
				from CTE_SEMANAS CTE 
				option (MAXRECURSION 5)

			open dias
			fetch next from dias into @semana
			while @@FETCH_STATUS=0
			begin
				
				set @inicio_semana = (select top 1 cartadatajornada 
				from tbgabcartaodeponto (nolock) 
				where funcicodigo = @funcicodigo and cartadatajornada between @startDate and @endDate 
				and cartadatajornada > @fim_semana order by cartadatajornada)

				set @dia_inicio = (select top 1 cartadiasemana
				from tbgabcartaodeponto (nolock) 
				where funcicodigo = @funcicodigo and cartadatajornada = @inicio_semana)
				
				if @dia_inicio <> 7
				begin
					set @fim_semana = (select top 1 cartadatajornada 
					from tbgabcartaodeponto (nolock) 
					where funcicodigo = @funcicodigo and cartadatajornada between @startDate and @endDate
					and cartadatajornada > @inicio_semana order by cartadiasemana desc,cartadatajornada)
				end
				else
				begin
					set @fim_semana = @inicio_semana
				end

				set @dia_fim = (select top 1 cartadiasemana
				from tbgabcartaodeponto (nolock) 
				where funcicodigo = @funcicodigo and cartadatajornada = @fim_semana)

				declare acumuladores cursor for
					select coalesce(sum(cartacargahoraria),0),sum(cartacargahorariarealizada),sum(cartahorasfalta),sum(cartaadn)/*,coalesce(sum(H.horarfatorcargamensal),0)*/ from tbgabcartaodeponto CP (nolock) 
					--left join tbgabhorario H (nolock) on CP.horarcodigo=H.horarcodigo 
					where funcicodigo = @funcicodigo and cartadatajornada between @inicio_semana and @fim_semana
				open acumuladores
				fetch next from acumuladores into @horaprevistasemanal,@horadia,@horafaltasemanal,@horanoturna--,@horaprevistaescala
				while @@FETCH_STATUS=0
				begin
					if @inicio_semana is not null and @fim_semana is not null
					begin
						set @dia_uteis = (select count(ctococodigo) from tbgabcartaodeponto (nolock) 
										  where funcicodigo = @funcicodigo and ctococodigo = 1 and cartadatajornada between @inicio_semana and @fim_semana)

						insert into @tabela values (@semana,@inicio_semana,@dia_inicio,
						@fim_semana,@dia_fim,@horaprevistaescala,@horadia,@horafaltasemanal,
						@dia_uteis,@horaextrasemanal,@horaprevistasemanal,@horanoturna)
					end
				fetch next from acumuladores into @horaprevistasemanal,@horadia,@horafaltasemanal,@horanoturna/*,@horaprevistaescala*/ end
				close acumuladores
				deallocate acumuladores
			
			fetch next from dias into @semana end
		close dias
		deallocate dias
	RETURN 
END
GO

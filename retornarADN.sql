
GO

/****** Object:  UserDefinedFunction [dbo].[retornarADN]    Script Date: 26/11/2020 11:19:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER FUNCTION [dbo].[retornarADN] (@funcicodigo int, @inicionoturno datetime,@fimnoturno datetime, @fatornoturno float, @cartadata datetime, @estendenoturno bit)
 
RETURNS 
@tempo table (
adn int,
minutos int, 
inicionoturno datetime, 
fimnoturno datetime, 
interval1 int,
interval2 int, 
interval3 int, 
interval4 int)
AS
BEGIN
	DECLARE @adn int,@minutos int
	DECLARE @interval1 int = 0, @interval2 int = 0, @interval3 int = 0, @interval4 int = 0
	DECLARE @periodo1 int = 0, @periodo2 int = 0, @periodo3 int = 0
	DECLARE @cartacodigo int = (select top 1 cartacodigo from tbgabcartaodeponto (nolock) where funcicodigo = @funcicodigo and cartadatajornada = @cartadata)

	if @inicionoturno is not null and @fimnoturno is not null
	begin
		set @interval1 = (select coalesce(adn,0) from dbo.retornarInterval1_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		set @interval2 = (select coalesce(adn,0) from dbo.retornarInterval2_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		set @interval3 = (select coalesce(adn,0) from dbo.retornarInterval3_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		set @interval4 = (select coalesce(adn,0) from dbo.retornarInterval4_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))

		if (select contabiliza from dbo.retornarIntervalosFuncionario(@cartacodigo,1) where contabiliza = 1) is not null
		begin
			set @periodo1 = (select coalesce(adn,0) from dbo.retornarPeriodo1_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		end

		if (select contabiliza from dbo.retornarIntervalosFuncionario(@cartacodigo,2) where contabiliza = 1) is not null
		begin
			set @periodo2 = (select coalesce(adn,0) from dbo.retornarPeriodo2_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		end

		if (select contabiliza from dbo.retornarIntervalosFuncionario(@cartacodigo,3) where contabiliza = 1) is not null
		begin
			set @periodo3 = (select coalesce(adn,0) from dbo.retornarPeriodo3_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		end
		
		set @adn = @interval1 + @interval2 + @interval3 + @interval4 + @periodo1 + @periodo2 + @periodo3

		set @interval1 = (select coalesce(minutos,0) from dbo.retornarInterval1_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		set @interval2 = (select coalesce(minutos,0) from dbo.retornarInterval2_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		set @interval3 = (select coalesce(minutos,0) from dbo.retornarInterval3_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		set @interval4 = (select coalesce(minutos,0) from dbo.retornarInterval4_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))

		if (select contabiliza from dbo.retornarIntervalosFuncionario(@cartacodigo,1) where contabiliza = 1) is not null
		begin
			set @periodo1 = (select coalesce(minutos,0) from dbo.retornarPeriodo1_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		end

		if (select contabiliza from dbo.retornarIntervalosFuncionario(@cartacodigo,2) where contabiliza = 1) is not null
		begin
			set @periodo2 = (select coalesce(minutos,0) from dbo.retornarPeriodo2_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		end

		if (select contabiliza from dbo.retornarIntervalosFuncionario(@cartacodigo,3) where contabiliza = 1) is not null
		begin
			set @periodo3 = (select coalesce(minutos,0) from dbo.retornarPeriodo3_ADN(@funcicodigo,@inicionoturno,@fimnoturno,@fatornoturno,@cartadata,@estendenoturno))
		end

		set @minutos = @interval1 + @interval2 + @interval3 + @interval4 + @periodo1 + @periodo2 + @periodo3
		
	end
	else
	begin
		set @minutos = 0
		set @adn = 0
	end
	insert into @tempo values (@adn,@minutos,@inicionoturno,@fimnoturno,@interval1,@interval2,@interval3,@interval4)
	
	RETURN;
END
GO


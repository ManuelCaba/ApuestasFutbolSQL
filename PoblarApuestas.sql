SET NOCOUNT ON

DECLARE @Apuestas Int = Floor(rand()*400) + 600
DECLARE @DineroApostado Int
DECLARE @Partido Int
DECLARE @ProbabilidadComprobada TinyInt
DECLARE @Cont SmallInt = 1
DECLARE @Comprobada Bit
DECLARE @NickUsuario Varchar(20)
DECLARE @TipoApuesta TinyInt
DECLARE @Resultado TinyInt
DECLARE @Apuesta SmallInt


BEGIN TRANSACTION

WHILE @Cont <= @Apuestas
	BEGIN
		
		SET @DineroApostado = Floor(rand() * 150) + 50
		SET @ProbabilidadComprobada = Floor(rand() * 9) + 1
		SET @TipoApuesta = Floor(rand() * 3) + 1

		SELECT TOP 1 @NickUsuario = Nick FROM Usuarios
		ORDER BY NEWID()

		SELECT TOP 1 @Partido = ID FROM Partidos
		ORDER BY NEWID()

		IF @ProbabilidadComprobada > 4
			SET @Comprobada = 0
		ELSE
			SET @Comprobada = 1
		
		IF(NOT EXISTS (SELECT * FROM Apuestas WHERE NickUsuario = @NickUsuario AND IDPartido = @Partido))
			BEGIN
				INSERT Apuestas (DineroApostado, IDPartido, NickUsuario, Comprobada)
				SELECT @DineroApostado,@Partido, @NickUsuario, @Comprobada

				SET @Apuesta = @@IDENTITY

				IF @TipoApuesta = 1
					BEGIN
						SET @Resultado = Floor(rand() * 3) + 1

						INSERT GanadoresPartidos
						VALUES(@Apuesta, (
											SELECT CASE @Resultado
													WHEN 1 THEN '1'
													WHEN 2 THEN 'X'
													ELSE '2'
												   END
										 ))
					END
				ELSE IF @TipoApuesta = 2
					BEGIN
						PRINT 'En construccion 2'
					END
				ELSE
					BEGIN
						PRINT 'En construccion 3'
					END

				SET @Cont += 1
			END
	END

--SELECT * FROM Apuestas

SELECT * FROM Apuestas
ORDER BY NickUsuario

--SELECT * FROM Apuestas
--ORDER BY IDPartido

--ROLLBACK

--DBCC CHECKIDENT (Apuestas, RESEED,0)
--SELECT * FROM Apuestas

--DELETE FROM Apuestas
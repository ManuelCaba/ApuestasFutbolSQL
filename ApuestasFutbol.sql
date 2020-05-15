
Create Database ApuestasFutbol
GO
Use ApuestasFutbol
GO


SET NOCOUNT ON
GO

Create Table Usuarios (

	Nick Varchar(20) NOT NULL,
	Contraseña Varchar(32) NOT NULL,
	Saldo Smallmoney NOT NULL Default 0,
	FechaAlta Date NULL,
	FechaBaja Date NULL,

	Constraint PKUsuarios Primary Key (Nick),
	Constraint CKNick Check (DATALENGTH(Nick) >= 3),
	Constraint CKContraseña Check (DATALENGTH(Contraseña) > 7),
	Constraint CKFechaAlta Check (FechaAlta < FechaBaja),
	Constraint CKFechaBaja Check (FechaBaja < GETDATE())

)
GO

Create Table Equipos (

	ID Char(4) NOT NULL,
	Nombre VarChar(20) NOT NULL,
	Ciudad VarChar(25) NULL,
	Pais VarChar (20) NULL,

	Constraint PKEquipos Primary Key (ID)

)
GO

Create Table Partidos (

	ID Int NOT NULL Identity,
	ELocal Char(4) NOT NULL,
	EVisitante Char(4) NOT NULL,
	GolesLocal TinyInt NOT NULL Default 0,
	GolesVisitante TinyInt NOT NULL Default 0,
	Finalizado Bit NOT NULL Default 0,
	Fecha SmallDateTime NULL,

	Constraint PKPartidos Primary Key (ID),
	Constraint FKPartidoLocal Foreign Key (ELocal) REFERENCES Equipos (ID) ON DELETE NO ACTION ON UPDATE NO ACTION,
	Constraint FKPartidoVisitante Foreign Key (EVisitante) REFERENCES Equipos (ID) ON DELETE NO ACTION ON UPDATE NO ACTION

)
GO

CREATE Table Clasificaciones (
	Posicion TinyInt NOT NULL IDENTITY (1,1),
	IDEquipo Char(4) NOT NULL,
	NombreEquipo VarChar(20) NOT NULL,
	PartidosJugados TinyInt NOT NULL Default 0,
	PartidosGanados TinyInt NOT NULL Default 0,
	PartidosEmpatados TinyInt NOT NULL Default 0,
	PartidosPerdidos AS PartidosJugados - (PartidosGanados + PartidosEmpatados),
	Puntos AS PartidosGanados * 3 + PartidosEmpatados,
	GolesFavor SmallInt NOT NULL Default 0,
	GolesContra SmallInt NOT NULL Default 0,

	Constraint PKClasificacion Primary Key (Posicion),
	Constraint FKClasificacionEquipo Foreign Key (IDEquipo) REFERENCES Equipos (ID) ON DELETE NO ACTION ON UPDATE CASCADE

)
GO

Create Table Apuestas (
	ID Int NOT NULL Identity,
	DineroApostado SmallMoney NOT NULL,
	IDPartido Int NOT NULL,
	NickUsuario VarChar(20) NOT NULL,
	Comprobada Bit NOT NULL DEFAULT 0,

	Constraint PKApuestas Primary Key (ID),
	Constraint FKApuestaPartido Foreign Key (IDPartido) REFERENCES Partidos (ID) ON DELETE NO ACTION ON UPDATE CASCADE,
	Constraint FKApuestaUsuario Foreign Key (NickUsuario) REFERENCES Usuarios (Nick),
	Constraint DineroApostado Check (DineroApostado BETWEEN 0.5 AND 200)

)
GO

Create Table Handicaps (
	IDApuesta Int NOT NULL,
	Handicap TinyInt NOT NULL,

	Constraint PKHandicaps Primary Key (IDApuesta),
	Constraint FKApuestasHandicaps Foreign Key (IDApuesta) REFERENCES Apuestas (ID) ON DELETE CASCADE ON UPDATE CASCADE, 
	Constraint CKHandicap Check ((Handicap BETWEEN -3 AND 3) AND Handicap <> 0)

)
GO

Create Table OversUnders (
	IDApuesta Int NOT NULL,
	[Over/Under] bit NOT NULL,
	Numero Decimal(2,1) NOT NULL,

	Constraint PKOversUnders Primary Key (IDApuesta),
	Constraint FKApuestaOversUnders Foreign Key (IDApuesta) REFERENCES Apuestas (ID) ON DELETE CASCADE ON UPDATE CASCADE,
	Constraint CKNumero Check ((Numero BETWEEN 0 AND 6) AND (Numero % 0.5 = 0))

)
GO

Create Table GanadoresPartidos (
	IDApuesta Int NOT NULL,
	Resultado Char(1) NOT NULL,

	Constraint PKGanadoresPartidos Primary Key (IDApuesta),
	Constraint FKApuestasGanadoresPartidos Foreign Key (IDApuesta) REFERENCES Apuestas(ID) ON DELETE CASCADE ON UPDATE CASCADE,
	Constraint CKResultado CHECK (Resultado IN ('1', 'X', '2'))

)
GO

--Excepciones
EXECUTE sys.sp_addmessage @msgnum = 50001, @severity = 16, @msgtext = N'Cannot update a bet', @lang = 'us_english', @replace = 'replace';
EXECUTE sys.sp_addmessage @msgnum = 50001, @severity = 16, @msgtext = N'No se puede actualizar una apuesta', @lang = 'spanish', @replace = 'replace';

EXECUTE sys.sp_addmessage @msgnum = 50002, @severity = 16, @msgtext = N'Some match has already been finished', @lang = 'us_english', @replace = 'replace';
EXECUTE sys.sp_addmessage @msgnum = 50002, @severity = 16, @msgtext = N'Algun partido ya ha sido finalizado', @lang = 'spanish', @replace = 'replace';
GO
--Vistas Clasificacion
CREATE OR ALTER VIEW PartidosGanadosLocal AS
(
	SELECT ELocal AS ID, COUNT(Elocal) PartidosGanadosLocal FROM Partidos
	WHERE GolesLocal > GolesVisitante
	GROUP BY ELocal		
)
GO

CREATE OR ALTER VIEW PartidosGanadosVisitante AS
(
	SELECT EVisitante AS ID, COUNT(EVisitante) PartidosGanadosVisitante FROM Partidos
	WHERE GolesVisitante > GolesLocal
	GROUP BY EVisitante
)
GO

CREATE OR ALTER VIEW PartidosEmpatados AS
(
	SELECT E.ID, COUNT(*) AS PartidosEmpatados FROM Equipos AS E 
	INNER JOIN Partidos AS P ON (E.ID = P.ELocal OR E.ID = P.EVisitante) AND P.GolesLocal = P.GolesVisitante
	WHERE P.Finalizado = 1
	GROUP BY E.ID
)
GO

CREATE OR ALTER VIEW PartidosTotales AS
(
	SELECT E.ID, COUNT(*) AS PartidosTotales FROM Equipos AS E
	INNER JOIN Partidos AS P ON E.ID = P.ELocal OR E.ID = P.EVisitante
	WHERE P.Finalizado = 1
	GROUP BY E.ID
)
GO


CREATE OR ALTER VIEW GolesLocales AS
(
	SELECT ELocal AS ID, SUM(GolesLocal) AS GolesLocal FROM Partidos
	GROUP BY ELocal
)
GO

CREATE OR ALTER VIEW GolesVisitante AS
(
	SELECT EVisitante AS ID, SUM(GolesVisitante) AS GolesVisitante FROM Partidos
	GROUP BY EVisitante
)
GO

CREATE OR ALTER VIEW GolesEnContra AS
(
	SELECT E.ID, SUM(CASE WHEN P.ELocal <> E.ID THEN GolesLocal
									ELSE GolesVisitante
					 END) AS GolesEnContra FROM Equipos AS E 
	INNER JOIN Partidos AS P ON E.ID = P.ELocal OR E.ID = P.EVisitante
	GROUP BY E.ID
)
GO

--TRIGGERS
GO
CREATE OR ALTER TRIGGER ActualizarClasificacion ON Partidos AFTER INSERT,UPDATE
AS
	BEGIN
		
		SET NOCOUNT ON

		DELETE FROM Clasificaciones

		DBCC CHECKIDENT (Clasificaciones, RESEED,0)

		INSERT Clasificaciones
		SELECT E.ID, E.Nombre, ISNULL(PT.PartidosTotales,0), (ISNULL(PGL.PartidosGanadosLocal,0) + ISNULL(PGV.PartidosGanadosVisitante,0)) AS PartidosGanados, ISNULL(PE.PartidosEmpatados,0), (ISNULL(GL.GolesLocal,0) + ISNULL(GV.GolesVisitante,0)) AS GolesFavor, ISNULL(GE.GolesEnContra,0) FROM Equipos AS E 
		LEFT JOIN PartidosGanadosLocal AS PGL ON E.ID = PGL.ID
		FULL JOIN PartidosGanadosVisitante AS PGV ON E.ID = PGV.ID
		FULL JOIN PartidosEmpatados AS PE ON E.ID = PE.ID
		FULL JOIN PartidosTotales AS PT ON E.ID = PT.ID
		FULL JOIN GolesLocales AS GL ON E.ID = GL.ID
		FULL JOIN GolesVisitante AS GV ON E.ID = GV.ID
		FULL JOIN GolesEnContra AS GE ON E.ID = GE.ID
		ORDER BY (((PGL.PartidosGanadosLocal + PGV.PartidosGanadosVisitante) * 3) + PE.PartidosEmpatados) DESC, (GV.GolesVisitante + GL.GolesLocal - GE.GolesEnContra) DESC, (GV.GolesVisitante + GL.GolesLocal) DESC, PGV.PartidosGanadosVisitante DESC, GV.GolesVisitante DESC
	END
GO

CREATE OR ALTER TRIGGER PartidosFinalizados ON Partidos FOR UPDATE 
AS
	BEGIN
		IF EXISTS (SELECT * FROM deleted WHERE Finalizado = 1)
			BEGIN	
			DECLARE @MensajePartido NVarchar(255) = FormatMessage(50002);
			THROW 50002, @MensajePartido ,1
			ROLLBACK Transaction
			END
		ELSE
			BEGIN
				UPDATE Partidos
				SET Finalizado = 1
				WHERE ID IN
							(
								SELECT ID FROM inserted WHERE Finalizado = 0
							)
			END
	END
GO

CREATE OR ALTER TRIGGER GenerarClasificacion ON Equipos FOR INSERT
AS
	BEGIN
		INSERT Clasificaciones (IDEquipo, NombreEquipo)
		SELECT ID, Nombre FROM inserted
	END
GO

CREATE OR ALTER TRIGGER ActualizarApuesta ON Apuestas FOR UPDATE
AS
	BEGIN
		IF(update(DineroApostado))
			BEGIN
				DECLARE @MensajeApuesta NVarchar(255) = FormatMessage(50001);
				THROW 50001, @MensajeApuesta ,1
				ROLLBACK Transaction
			END
	END
GO

CREATE OR ALTER TRIGGER ActualizarHandicap ON Handicaps FOR UPDATE
AS
	BEGIN
		IF(update(Handicap))
			BEGIN
				DECLARE @MensajeApuesta NVarchar(255) = FormatMessage(50001);
				THROW 50001, @MensajeApuesta ,1
				ROLLBACK Transaction
			END
	END
GO

CREATE OR ALTER TRIGGER ActualizarOverUnder ON OversUnders FOR UPDATE
AS
	BEGIN
		IF(update([Over/Under]) OR update(Numero))
			BEGIN
				DECLARE @MensajeApuesta NVarchar(255) = FormatMessage(50001);
				THROW 50001, @MensajeApuesta ,1
				ROLLBACK Transaction
			END
	END
GO

CREATE OR ALTER TRIGGER ActualizarGanadorPartido ON GanadoresPartidos FOR UPDATE
AS
	BEGIN
		IF(update(Resultado))
			BEGIN
				DECLARE @MensajeApuesta NVarchar(255) = FormatMessage(50001);
				THROW 50001, @MensajeApuesta ,1
				ROLLBACK Transaction
			END
	END
GO

-- Poblamos la tabla equipos 
CREATE OR ALTER PROCEDURE PoblarEquipos
AS
	BEGIN
		INSERT INTO Equipos (ID,Nombre,Ciudad,Pais)
			VALUES ('RBET','Real Betis','Sevilla','España'),('LIVL','Liverpool FC','Liverpool','Reino Unido'),('GTFE','Getafe CF','Getafe','España'),
			('AJAX','Ajax','Amsterdam','Holanda'),('MANC','Manchester City','Manchester','Reino Unido'),('OPRT','FC Oporto','Oporto','Portugal'),
			('BODO','Borussia Dortmund','Dortmund','Alemania'),('BARC','FC Barcelona','Barcelona','España'),('PASG','Paris Saint Germain','Paris','Francia'),
			('ROMA','AS Roma','Roma','Italia'),('MANU','Manchester United','Manchester','Reino Unido'),('OLYL','Olympique de Lion','Lion','Francia'),
			('INTM','Inter','Milan','Italia'),('BENF','Benfica','Lisboa','Portugal'),('BAYM','Bayern','Munich','Alemania'),('JUVT','Juventus','Turin','Italia'),
			('CSKM','PFC CSKA Moscu','Moscú','Rusia'), ('RMAD','Real Madrid','Madrid','España')
	END
GO

EXECUTE PoblarEquipos
GO
-- Poblamos la tabla Partidos

CREATE OR ALTER PROCEDURE PoblarPartidos 
AS
	BEGIN
		Insert Into Partidos (ELocal ,EVisitante)
		SELECT L.ID, V.ID FROM Equipos AS L CROSS JOIN Equipos AS V Where L.ID <> V.ID
		
		DECLARE @GolesL TinyInt, @GolesV TinyInt, @Partido SmallInt
		DECLARE CPartidos CURSOR FOR Select ID From Partidos
		Open Cpartidos
		Fetch Next FROM Cpartidos INTO @Partido
		While @@FETCH_STATUS = 0
		Begin
			If @Partido % 15 <> 0
			Begin
				SET @GolesL = Floor(rand()*4)
				SET @GolesV = Floor(rand()*3)
				Update Partidos Set GolesLocal = @GolesL, GolesVisitante = @GolesV, Finalizado = 1
					Where Current Of Cpartidos
			End -- If
			Fetch Next FROM Cpartidos INTO @Partido
		End -- While
		Close Cpartidos
		Deallocate CPartidos
	END
GO

EXECUTE PoblarPartidos

-- Poblamos la tabla Usuarios
GO
CREATE OR ALTER PROCEDURE PoblarUsuarios
AS
	BEGIN
	
		SET dateformat mdy

		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Zamit', 'uoCW56L2x', 659.05, '6/24/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Jorgito', 'CpAQocprq', 521.37, '6/7/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Piñata', 'ZwkFM8HBnj', 450.51, '4/25/2017', '12/14/2018');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Elmendita', '0JzqSdpMf', 371.21, '3/20/2018', '8/22/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Greenlam', 'SXrmn0IRu', 932.86, '3/28/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Bitwolf', 'HEff4Kdsl', 12.34, '1/12/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Cardguard', 'dLp1e3aR7', 123.2, '4/18/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Fix San', 'lnEZk1vT', 128.49, '8/24/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Tempsoft', 'e66k8swZAyo', 532.15, '1/20/2017', '6/20/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Konklux', 'hd34aXMon', 979.87, '7/20/2016', '9/25/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Payaso', 'HX6ZcTBgv', 667.86, '2/22/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Regrant', 'axjfPmuQ', 591.36, '4/16/2017', '6/29/2018');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Job', 'qrr4cK3Iga', 24.89, '3/27/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Tajarta', 'e3ISDhhbQ', 405.00, '6/27/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Zoolab', 'Gywcd4t2P', 467.96, '10/6/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Lotlux', 'ZgkTw4Bg91', 937.27, '4/12/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Sub-Ex', 'bPXC6h7Te', 882.81, '3/18/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Voyatouch', 'wMvbTmFs', 75.77, '11/18/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Flexidy', 'JMLgg5LEz', 356.80, '7/4/2016', '4/19/2020');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Ventosanzap', 'u2TYUUgz', 282.32, '6/16/2016', '8/27/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Wrapsafe', '0wz4lD2W3GJ', 373.73, '5/15/2016', '5/14/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Cookley', 'bic0m74fH5o', 380.67, '10/6/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('BurgerKing001', 'klyFQwZtP', 425.12, '3/18/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Bitchip', 'xYp1kIP8W', 116.01, '10/10/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Tin', 'rbMHSd1M', 870.54, '9/21/2016', '7/26/2018');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Alejandrito', 'dD10o5Hv', 905.63, '7/21/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('El nadie', 'tYpC12frBh', 587.0, '3/13/2018', '5/10/2020');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Tresom', 'j814tnpcysA', 241.25, '9/24/2016', '6/15/2018');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Quo Lux', 'RLwLwgzQNA', 137.65, '12/8/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Treeflex', 'ipfde3cqY', 127.83, '8/7/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Rotita', 'VMdtCOtfStL', 398.03, '12/22/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Matsoft', 'OjWnjb7KI', 352.25, '10/20/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Juanuit1654', '3jgad4dK1', 10.13, '1/26/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Viva', 'oqfTtzl1FBg0', 337.44, '9/2/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Carraga', 'j3yaYwqChc1E', 429.48, '10/21/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('MellamoPepe', 'XG65deQVg', 352.33, '10/31/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Transcof', 'jwSim5C1', 898.78, '8/18/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Otcom', 'OpFt3ZhCj', 793.19, '5/20/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('TakiTaki', '3vSv7iMPK2', 908.34, '3/18/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Cardify', 'bLfHh4ql', 980.11, '4/10/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Elcocinitas', 'ik32vSxX1', 517.31, '12/3/2017', '6/22/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Domainer', 'sP6Syc1dTz3', 262.57, '10/31/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Hombrelobo', '2ELkrleXTX', 56.96, '2/27/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Mat Lam Tam', 'ZOFfe12fCq', 280.98, '2/8/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Home Ing', 'rMrbs3IAaJ6k', 108.00, '5/25/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Lotstring', 'YP0Dn4gI', 764.85, '11/21/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Caballero172', 'G6UBw4Ac', 178.45, '1/9/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Tucomunista69', '6RkfewvJh8', 504.02, '8/8/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Hatity', 'Zvzf45WPZ', 419.28, '4/25/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Zopa', 'fgvgCqCC', 232.99, '7/19/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Opela', 'biIYyVIEVSku', 505.01, '4/2/2017', '6/18/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Andalax', '9Yff4szOo', 513.47, '7/22/2017', '4/17/2020');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Gembucket', '5aqLWtsP', 730.56, '2/26/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Aleixking', 'X5eyd0kJOv', 181.73, '10/10/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Cersei', 'Wk0qvU123', 96.81, '12/15/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Zaam-Dox', 'Y2T0SYZkcD0', 56.19, '2/19/2018', '12/4/2018');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Fixflex', '1qjuTcb52D', 475.95, '1/28/2017', '1/4/2020');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Trippledex', 'yiJ2Bx1AQ', 895.57, '3/15/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Rank', '3PMEkWERTY', 321.85, '10/24/2017', '5/21/2018');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('AndaluzGaditano12', 'GcvM93ULEDSf', 58.57, '1/5/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Elninio', 'oBnLtG0ma', 991.54, '8/10/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Pepito', 'zzGUVv7LUC6u', 931.45, '10/12/2017', '7/27/2018');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Alphazap', 'nzMd1IuP1', 525.44, '12/21/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('AsunApruebame', 'xClZLsN6TMLb', 341.82, '9/17/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('CataluñaEsEspaña', 'iQRX3EA48', 838.33, '8/23/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Redhold', 'mRxyA6BbS8', 369.23, '3/4/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Ingeniero166', 'yjtWZ5UWmpY', 472.64, '7/21/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Gatita32', 'dUHLS24P0', 237.86, '2/23/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Flowdesk', 'B9I9ABS7nc', 221.24, '7/4/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Toughjoyfax', 'tMOtrjUQKqq', 678.99, '11/19/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Pacome', 'cifFEIM3Va', 455.34, '7/27/2017', '10/27/2018');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('AleBernal', 'mfrwNzxQG3K', 956.35, '9/19/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('TripleXXX', 'h4HyrnU073', 582.92, '8/14/2016', '5/29/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Y-find', 'w7X9qQPasa', 469.02, '3/13/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Trsorito', 'S2elwW6d', 33.01, '1/23/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Asoka', 'XlLa3Kt12d', 515.99, '10/20/2017', '5/1/2020');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('LeoApruebame', 'QgwhDURHOTS', 36.25, '3/3/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('PacoPepe', 'Q4V9myxaOGF', 501.15, '5/23/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Sonsing', 'hBi6gmFM0LQz', 84.11, '5/6/2017', '4/27/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Bigtax', 'vCyEH9OLF', 300.44, '1/31/2017', '10/28/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Zelote', 'ZJ2dgTeU', 819.88, '11/16/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Sonair', '6tTCs4GuiGSd', 628.49, '5/29/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Tinotobar', 'uFqwQMSQL', 488.28, '12/12/2016', '4/21/2020');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('RosarioApruebame', 'x8wZ8WVdNyH9', 810.57, '12/20/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('VivaEspaña', 'Ptg0Tb1db0', 327.30, '10/7/2016', '8/15/2018');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('MiPanita', 'ckdfdtoj', 597.02, '6/29/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('TuExnovia', 'qlYDZgI0', 642.24, '1/20/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Perdidos002', '3N507Quill0', 427.78, '8/28/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('XDestroyer2000', 'NHpZjDgkZp', 49.63, '3/2/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Emanenxd', 'ZQe1YP9nXRv', 694.04, '10/6/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Ronstring', 'e51jakVT66', 936.71, '3/25/2017', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Stim', 'Ta6MLmkFVs', 707.06, '5/31/2016', '12/10/2018');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Pocha', 'mlDpFeKas', 624.92, '9/8/2017', '9/29/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('VivaCaiz', 'ueT5Fc7y', 403.11, '5/17/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Temp', 'NiQ8e3mO6wrU', 841.09, '7/7/2017', '9/6/2019');
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Vegetta777', '1XdhTlim4', 167.21, '6/16/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('ManuJava', 'emC4Xkfe', 184.05, '7/19/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('RosaLaPoderosa', 'BdExNyQ3Ke', 794.93, '3/26/2018', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Willy', 'zMzBtmtgYHuI', 332.88, '10/17/2016', null);
		insert into Usuarios (Nick, Contraseña, Saldo, FechaAlta, FechaBaja) values ('Y-Solowarm', 'dJmo1wPW01J', 208.15, '8/11/2016', null);


	END
GO
-- Poblamos la tabla Apuestas
--GO
--CREATE OR ALTER PROCEDURE PoblarApuestas
--AS
--	BEGIN
--		SELECT TOP 1 *, Floor(rand()*199) + 1 AS DineroApostado FROM Partidos
--		ORDER BY NEWID()
--		SELECT TOP 1 * FROM Usuarios
--		ORDER BY NEWID()

		

--		SELECT * FROM Partidos

--		SELECT * FROM Apuestas

--		SET DATEFORMAT mdy

--		Insert Into Apuestas (DineroApostado , IDPartido, NickUsuario)
--		SELECT L.ID, V.ID FROM Equipos AS L CROSS JOIN Equipos AS V Where L.ID <> V.ID
		

--	END
--GO

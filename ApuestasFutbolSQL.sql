CREATE DATABASE ApuestasFutbolSQL
--DROP DATABASE ApuestasFutbolSQL
GO
Use ApuestasFutbolSQL
GO


SET NOCOUNT ON
GO

Create Table Usuarios (

	Nick Varchar(20) NOT NULL,
	Contraseña Varchar(32) NOT NULL,

	Constraint PKUsuarios Primary Key (Nick),
	Constraint CKNick Check (DATALENGTH(Nick) >= 3),
	Constraint CKContraseña Check (DATALENGTH(Contraseña) >= 7 AND Contraseña LIKE '%[A-z]%' AND Contraseña LIKE '%[0-9]%')
)
GO

Create Table UsuariosApostadores (

	Nick Varchar(20) NOT NULL,
	Saldo Smallmoney NOT NULL Default 0,
	FechaAlta Date NULL Default GETDATE(),
	FechaBaja Date NULL,

	Constraint PKUsuariosApostadores Primary Key (Nick),
	Constraint FKUsuarioUsuarioApostador Foreign Key (Nick) REFERENCES Usuarios (Nick) ON DELETE CASCADE ON UPDATE CASCADE,
	Constraint CKSaldo Check (Saldo >= 0),
	Constraint CKFechaAlta Check (FechaAlta <= FechaBaja),
	Constraint CKFechaBaja Check (FechaBaja < GETDATE())
)
GO

Create Table Equipos (

	ID Char(4) NOT NULL,
	Nombre VarChar(20) NOT NULL,
	Ciudad VarChar(25) NULL,
	Pais VarChar (20) NULL,

	Constraint PKEquipos Primary Key (ID),
	Constraint CKID Check (ID LIKE '[A-Z][A-Z][A-Z][A-Z]')
)
GO

Create Table Partidos (

	ID Int NOT NULL Identity,
	ELocal Char(4) NOT NULL,
	EVisitante Char(4) NOT NULL,
	GolesLocal TinyInt NOT NULL Default 0,
	GolesVisitante TinyInt NOT NULL Default 0,
	CuotaLocal Float NOT NULL DEFAULT 40,
	CuotaEmpate Float NOT NULL DEFAULT 20,
	CuotaVisitante Float NOT NULL DEFAULT 40,
	Finalizado Bit NOT NULL Default 0,
	Fecha DATE NULL,
	IDPartidoSustituido Int NULL,

	Constraint PKPartidos Primary Key (ID),
	Constraint FKPartidoLocal Foreign Key (ELocal) REFERENCES Equipos (ID) ON DELETE NO ACTION ON UPDATE NO ACTION,
	Constraint FKPartidoVisitante Foreign Key (EVisitante) REFERENCES Equipos (ID) ON DELETE NO ACTION ON UPDATE NO ACTION,
	Constraint CKGolesLocal Check(GolesLocal >= 0),
	Constraint CKGolesVisitante Check(GolesVisitante >= 0),
	Constraint CKCuotaLocal CHECK (CuotaLocal BETWEEN 5 AND 90),
	Constraint CKCuotaEmpate CHECK (CuotaEmpate BETWEEN 5 AND 90),
	Constraint CKCuotaVisitante CHECK (CuotaVisitante BETWEEN 5 AND 90),
	Constraint CKCuotas CHECK (CuotaLocal + CuotaEmpate + CuotaVisitante = 100),
	Constraint FKPartidoSustituidoPartido Foreign Key (IDPartidoSustituido) REFERENCES Partidos (ID) ON DELETE NO ACTION ON UPDATE NO ACTION
)
GO

CREATE Table ClasificacionesEspecificas (
	Posicion TinyInt NOT NULL IDENTITY (1,1),
	IDEquipo Char(4) NOT NULL,
	NombreEquipo VarChar(20) NOT NULL,
	PartidosJugados AS (PartidosGanados + PartidosEmpatados + PartidosPerdidos),
	PartidosGanados TinyInt NOT NULL Default 0,
	PartidosEmpatados TinyInt NOT NULL Default 0,
	PartidosPerdidos TinyInt NOT NULL Default 0,
	GolesFavor SmallInt NOT NULL Default 0,
	GolesContra SmallInt NOT NULL Default 0,
	DiferenciaGoles AS GolesFavor - GolesContra,
	Puntos AS PartidosGanados * 3 + PartidosEmpatados,
	[Local/Visitante] Bit NOT NULL DEFAULT 0,

	Constraint PKClasificacionesEspecificas Primary Key (IDEquipo,[Local/Visitante]),
	Constraint CKPartidosGanadosE Check(PartidosGanados >= 0),
	Constraint CKPartidosEmpatadosE Check(PartidosEmpatados >= 0),
	Constraint CKPartidosPerdidosE Check(PartidosPerdidos >= 0),
	Constraint CKGolesFavorE Check(GolesFavor >= 0),
	Constraint CKGolesContraE Check(GolesContra >= 0),
	Constraint FKClasificacionEspecificaEquipo Foreign Key (IDEquipo) REFERENCES Equipos (ID) ON DELETE CASCADE ON UPDATE CASCADE
)
GO

Create Table Apuestas (
	ID Int NOT NULL Identity,
	DineroApostado SmallMoney NOT NULL,
	IDPartido Int NOT NULL,
	NickUsuario VarChar(20) NOT NULL,
	Resultado Char(1) NOT NULL,
	Comprobada Bit NOT NULL Default 0,

	Constraint PKApuestas Primary Key (ID),
	Constraint FKApuestaPartido Foreign Key (IDPartido) REFERENCES Partidos (ID) ON DELETE NO ACTION ON UPDATE CASCADE,
	Constraint FKApuestaUsuarioApostador Foreign Key (NickUsuario) REFERENCES UsuariosApostadores (Nick),
	Constraint DineroApostado Check (DineroApostado >= 1),
	Constraint CKResultado CHECK (Resultado IN ('1', 'X', '2')),
	Constraint UQUsuarioPartido UNIQUE (NickUsuario, IDPartido)
)
GO


CREATE OR ALTER TRIGGER GenerarClasificacion ON Equipos FOR INSERT
AS
	BEGIN
		INSERT ClasificacionesEspecificas(IDEquipo, NombreEquipo, [Local/Visitante])
		SELECT ID, Nombre, 0 FROM inserted

		INSERT ClasificacionesEspecificas(IDEquipo, NombreEquipo, [Local/Visitante])
		SELECT ID, Nombre, 1 FROM inserted
	END
GO

GO
CREATE OR ALTER TRIGGER ActualizarClasificacion ON Partidos AFTER INSERT,UPDATE
AS
	BEGIN

		SET NOCOUNT ON

		DECLARE @ClasificacionAux TABLE
		(
			IDEquipo Char(4),
			NombreEquipo VarChar(20),
			PartidosGanados TinyInt,
			PartidosEmpatados TinyInt,
			PartidosPerdidos TinyInt,
			GolesFavor SmallInt,
			GolesContra SmallInt,
			[Local/Visitante] Bit
		)

		DECLARE @Cont TinyInt = 0

		INSERT @ClasificacionAux
		SELECT CE.IDEquipo,
		CE.NombreEquipo,
		(CE.PartidosGanados + ISNULL(PG.PartidosGanados, 0)) AS PartidosGanados,
		(CE.PartidosEmpatados + ISNULL(PE.PartidosEmpatados, 0)) AS PartidosEmpatados,
		(CE.PartidosPerdidos + ISNULL(PP.PartidosPerdidos, 0)) AS PartidosPerdidos,
		(CE.GolesFavor + ISNULL(GF.GolesFavor, 0)) AS GolesFavor,
		(CE.GolesContra + ISNULL(GC.GolesContra, 0)) AS GolesContra,
		CE.[Local/Visitante]
		FROM ClasificacionesEspecificas AS CE
		LEFT JOIN 
		(
			SELECT CE.IDEquipo, COUNT(*) AS PartidosGanados, CE.[Local/Visitante] FROM ClasificacionesEspecificas AS CE
			INNER JOIN inserted AS I ON (CE.IDEquipo = I.ELocal AND CE.[Local/Visitante] = 1) OR (CE.IDEquipo = I.EVisitante AND CE.[Local/Visitante] = 0)
			WHERE (I.GolesLocal > I.GolesVisitante AND CE.[Local/Visitante] = 1) OR (I.GolesVisitante > I.GolesLocal AND CE.[Local/Visitante] = 0)
			GROUP BY CE.IDEquipo, CE.[Local/Visitante]
			--ORDER BY CE.IDEquipo
		) AS PG ON CE.IDEquipo = PG.IDEquipo AND CE.[Local/Visitante] = PG.[Local/Visitante]
		FULL JOIN
		(
			SELECT CE.IDEquipo, COUNT(*) AS PartidosEmpatados, CE.[Local/Visitante] FROM ClasificacionesEspecificas AS CE
			INNER JOIN inserted AS I ON (CE.IDEquipo = I.ELocal AND CE.[Local/Visitante] = 1) OR (CE.IDEquipo = I.EVisitante AND CE.[Local/Visitante] = 0)
			WHERE ((I.GolesLocal = I.GolesVisitante AND CE.[Local/Visitante] = 1) OR (I.GolesVisitante = I.GolesLocal AND CE.[Local/Visitante] = 0)) AND I.Finalizado = 1
			GROUP BY CE.IDEquipo, CE.[Local/Visitante]
			--ORDER BY CE.IDEquipo
		) AS PE ON CE.IDEquipo = PE.IDEquipo AND CE.[Local/Visitante] = PE.[Local/Visitante]
		FULL JOIN
		(
			SELECT CE.IDEquipo, COUNT(*) AS PartidosPerdidos, CE.[Local/Visitante] FROM ClasificacionesEspecificas AS CE
			INNER JOIN inserted AS I ON (CE.IDEquipo = I.ELocal AND CE.[Local/Visitante] = 1) OR (CE.IDEquipo = I.EVisitante AND CE.[Local/Visitante] = 0)
			WHERE (I.GolesLocal < I.GolesVisitante AND CE.[Local/Visitante] = 1) OR (I.GolesVisitante < I.GolesLocal AND CE.[Local/Visitante] = 0)
			GROUP BY CE.IDEquipo, CE.[Local/Visitante]
			--ORDER BY CE.IDEquipo
		) AS PP ON CE.IDEquipo = PP.IDEquipo AND CE.[Local/Visitante] = PP.[Local/Visitante]
		FULL JOIN 
		(
			SELECT CE.IDEquipo, SUM(CASE
								WHEN I.ELocal = CE.IDEquipo THEN GolesLocal
								WHEN I.EVisitante = CE.IDEquipo THEN GolesVisitante
								END)
								AS GolesFavor, CE.[Local/Visitante] FROM ClasificacionesEspecificas AS CE
			INNER JOIN inserted AS I ON (CE.IDEquipo = I.ELocal AND CE.[Local/Visitante] = 1) OR (CE.IDEquipo = I.EVisitante AND CE.[Local/Visitante] = 0)
			GROUP BY CE.IDEquipo, CE.[Local/Visitante]
			--ORDER BY CE.IDEquipo
		) AS GF ON CE.IDEquipo = GF.IDEquipo AND CE.[Local/Visitante] = GF.[Local/Visitante]
		FULL JOIN
		(
			SELECT CE.IDEquipo, SUM(CASE
								WHEN I.ELocal = CE.IDEquipo THEN GolesVisitante
								WHEN I.EVisitante = CE.IDEquipo THEN GolesLocal
								END)
								AS GolesContra, CE.[Local/Visitante] FROM ClasificacionesEspecificas AS CE
			INNER JOIN inserted AS I ON (CE.IDEquipo = I.ELocal AND CE.[Local/Visitante] = 1) OR (CE.IDEquipo = I.EVisitante AND CE.[Local/Visitante] = 0)
			GROUP BY CE.IDEquipo, CE.[Local/Visitante]
			--ORDER BY CE.IDEquipo
		) AS GC ON CE.IDEquipo = GC.IDEquipo AND CE.[Local/Visitante] = GC.[Local/Visitante]

		DELETE FROM ClasificacionesEspecificas

		WHILE @Cont <= 1
			BEGIN
				DBCC CHECKIDENT (ClasificacionesEspecificas, RESEED,0)

				INSERT ClasificacionesEspecificas (IDEquipo, NombreEquipo, PartidosGanados, PartidosEmpatados, PartidosPerdidos, GolesFavor, GolesContra, [Local/Visitante])
				SELECT IDEquipo, NombreEquipo, PartidosGanados, PartidosEmpatados, PartidosPerdidos, GolesFavor, GolesContra, @Cont FROM @ClasificacionAux
				WHERE [Local/Visitante] = @Cont
				ORDER BY ((PartidosGanados * 3) + PartidosEmpatados) DESC, (GolesFavor - GolesContra) DESC, PartidosGanados DESC, GolesFavor DESC

				SET @Cont += 1
			END
	END
GO

CREATE OR ALTER VIEW Clasificacion AS
(
SELECT Local.IDEquipo, 
	   Local.NombreEquipo, 
	   (Local.PartidosJugados + Visitante.PartidosJugados) AS PartidosJugados, 
	   (Local.PartidosGanados + Visitante.PartidosGanados) AS PartidosGanados,
	   (Local.PartidosEmpatados + Visitante.PartidosEmpatados) AS PartidosEmpatados,
	   (Local.PartidosPerdidos + Visitante.PartidosPerdidos) AS PartidosPerdidos,
	   (Local.GolesFavor + Visitante.GolesFavor) AS GolesFavor,
	   (Local.GolesContra + Visitante.GolesContra) AS GolesContra,
	   (Local.DiferenciaGoles + Visitante.DiferenciaGoles) AS DiferenciaGoles,
	   (Local.Puntos + Visitante.Puntos) AS Puntos,
	   Visitante.PartidosGanados AS PartidosGanadosVisitante,
	   Visitante.GolesFavor AS GolesFavorVisitante FROM 
(
	SELECT * FROM ClasificacionesEspecificas
	WHERE [Local/Visitante] = 1
) AS Local
INNER JOIN
(
	SELECT * FROM ClasificacionesEspecificas
	WHERE [Local/Visitante] = 0
) AS Visitante ON Local.IDEquipo = Visitante.IDEquipo
--ORDER BY (Local.Puntos + Visitante.Puntos) DESC, (Local.DiferenciaGoles + Visitante.DiferenciaGoles) DESC, (Local.GolesFavor + Visitante.GolesFavor) DESC, Visitante.PartidosGanados DESC, Visitante.GolesFavor DESC
)
GO




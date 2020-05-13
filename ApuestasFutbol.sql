
Create Database ApuestasFutbol
GO
Use ApuestasFutbol
GO

Create Table Usuarios (

	Nick Varchar(20) NOT NULL,
	Contrase�a Varchar(32) NOT NULL,
	Saldo Smallmoney NOT NULL Default 0,
	FechaAlta Date NULL,
	FechaBaja Date NULL,

	Constraint PKUsuarios Primary Key (Nick),
	Constraint CKNick Check (DATALENGTH(Nick) > 3),
	Constraint CKContrase�a Check (DATALENGTH(Contrase�a) > 7),
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

CREATE OR ALTER TRIGGER PartidosFinalizados ON Partidos FOR UPDATE 
AS
	BEGIN
		IF EXISTS (SELECT * FROM deleted WHERE Finalizado = 1)
			BEGIN	
			RAISERROR('Alg�n partido ya ha sido finalizado.',10,1)
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

-- Equipos participantes 
INSERT INTO Equipos (ID,Nombre,Ciudad,Pais)
     VALUES ('RBET','Real Betis','Sevilla','Espa�a'),('LIVL','Liverpool FC','Liverpool','Reino Unido'),('ESRO','Estrella Roja','Belgrado','Serbia'),
	 ('AJAX','Ajax','Amsterdam','Holanda'),('MANC','Manchester City','Manchester','Reino Unido'),('ARAR','Ararat','Erevan','Armenia'),
	 ('BODO','Borussia Dortmund','Dortmund','Alemania'),('BARC','FC Barcelona','Barcelona','Espa�a'),('PASG','Paris Saint Germain','Paris','Francia'),
	 ('OLYM','Olympiacos','Atenas','Grecia'),('MANU','Manchester United','Manchester','Reino Unido'),('OLYL','Olympique de Lion','Lion','Francia'),
	 ('INTM','Inter','Milan','Italia'),('BENF','Benfica','Lisboa','Portugal'),('BAYM','Bayern','Munich','Alemania'),('JUVT','Juventus','Turin','Italia'),
	 ('ZENR','Zenit','San Petesburgo','Rusia'), ('RMAD','Real Madrid','Madrid','Espa�a')
GO

-- Poblamos la tabla Partidos

Insert Into Partidos (ELocal ,EVisitante)
SELECT L.ID, V.ID FROM Equipos AS L CROSS JOIN Equipos AS V Where L.ID <> V.ID
GO
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

-- Mucho Betis!
-- El factor Villamarin
Update Partidos Set GolesLocal = GolesLocal + 1
	Where ELocal ='RBET'

Select * From Partidos

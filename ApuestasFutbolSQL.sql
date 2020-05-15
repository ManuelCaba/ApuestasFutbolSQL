
Create Database ApuestasFutbolSQL
GO
Use ApuestasFutbolSQL
GO


SET NOCOUNT ON
GO

Create Table Usuarios (

	Nick Varchar(20) NOT NULL,
	Contraseña Varchar(32) NOT NULL,

	Constraint PKUsuarios Primary Key (Nick),
	Constraint CKNick Check (DATALENGTH(Nick) > 3),
	Constraint CKContraseña Check (DATALENGTH(Contraseña) >= 7)
)
GO

Create Table UsuariosApostadores (

	Nick Varchar(20) NOT NULL,
	Saldo Smallmoney NOT NULL Default 0,
	FechaAlta Date NULL,
	FechaBaja Date NULL,

	Constraint PKUsuariosApostadores Primary Key (Nick),
	Constraint FKUsuarioUsuarioApostador Foreign Key (Nick) REFERENCES Usuarios (Nick) ON DELETE CASCADE ON UPDATE CASCADE,
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
	CuotaLocal SmallInt NOT NULL DEFAULT 40,
	CuotaEmpate SmallInt NOT NULL DEFAULT 20,
	CuotaVisitante SmallInt NOT NULL DEFAULT 40,
	Finalizado Bit NOT NULL Default 0,
	Fecha SmallDateTime NULL,
	IDPartidoSustituido Int NULL,

	Constraint PKPartidos Primary Key (ID),
	Constraint FKPartidoLocal Foreign Key (ELocal) REFERENCES Equipos (ID) ON DELETE NO ACTION ON UPDATE NO ACTION,
	Constraint FKPartidoVisitante Foreign Key (EVisitante) REFERENCES Equipos (ID) ON DELETE NO ACTION ON UPDATE NO ACTION,
	Constraint CKCuotas CHECK (CuotaLocal + CuotaEmpate + CuotaVisitante = 100),
	Constraint FKPartidoSustituidoPartido Foreign Key (IDPartidoSustituido) REFERENCES Partidos (ID) ON DELETE NO ACTION ON UPDATE NO ACTION
)
GO

CREATE Table ClasificacionesGenerales (
	Posicion TinyInt NOT NULL IDENTITY (1,1),
	IDEquipo Char(4) NOT NULL,
	NombreEquipo VarChar(20) NOT NULL,
	PartidosJugados AS (PartidosGanados + PartidosEmpatados + PartidosPerdidos),
	PartidosGanados TinyInt NOT NULL Default 0,
	PartidosEmpatados TinyInt NOT NULL Default 0,
	PartidosPerdidos TinyInt NOT NULL Default 0,
	GolesFavor SmallInt NOT NULL Default 0,
	GolesContra SmallInt NOT NULL Default 0,
	Puntos AS PartidosGanados * 3 + PartidosEmpatados,

	Constraint PKClasificacionesGenerales Primary Key (IDEquipo),
	Constraint FKEquipoClasificacion Foreign Key (IDEquipo) REFERENCES Equipos (ID) ON DELETE CASCADE ON UPDATE CASCADE
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
	Puntos AS PartidosGanados * 3 + PartidosEmpatados,
	[Local/Visitante] Bit NOT NULL DEFAULT 0,

	Constraint PKClasificacionesEspecificas Primary Key (IDEquipo,[Local/Visitante]),
	Constraint FKClasificacionEspecificaGeneral Foreign Key (IDEquipo) REFERENCES ClasificacionesGenerales (IDEquipo) ON DELETE CASCADE ON UPDATE CASCADE
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
	Constraint DineroApostado Check (DineroApostado BETWEEN 0.5 AND 200),
	Constraint CKResultado CHECK (Resultado IN ('1', 'X', '2'))
)
GO

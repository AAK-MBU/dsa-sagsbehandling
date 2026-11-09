USE [DSA]
GO
/****** Object:  Table [dsa].[Adresse]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Adresse](
	[adresse_id] [nvarchar](36) NOT NULL,
	[adresse_tekst] [nvarchar](500) NULL,
	[latitude] [float] NULL,
	[longitude] [float] NULL,
 CONSTRAINT [PK_Adresse] PRIMARY KEY CLUSTERED 
(
	[adresse_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Aendringsaarsag]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Aendringsaarsag](
	[aendringsaarsag_id] [int] IDENTITY(1,1) NOT NULL,
	[aendringsaarsag_tekst] [nvarchar](255) NOT NULL,
	[beskrivelse] [nvarchar](1000) NULL,
	[aktiv] [bit] NOT NULL,
	[sortering] [int] NULL,
 CONSTRAINT [PK_Aendringsaarsag] PRIMARY KEY CLUSTERED 
(
	[aendringsaarsag_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UQ_Aendringsaarsag_tekst] UNIQUE NONCLUSTERED 
(
	[aendringsaarsag_tekst] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Brevskabelon]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Brevskabelon](
	[brevskabelon_id] [int] IDENTITY(1,1) NOT NULL,
	[brevskabelon_tekst] [nvarchar](255) NOT NULL,
	[beskrivelse] [nvarchar](1000) NULL,
	[aktiv] [bit] NOT NULL,
	[fagomraade_id] [int] NULL,
	[sortering] [int] NULL,
 CONSTRAINT [PK_Brevskabelon] PRIMARY KEY CLUSTERED 
(
	[brevskabelon_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UQ_Brevskabelon_tekst_fagomraade] UNIQUE NONCLUSTERED 
(
	[brevskabelon_tekst] ASC,
	[fagomraade_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Elev]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Elev](
	[cpr] [varchar](10) NOT NULL,
	[adresseringsnavn] [nvarchar](200) NULL,
	[navne_adresse_beskyttelse] [bit] NULL,
	[adresse_id] [nvarchar](36) NULL,
	[koen] [nvarchar](20) NULL,
	[modersmaal] [nvarchar](100) NULL,
	[distriktsskolekode] [int] NULL,
	[skolekode] [int] NULL,
	[elevklassetrin] [nvarchar](20) NULL,
	[klassebetegnelse] [nvarchar](50) NULL,
	[sprogstoettebehov] [bit] NULL,
	[ppr_status] [bit] NULL,
	[tilflyttet_dk_dato] [date] NULL,
	[opdateret_tidspunkt] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_Elev] PRIMARY KEY CLUSTERED 
(
	[cpr] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Elev_Indrejse]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Elev_Indrejse](
	[cpr] [varchar](10) NOT NULL,
	[foerste_indrejse] [date] NOT NULL,
	[seneste_indrejse] [date] NOT NULL,
 CONSTRAINT [PK_Elev_Indrejse] PRIMARY KEY CLUSTERED 
(
	[cpr] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Elev_Modersmaal]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Elev_Modersmaal](
	[cpr] [varchar](10) NOT NULL,
	[modersmaal] [nvarchar](50) NULL,
	[gyldig_fra] [date] NOT NULL,
	[gyldig_til] [date] NOT NULL,
 CONSTRAINT [PK_Elev_Modersmaal] PRIMARY KEY CLUSTERED 
(
	[cpr] ASC,
	[gyldig_fra] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Elev_PPR]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Elev_PPR](
	[cpr] [varchar](10) NOT NULL,
	[startdato] [date] NOT NULL,
	[slutdato] [date] NOT NULL,
 CONSTRAINT [PK_Elev_PPR] PRIMARY KEY CLUSTERED 
(
	[cpr] ASC,
	[startdato] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Elev_STG]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Elev_STG](
	[cpr] [varchar](10) NULL,
	[adresseringsnavn] [nvarchar](200) NULL,
	[navne_adresse_beskyttelse] [bit] NULL,
	[adresse_id] [nvarchar](36) NULL,
	[koen] [nvarchar](20) NULL,
	[distriktsskolekode] [int] NULL,
	[opdateret_tidspunkt] [datetime2](7) NULL,
	[skoledistrikt] [nvarchar](100) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Fagomraade]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Fagomraade](
	[fagomraade_id] [int] IDENTITY(1,1) NOT NULL,
	[fagomraade_tekst] [nvarchar](255) NOT NULL,
	[beskrivelse] [nvarchar](1000) NULL,
	[aktiv] [bit] NOT NULL,
	[sortering] [int] NULL,
 CONSTRAINT [PK_Fagomraade] PRIMARY KEY CLUSTERED 
(
	[fagomraade_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UQ_Fagomraade_tekst] UNIQUE NONCLUSTERED 
(
	[fagomraade_tekst] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Foraelder]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Foraelder](
	[cpr_foraelder] [varchar](10) NOT NULL,
	[cpr_elev] [varchar](10) NOT NULL,
	[adresseringsnavn] [nvarchar](200) NULL,
	[navne_adresse_beskyttelse] [bit] NULL,
	[maa_vide_barns_adresse] [bit] NULL,
	[adresse_id] [nvarchar](36) NULL,
	[relation] [nvarchar](50) NULL,
 CONSTRAINT [PK_Foraelder] PRIMARY KEY CLUSTERED 
(
	[cpr_foraelder] ASC,
	[cpr_elev] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Foraelder_STG]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Foraelder_STG](
	[cpr_foraelder] [varchar](10) NULL,
	[cpr_elev] [varchar](10) NULL,
	[adresseringsnavn] [nvarchar](200) NULL,
	[navne_adresse_beskyttelse] [bit] NULL,
	[maa_vide_barns_adresse] [bit] NULL,
	[adresse_id] [nvarchar](36) NULL,
	[relation] [nvarchar](50) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[PortalAuditLog]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[PortalAuditLog](
	[AuditLogId] [int] IDENTITY(1,1) NOT NULL,
	[BrugerIdent] [nvarchar](200) NULL,
	[IpAdresse] [nvarchar](50) NULL,
	[UserAgent] [nvarchar](500) NULL,
	[OprettetDato] [datetime2](7) NOT NULL,
	[Method] [nvarchar](10) NULL,
	[Path] [nvarchar](500) NULL,
	[QueryParams] [nvarchar](max) NULL,
	[StatusCode] [int] NULL,
	[DurationMs] [decimal](10, 2) NULL,
	[ErrorMessage] [nvarchar](max) NULL,
	[ApiKeyId] [int] NULL,
	[ApiKeyName] [nvarchar](200) NULL,
	[Action] [nvarchar](200) NULL,
 CONSTRAINT [PK_PortalAuditLog] PRIMARY KEY CLUSTERED 
(
	[AuditLogId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Sagsaktivitet]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Sagsaktivitet](
	[aktivitet_id] [int] IDENTITY(1,1) NOT NULL,
	[cpr] [varchar](10) NOT NULL,
	[aktivitetstype] [nvarchar](50) NOT NULL,
	[kommentar] [nvarchar](max) NULL,
	[udfoert_af] [nvarchar](100) NULL,
	[oprettet_tidspunkt] [datetime2](7) NOT NULL,
	[fagomraade_id] [int] NULL,
	[relateret_sag_id] [int] NULL,
	[aktivitetstype_id] [int] NULL,
 CONSTRAINT [PK_Sagsaktivitet] PRIMARY KEY CLUSTERED 
(
	[aktivitet_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dsa].[SagsaktivitetType]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[SagsaktivitetType](
	[type_id] [int] IDENTITY(1,1) NOT NULL,
	[type_kode] [nvarchar](100) NOT NULL,
 CONSTRAINT [PK_SagsaktivitetType] PRIMARY KEY CLUSTERED 
(
	[type_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UQ_SagsaktivitetType_kode] UNIQUE NONCLUSTERED 
(
	[type_kode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Skolebegynder]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Skolebegynder](
	[skolebegynder_id] [int] IDENTITY(1,1) NOT NULL,
	[cpr] [varchar](10) NOT NULL,
	[skoleaar] [int] NOT NULL,
	[status_id] [int] NOT NULL,
	[status_dato] [date] NULL,
	[modtaget_tidspunkt] [datetime2](7) NOT NULL,
	[screeningsdato] [date] NULL,
	[testtype] [nvarchar](100) NULL,
	[navn_konsulent] [nvarchar](200) NULL,
	[alder_mdr] [int] NULL,
	[gennemfoert] [bit] NULL,
	[afbrudt] [bit] NULL,
	[screening_noter] [nvarchar](max) NULL,
	[of_percentil] [decimal](4, 1) NULL,
	[of_besvaret] [int] NULL,
	[of_ubesvaret] [int] NULL,
	[of_korrekt] [int] NULL,
	[of_forkert] [int] NULL,
	[of_korrekt_ratio] [float] NULL,
	[of_score] [int] NULL,
	[of_score_alt] [nvarchar](50) NULL,
	[sf_percentil] [decimal](4, 1) NULL,
	[sf_besvaret] [int] NULL,
	[sf_ubesvaret] [int] NULL,
	[sf_korrekt] [int] NULL,
	[sf_forkert] [int] NULL,
	[sf_korrekt_ratio] [float] NULL,
	[sf_korrekt_ratio_ori] [float] NULL,
	[sf_score] [int] NULL,
	[sf_score_alt] [nvarchar](50) NULL,
	[samlet_resultat] [nvarchar](100) NULL,
	[puf_screeningsresultat] [nvarchar](100) NULL,
	[sprogstoettebehov] [bit] NULL,
	[dagtilbud] [nvarchar](200) NULL,
	[dagtilbud_afdeling] [nvarchar](200) NULL,
	[dagtilbud_afdeling_adresse] [nvarchar](500) NULL,
	[email_pl] [nvarchar](255) NULL,
	[email_distriktsskole] [nvarchar](255) NULL,
	[oensket_skolekode] [int] NULL,
	[soeskende_skolekode] [int] NULL,
	[ansoeger_anden_skole] [bit] NULL,
	[skoletilbud_matrikel_id] [int] NULL,
	[skoletilbudstype_id] [int] NULL,
	[skoleplaceringsaarsag_id] [int] NULL,
	[brevskabelon_id] [int] NULL,
	[krav_paa_befordring] [bit] NULL,
	[gaaafstand_distriktsskole_km] [float] NULL,
	[gaaafstand_oensket_skole_km] [float] NULL,
	[gaaafstand_skoletilbud_km] [float] NULL,
	[bemaerkning] [nvarchar](max) NULL,
	[sagsbehandlingsdato] [date] NULL,
	[journalfil_dannet] [date] NULL,
	[graffil_dannet] [date] NULL,
	[afsluttet_dato] [date] NULL,
	[created_at] [datetime2](7) NOT NULL,
	[created_by] [nvarchar](100) NOT NULL,
	[updated_at] [datetime2](7) NOT NULL,
	[updated_by] [nvarchar](100) NOT NULL,
	[aktiv] [bit] NOT NULL,
	[screening_booket_tidspunkt] [datetime2](0) NULL,
	[oensket_skolekode_2] [int] NULL,
	[afklaring] [nvarchar](max) NULL,
 CONSTRAINT [PK_Skolebegynder] PRIMARY KEY CLUSTERED 
(
	[skolebegynder_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UQ_Skolebegynder_cpr_skoleaar] UNIQUE NONCLUSTERED 
(
	[cpr] ASC,
	[skoleaar] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Skolebegynder_Aendring]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Skolebegynder_Aendring](
	[aendring_id] [int] IDENTITY(1,1) NOT NULL,
	[skolebegynder_id] [int] NOT NULL,
	[aendringsaarsag_id] [int] NOT NULL,
	[beskrivelse] [nvarchar](1000) NULL,
	[registreret_tidspunkt] [datetime2](7) NOT NULL,
	[haandteret] [bit] NOT NULL,
	[haandteret_af] [nvarchar](100) NULL,
	[haandteret_tidspunkt] [datetime2](7) NULL,
 CONSTRAINT [PK_Skolebegynder_Aendring] PRIMARY KEY CLUSTERED 
(
	[aendring_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[SkoleHistorik]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[SkoleHistorik](
	[skolehistorik_id] [int] IDENTITY(1,1) NOT NULL,
	[cpr] [varchar](10) NOT NULL,
	[skolekode] [int] NULL,
	[elevklassetrin] [nvarchar](20) NULL,
	[klassebetegnelse] [nvarchar](50) NULL,
	[sprogstoettebehov] [bit] NULL,
	[gyldig_fra] [date] NOT NULL,
	[gyldig_til] [date] NULL,
	[kilde] [nvarchar](50) NULL,
	[oprettet_tidspunkt] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_SkoleHistorik] PRIMARY KEY CLUSTERED 
(
	[skolehistorik_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Skolematrikel]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Skolematrikel](
	[matrikel_id] [int] IDENTITY(1,1) NOT NULL,
	[matrikel_navn] [varchar](max) NOT NULL,
	[matrikel_adresse] [varchar](max) NOT NULL,
	[skolekode] [int] NOT NULL,
	[er_matrikel_hovedadresse] [bit] NOT NULL,
	[latitude] [float] NULL,
	[longitude] [float] NULL,
 CONSTRAINT [PK_skolematrikel] PRIMARY KEY CLUSTERED 
(
	[matrikel_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Skoleplaceringsaarsag]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Skoleplaceringsaarsag](
	[skoleplaceringsaarsag_id] [int] IDENTITY(1,1) NOT NULL,
	[skoleplaceringsaarsag_tekst] [nvarchar](255) NOT NULL,
	[beskrivelse] [nvarchar](1000) NULL,
	[aktiv] [bit] NOT NULL,
	[sortering] [int] NULL,
 CONSTRAINT [PK_Skoleplaceringsaarsag] PRIMARY KEY CLUSTERED 
(
	[skoleplaceringsaarsag_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UQ_Skoleplaceringsaarsag_tekst] UNIQUE NONCLUSTERED 
(
	[skoleplaceringsaarsag_tekst] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Skoleskifter]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Skoleskifter](
	[skoleskifter_id] [int] IDENTITY(1,1) NOT NULL,
	[cpr] [varchar](10) NOT NULL,
	[variant] [nvarchar](30) NOT NULL,
	[status_id] [int] NOT NULL,
	[status_dato] [date] NULL,
	[modtaget_tidspunkt] [datetime2](7) NOT NULL,
	[os2forms_id] [nvarchar](100) NULL,
	[ansoegningsdata] [nvarchar](max) NULL,
	[esdh_noegle] [nvarchar](50) NULL,
	[esdh_url] [nvarchar](500) NULL,
	[oensket_skolekode] [int] NULL,
	[nuvaerende_skolekode] [int] NULL,
	[nuvaerende_skole_tekst] [nvarchar](200) NULL,
	[klassetrin_ansoegning] [nvarchar](20) NULL,
	[kommende_adresse] [nvarchar](300) NULL,
	[screeningsdato] [date] NULL,
	[point_1] [decimal](6, 1) NULL,
	[resultat_1] [nvarchar](100) NULL,
	[point_2] [decimal](6, 1) NULL,
	[resultat_2] [nvarchar](100) NULL,
	[point_3] [decimal](6, 1) NULL,
	[resultat_3] [nvarchar](100) NULL,
	[samlet_resultat] [nvarchar](100) NULL,
	[skoletilbud_matrikel_id] [int] NULL,
	[skoletilbudstype_id] [int] NULL,
	[dato_skoletilbud] [date] NULL,
	[start_visitationsklasse] [date] NULL,
	[klassetrin] [nvarchar](20) NULL,
	[spor] [nvarchar](50) NULL,
	[bemaerkning] [nvarchar](max) NULL,
	[ppr_sendt_dato] [date] NULL,
	[afsluttet_dato] [date] NULL,
	[created_at] [datetime2](7) NOT NULL,
	[created_by] [nvarchar](100) NOT NULL,
	[updated_at] [datetime2](7) NOT NULL,
	[updated_by] [nvarchar](100) NOT NULL,
	[aktiv] [bit] NOT NULL,
	[skoleaar] [int] NULL,
	[nuvaerende_skoletilbud] [nvarchar](30) NULL,
	[udslusningsdato] [date] NULL,
	[nuvaerende_kommune] [nvarchar](100) NULL,
	[flytning] [bit] NULL,
	[flyttedato] [date] NULL,
	[modersmaal_foraelder] [nvarchar](50) NULL,
	[modersmaal_skole] [nvarchar](50) NULL,
	[soeskende_paa_skolen] [bit] NULL,
	[soeskende_klasse] [nvarchar](20) NULL,
	[begrundelse] [nvarchar](max) NULL,
	[skolens_afgoerelse] [nvarchar](50) NULL,
 CONSTRAINT [PK_Skoleskifter] PRIMARY KEY CLUSTERED 
(
	[skoleskifter_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Skoletilbudstype]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Skoletilbudstype](
	[skoletilbudstype_id] [int] IDENTITY(1,1) NOT NULL,
	[skoletilbudstype_tekst] [nvarchar](255) NOT NULL,
	[beskrivelse] [nvarchar](1000) NULL,
	[aktiv] [bit] NOT NULL,
	[fagomraade_id] [int] NULL,
	[sortering] [int] NULL,
 CONSTRAINT [PK_Skoletilbudstype] PRIMARY KEY CLUSTERED 
(
	[skoletilbudstype_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UQ_Skoletilbudstype_tekst_fagomraade] UNIQUE NONCLUSTERED 
(
	[skoletilbudstype_tekst] ASC,
	[fagomraade_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dsa].[Status]    Script Date: 06/11/2026 10:58:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dsa].[Status](
	[status_id] [int] IDENTITY(1,1) NOT NULL,
	[status_tekst] [nvarchar](255) NOT NULL,
	[beskrivelse] [nvarchar](1000) NULL,
	[aktiv] [bit] NOT NULL,
	[fagomraade_id] [int] NULL,
	[sortering] [int] NULL,
 CONSTRAINT [PK_Status] PRIMARY KEY CLUSTERED 
(
	[status_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UQ_Status_tekst_fagomraade] UNIQUE NONCLUSTERED 
(
	[status_tekst] ASC,
	[fagomraade_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dsa].[Aendringsaarsag] ADD  CONSTRAINT [DF_Aendringsaarsag_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [dsa].[Brevskabelon] ADD  CONSTRAINT [DF_Brevskabelon_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [dsa].[Elev] ADD  CONSTRAINT [DF_Elev_opdateret]  DEFAULT (sysdatetime()) FOR [opdateret_tidspunkt]
GO
ALTER TABLE [dsa].[Elev_Modersmaal] ADD  CONSTRAINT [DF_Elev_Modersmaal_gyldig_til]  DEFAULT ('99991231') FOR [gyldig_til]
GO
ALTER TABLE [dsa].[Fagomraade] ADD  CONSTRAINT [DF_Fagomraade_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [dsa].[Foraelder] ADD  CONSTRAINT [DF_Foraelder_maa_vide_barns_adresse]  DEFAULT ((1)) FOR [maa_vide_barns_adresse]
GO
ALTER TABLE [dsa].[Foraelder] ADD  CONSTRAINT [DF_Foraelder_relation]  DEFAULT (N'Ukendt') FOR [relation]
GO
ALTER TABLE [dsa].[Sagsaktivitet] ADD  CONSTRAINT [DF_Sagsaktivitet_oprettet]  DEFAULT (sysdatetime()) FOR [oprettet_tidspunkt]
GO
ALTER TABLE [dsa].[Skolebegynder] ADD  CONSTRAINT [DF_Skolebegynder_modtaget]  DEFAULT (sysdatetime()) FOR [modtaget_tidspunkt]
GO
ALTER TABLE [dsa].[Skolebegynder] ADD  CONSTRAINT [DF_Skolebegynder_created_at]  DEFAULT (sysdatetime()) FOR [created_at]
GO
ALTER TABLE [dsa].[Skolebegynder] ADD  CONSTRAINT [DF_Skolebegynder_updated_at]  DEFAULT (sysdatetime()) FOR [updated_at]
GO
ALTER TABLE [dsa].[Skolebegynder] ADD  CONSTRAINT [DF_Skolebegynder_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [dsa].[Skolebegynder_Aendring] ADD  CONSTRAINT [DF_Skolebegynder_Aendring_registreret]  DEFAULT (sysdatetime()) FOR [registreret_tidspunkt]
GO
ALTER TABLE [dsa].[Skolebegynder_Aendring] ADD  CONSTRAINT [DF_Skolebegynder_Aendring_haandteret]  DEFAULT ((0)) FOR [haandteret]
GO
ALTER TABLE [dsa].[SkoleHistorik] ADD  CONSTRAINT [DF_SkoleHistorik_oprettet]  DEFAULT (sysdatetime()) FOR [oprettet_tidspunkt]
GO
ALTER TABLE [dsa].[Skoleplaceringsaarsag] ADD  CONSTRAINT [DF_Skoleplaceringsaarsag_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [dsa].[Skoleskifter] ADD  CONSTRAINT [DF_Skoleskifter_modtaget]  DEFAULT (sysdatetime()) FOR [modtaget_tidspunkt]
GO
ALTER TABLE [dsa].[Skoleskifter] ADD  CONSTRAINT [DF_Skoleskifter_created_at]  DEFAULT (sysdatetime()) FOR [created_at]
GO
ALTER TABLE [dsa].[Skoleskifter] ADD  CONSTRAINT [DF_Skoleskifter_updated_at]  DEFAULT (sysdatetime()) FOR [updated_at]
GO
ALTER TABLE [dsa].[Skoleskifter] ADD  CONSTRAINT [DF_Skoleskifter_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [dsa].[Skoletilbudstype] ADD  CONSTRAINT [DF_Skoletilbudstype_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [dsa].[Status] ADD  CONSTRAINT [DF_Status_aktiv]  DEFAULT ((1)) FOR [aktiv]
GO
ALTER TABLE [dsa].[Brevskabelon]  WITH CHECK ADD  CONSTRAINT [FK_Brevskabelon_Fagomraade] FOREIGN KEY([fagomraade_id])
REFERENCES [dsa].[Fagomraade] ([fagomraade_id])
GO
ALTER TABLE [dsa].[Brevskabelon] CHECK CONSTRAINT [FK_Brevskabelon_Fagomraade]
GO
ALTER TABLE [dsa].[Elev]  WITH CHECK ADD  CONSTRAINT [FK_Elev_Adresse] FOREIGN KEY([adresse_id])
REFERENCES [dsa].[Adresse] ([adresse_id])
GO
ALTER TABLE [dsa].[Elev] CHECK CONSTRAINT [FK_Elev_Adresse]
GO
ALTER TABLE [dsa].[Elev_Indrejse]  WITH CHECK ADD  CONSTRAINT [FK_Elev_Indrejse_Elev] FOREIGN KEY([cpr])
REFERENCES [dsa].[Elev] ([cpr])
GO
ALTER TABLE [dsa].[Elev_Indrejse] CHECK CONSTRAINT [FK_Elev_Indrejse_Elev]
GO
ALTER TABLE [dsa].[Elev_Modersmaal]  WITH CHECK ADD  CONSTRAINT [FK_Elev_Modersmaal_Elev] FOREIGN KEY([cpr])
REFERENCES [dsa].[Elev] ([cpr])
GO
ALTER TABLE [dsa].[Elev_Modersmaal] CHECK CONSTRAINT [FK_Elev_Modersmaal_Elev]
GO
ALTER TABLE [dsa].[Elev_PPR]  WITH CHECK ADD  CONSTRAINT [FK_Elev_PPR_Elev] FOREIGN KEY([cpr])
REFERENCES [dsa].[Elev] ([cpr])
GO
ALTER TABLE [dsa].[Elev_PPR] CHECK CONSTRAINT [FK_Elev_PPR_Elev]
GO
ALTER TABLE [dsa].[Foraelder]  WITH CHECK ADD  CONSTRAINT [FK_Foraelder_Adresse] FOREIGN KEY([adresse_id])
REFERENCES [dsa].[Adresse] ([adresse_id])
GO
ALTER TABLE [dsa].[Foraelder] CHECK CONSTRAINT [FK_Foraelder_Adresse]
GO
ALTER TABLE [dsa].[Foraelder]  WITH CHECK ADD  CONSTRAINT [FK_Foraelder_Elev] FOREIGN KEY([cpr_elev])
REFERENCES [dsa].[Elev] ([cpr])
GO
ALTER TABLE [dsa].[Foraelder] CHECK CONSTRAINT [FK_Foraelder_Elev]
GO
ALTER TABLE [dsa].[Sagsaktivitet]  WITH CHECK ADD  CONSTRAINT [FK_Sagsaktivitet_Fagomraade] FOREIGN KEY([fagomraade_id])
REFERENCES [dsa].[Fagomraade] ([fagomraade_id])
GO
ALTER TABLE [dsa].[Sagsaktivitet] CHECK CONSTRAINT [FK_Sagsaktivitet_Fagomraade]
GO
ALTER TABLE [dsa].[Sagsaktivitet]  WITH CHECK ADD  CONSTRAINT [FK_Sagsaktivitet_Type] FOREIGN KEY([aktivitetstype_id])
REFERENCES [dsa].[SagsaktivitetType] ([type_id])
GO
ALTER TABLE [dsa].[Sagsaktivitet] CHECK CONSTRAINT [FK_Sagsaktivitet_Type]
GO
ALTER TABLE [dsa].[Skolebegynder]  WITH CHECK ADD  CONSTRAINT [FK_Skolebegynder_Brevskabelon] FOREIGN KEY([brevskabelon_id])
REFERENCES [dsa].[Brevskabelon] ([brevskabelon_id])
GO
ALTER TABLE [dsa].[Skolebegynder] CHECK CONSTRAINT [FK_Skolebegynder_Brevskabelon]
GO
ALTER TABLE [dsa].[Skolebegynder]  WITH CHECK ADD  CONSTRAINT [FK_Skolebegynder_Elev] FOREIGN KEY([cpr])
REFERENCES [dsa].[Elev] ([cpr])
GO
ALTER TABLE [dsa].[Skolebegynder] CHECK CONSTRAINT [FK_Skolebegynder_Elev]
GO
ALTER TABLE [dsa].[Skolebegynder]  WITH CHECK ADD  CONSTRAINT [FK_Skolebegynder_Skoleplaceringsaarsag] FOREIGN KEY([skoleplaceringsaarsag_id])
REFERENCES [dsa].[Skoleplaceringsaarsag] ([skoleplaceringsaarsag_id])
GO
ALTER TABLE [dsa].[Skolebegynder] CHECK CONSTRAINT [FK_Skolebegynder_Skoleplaceringsaarsag]
GO
ALTER TABLE [dsa].[Skolebegynder]  WITH CHECK ADD  CONSTRAINT [FK_Skolebegynder_Skoletilbud] FOREIGN KEY([skoletilbud_matrikel_id])
REFERENCES [dsa].[Skolematrikel] ([matrikel_id])
GO
ALTER TABLE [dsa].[Skolebegynder] CHECK CONSTRAINT [FK_Skolebegynder_Skoletilbud]
GO
ALTER TABLE [dsa].[Skolebegynder]  WITH CHECK ADD  CONSTRAINT [FK_Skolebegynder_Skoletilbudstype] FOREIGN KEY([skoletilbudstype_id])
REFERENCES [dsa].[Skoletilbudstype] ([skoletilbudstype_id])
GO
ALTER TABLE [dsa].[Skolebegynder] CHECK CONSTRAINT [FK_Skolebegynder_Skoletilbudstype]
GO
ALTER TABLE [dsa].[Skolebegynder]  WITH CHECK ADD  CONSTRAINT [FK_Skolebegynder_Status] FOREIGN KEY([status_id])
REFERENCES [dsa].[Status] ([status_id])
GO
ALTER TABLE [dsa].[Skolebegynder] CHECK CONSTRAINT [FK_Skolebegynder_Status]
GO
ALTER TABLE [dsa].[Skolebegynder_Aendring]  WITH CHECK ADD  CONSTRAINT [FK_Skolebegynder_Aendring_Skolebegynder] FOREIGN KEY([skolebegynder_id])
REFERENCES [dsa].[Skolebegynder] ([skolebegynder_id])
GO
ALTER TABLE [dsa].[Skolebegynder_Aendring] CHECK CONSTRAINT [FK_Skolebegynder_Aendring_Skolebegynder]
GO
ALTER TABLE [dsa].[Skolebegynder_Aendring]  WITH CHECK ADD  CONSTRAINT [FK_Skolebegynder_Aendring_Aarsag] FOREIGN KEY([aendringsaarsag_id])
REFERENCES [dsa].[Aendringsaarsag] ([aendringsaarsag_id])
GO
ALTER TABLE [dsa].[Skolebegynder_Aendring] CHECK CONSTRAINT [FK_Skolebegynder_Aendring_Aarsag]
GO
ALTER TABLE [dsa].[SkoleHistorik]  WITH CHECK ADD  CONSTRAINT [FK_SkoleHistorik_Elev] FOREIGN KEY([cpr])
REFERENCES [dsa].[Elev] ([cpr])
GO
ALTER TABLE [dsa].[SkoleHistorik] CHECK CONSTRAINT [FK_SkoleHistorik_Elev]
GO
ALTER TABLE [dsa].[Skoleskifter]  WITH CHECK ADD  CONSTRAINT [FK_Skoleskifter_Elev] FOREIGN KEY([cpr])
REFERENCES [dsa].[Elev] ([cpr])
GO
ALTER TABLE [dsa].[Skoleskifter] CHECK CONSTRAINT [FK_Skoleskifter_Elev]
GO
ALTER TABLE [dsa].[Skoleskifter]  WITH CHECK ADD  CONSTRAINT [FK_Skoleskifter_Skoletilbud] FOREIGN KEY([skoletilbud_matrikel_id])
REFERENCES [dsa].[Skolematrikel] ([matrikel_id])
GO
ALTER TABLE [dsa].[Skoleskifter] CHECK CONSTRAINT [FK_Skoleskifter_Skoletilbud]
GO
ALTER TABLE [dsa].[Skoleskifter]  WITH CHECK ADD  CONSTRAINT [FK_Skoleskifter_Skoletilbudstype] FOREIGN KEY([skoletilbudstype_id])
REFERENCES [dsa].[Skoletilbudstype] ([skoletilbudstype_id])
GO
ALTER TABLE [dsa].[Skoleskifter] CHECK CONSTRAINT [FK_Skoleskifter_Skoletilbudstype]
GO
ALTER TABLE [dsa].[Skoleskifter]  WITH CHECK ADD  CONSTRAINT [FK_Skoleskifter_Status] FOREIGN KEY([status_id])
REFERENCES [dsa].[Status] ([status_id])
GO
ALTER TABLE [dsa].[Skoleskifter] CHECK CONSTRAINT [FK_Skoleskifter_Status]
GO
ALTER TABLE [dsa].[Skoletilbudstype]  WITH CHECK ADD  CONSTRAINT [FK_Skoletilbudstype_Fagomraade] FOREIGN KEY([fagomraade_id])
REFERENCES [dsa].[Fagomraade] ([fagomraade_id])
GO
ALTER TABLE [dsa].[Skoletilbudstype] CHECK CONSTRAINT [FK_Skoletilbudstype_Fagomraade]
GO
ALTER TABLE [dsa].[Status]  WITH CHECK ADD  CONSTRAINT [FK_Status_Fagomraade] FOREIGN KEY([fagomraade_id])
REFERENCES [dsa].[Fagomraade] ([fagomraade_id])
GO
ALTER TABLE [dsa].[Status] CHECK CONSTRAINT [FK_Status_Fagomraade]
GO
ALTER TABLE [dsa].[Elev]  WITH CHECK ADD  CONSTRAINT [CK_Elev_cpr] CHECK  ((len([cpr])=(10) AND NOT [cpr] like '%[^0-9]%'))
GO
ALTER TABLE [dsa].[Elev] CHECK CONSTRAINT [CK_Elev_cpr]
GO
ALTER TABLE [dsa].[Elev_Indrejse]  WITH CHECK ADD  CONSTRAINT [CK_Elev_Indrejse_cpr] CHECK  ((len([cpr])=(10) AND NOT [cpr] like '%[^0-9]%'))
GO
ALTER TABLE [dsa].[Elev_Indrejse] CHECK CONSTRAINT [CK_Elev_Indrejse_cpr]
GO
ALTER TABLE [dsa].[Elev_Indrejse]  WITH CHECK ADD  CONSTRAINT [CK_Elev_Indrejse_datoer] CHECK  (([seneste_indrejse]>=[foerste_indrejse]))
GO
ALTER TABLE [dsa].[Elev_Indrejse] CHECK CONSTRAINT [CK_Elev_Indrejse_datoer]
GO
ALTER TABLE [dsa].[Elev_Modersmaal]  WITH CHECK ADD  CONSTRAINT [CK_Elev_Modersmaal_cpr] CHECK  ((len([cpr])=(10) AND NOT [cpr] like '%[^0-9]%'))
GO
ALTER TABLE [dsa].[Elev_Modersmaal] CHECK CONSTRAINT [CK_Elev_Modersmaal_cpr]
GO
ALTER TABLE [dsa].[Elev_Modersmaal]  WITH CHECK ADD  CONSTRAINT [CK_Elev_Modersmaal_periode] CHECK  (([gyldig_til]>=[gyldig_fra]))
GO
ALTER TABLE [dsa].[Elev_Modersmaal] CHECK CONSTRAINT [CK_Elev_Modersmaal_periode]
GO
ALTER TABLE [dsa].[Elev_PPR]  WITH CHECK ADD  CONSTRAINT [CK_Elev_PPR_periode] CHECK  (([slutdato]>=[startdato]))
GO
ALTER TABLE [dsa].[Elev_PPR] CHECK CONSTRAINT [CK_Elev_PPR_periode]
GO
ALTER TABLE [dsa].[Foraelder]  WITH CHECK ADD  CONSTRAINT [CK_Foraelder_cpr] CHECK  ((len([cpr_foraelder])=(10) AND NOT [cpr_foraelder] like '%[^0-9]%'))
GO
ALTER TABLE [dsa].[Foraelder] CHECK CONSTRAINT [CK_Foraelder_cpr]
GO
ALTER TABLE [dsa].[Skolebegynder]  WITH CHECK ADD  CONSTRAINT [CK_Skolebegynder_skoleaar] CHECK  (([skoleaar]>=(2000) AND [skoleaar]<=(2100)))
GO
ALTER TABLE [dsa].[Skolebegynder] CHECK CONSTRAINT [CK_Skolebegynder_skoleaar]
GO
ALTER TABLE [dsa].[SkoleHistorik]  WITH CHECK ADD  CONSTRAINT [CK_SkoleHistorik_periode] CHECK  (([gyldig_til] IS NULL OR [gyldig_til]>=[gyldig_fra]))
GO
ALTER TABLE [dsa].[SkoleHistorik] CHECK CONSTRAINT [CK_SkoleHistorik_periode]
GO
ALTER TABLE [dsa].[Skoleskifter]  WITH CHECK ADD  CONSTRAINT [CK_Skoleskifter_afgoerelse] CHECK  (([skolens_afgoerelse]=N'Ledig plads' OR [skolens_afgoerelse]=N'Tilflytter til distriktet'))
GO
ALTER TABLE [dsa].[Skoleskifter] CHECK CONSTRAINT [CK_Skoleskifter_afgoerelse]
GO
ALTER TABLE [dsa].[Skoleskifter]  WITH CHECK ADD  CONSTRAINT [CK_Skoleskifter_skoletilbud] CHECK  (([nuvaerende_skoletilbud]=N'Modtagelsesklasse' OR [nuvaerende_skoletilbud]=N'Almen klasse'))
GO
ALTER TABLE [dsa].[Skoleskifter] CHECK CONSTRAINT [CK_Skoleskifter_skoletilbud]
GO
ALTER TABLE [dsa].[Skoleskifter]  WITH CHECK ADD  CONSTRAINT [CK_Skoleskifter_variant] CHECK  (([variant]=N'Skoleskift udefra' OR [variant]=N'Skoleskift internt' OR [variant]=N'Tilflytter'))
GO
ALTER TABLE [dsa].[Skoleskifter] CHECK CONSTRAINT [CK_Skoleskifter_variant]
GO

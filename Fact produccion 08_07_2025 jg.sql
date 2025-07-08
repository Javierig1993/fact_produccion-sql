--Fact produccion 

WITH MapModulosCerrados AS (
    SELECT 
        ID,
        CASE 
            WHEN DREAL <> '1900-01-01' THEN 'CERRADO'
            ELSE 'ACTIVO'
        END AS EstadoGeneralModulo
    FROM TF_WEB.dbo.PRODUCCION_MODULOS
),
MapM2Modulos AS (
    SELECT 
        ID,M2
    FROM TF_WEB.dbo.PRODUCCION_MODULOS
),
MapUbicacion AS (
    SELECT 
        a.ID,
        b.li_nombre AS Ubicacion
    FROM TF_WEB.dbo.PRODUCCION_MODULOS a
    LEFT JOIN TF_WEB.dbo.LISTAS_PRODUCCION b ON a.UBICACION = b.li_id
),
MapAtrasoIngreso AS (
    SELECT 
        li_id AS CodAtrasoIngreso,
        li_nombre AS MotivoAtrasoIngreso
    FROM TF_WEB.dbo.LISTAS_PRODUCCION
),
MapAtrasoSalida AS (
    SELECT 
        li_id AS CodAtrasoSalida,
        li_nombre AS MotivoAtrasoSalida
    FROM TF_WEB.dbo.LISTAS_PRODUCCION
),
MapTipoModulo AS (
    SELECT 
        li_id AS CodTipoModulo,
        li_nombre AS TipoModulo
    FROM TF_WEB.dbo.LISTAS_PRODUCCION
),
MapEquipo AS (
    SELECT 
        li_id AS CodEquipo,
        li_nombre AS Equipo,
        CASE 
            WHEN li_nombre LIKE '%Arambur%' THEN 'Arambur'
            WHEN li_nombre LIKE '%Consa%' THEN 'Consa'
            WHEN li_nombre LIKE '%Duarte%' THEN 'Duarte'
            WHEN li_nombre LIKE '%Redsan%' THEN 'Redsan'
        END AS EquipoSanitario,
        CASE 
            WHEN li_nombre LIKE '%Promodular%' THEN 'Promodular'
            WHEN li_nombre LIKE '%Tecno Fast%' THEN 'Tecno Fast'
        END AS EquipoTerminaciones
    FROM TF_WEB.dbo.LISTAS_PRODUCCION
),
--integracion de avance de modulo %
AVANCE_MODULO00 AS (
    SELECT 
        ID,
        FECHACAL AS FechaCalculoAvance,
        DPROYECTADO AS FechaProyectada,

        -- Avances normalizados a decimal
        CAST(ROUND(IIF(PFABRICA > 100, 100, PFABRICA) / 100.0, 2) AS DECIMAL(5,2)) AS Avance_Obra_Gruesa,
        CAST(ROUND(IIF(SANITARIOS > 100, 100, SANITARIOS) / 100.0, 2) AS DECIMAL(5,2)) AS Avance_Sanitario,
        CAST(ROUND(IIF(FABRICA1 > 100, 100, FABRICA1) / 100.0, 2) AS DECIMAL(5,2)) AS Avance_Electrico,
        CAST(ROUND(IIF(TERMINACIONES > 100, 100, TERMINACIONES) / 100.0, 2) AS DECIMAL(5,2)) AS Avance_Terminaciones
    FROM TF_WEB.dbo.PRODUCCION_LISTADO
),
UbicacionTexto AS (
    SELECT  ID,  
        CAST(Ubicacion AS VARCHAR(100)) AS ubicacion
    FROM TF_WEB.dbo.PRODUCCION_MODULOS
),
AVANCE_MODULO AS (
    SELECT 
        a.ID AS Key_Produccion_Modulos,
        a.FechaCalculoAvance,
        a.FechaProyectada,
        m2.M2,

        -- Avances individuales formateados como porcentaje
        FORMAT(a.Avance_Electrico, 'P', 'es-CL')     AS Avance_Electrico,
        FORMAT(a.Avance_Obra_Gruesa, 'P', 'es-CL')   AS Avance_Obra_Gruesa,
        FORMAT(a.Avance_Sanitario, 'P', 'es-CL')     AS Avance_Sanitario,
        FORMAT(a.Avance_Terminaciones, 'P', 'es-CL') AS Avance_Terminaciones,

        -- Avance módulo (ponderado) como porcentaje
        FORMAT(
            IIF(mc.ID IS NOT NULL, 1.0,
                ROUND(
                    a.Avance_Obra_Gruesa * 0.4 +
                    a.Avance_Sanitario * 0.17 +
                    a.Avance_Electrico * 0.09 +
                    a.Avance_Terminaciones * 0.34, 2)
            ), 'P'
        ) AS [Avance Módulo],

        -- M2 Avance módulo
        FORMAT(
            IIF(mc.ID IS NOT NULL, m2.M2,
                ROUND(
                    a.Avance_Obra_Gruesa * 0.4 +
                    a.Avance_Sanitario * 0.17 +
                    a.Avance_Electrico * 0.09 +
                    a.Avance_Terminaciones * 0.34, 2) * m2.M2
            ), '#,##0.0'
        ) AS [M2 Avance Módulo],

        -- M2 pendiente módulo
        FORMAT(
            IIF(mc.ID IS NOT NULL, 0,
                (1 - (
                    a.Avance_Obra_Gruesa * 0.4 +
                    a.Avance_Sanitario * 0.17 +
                    a.Avance_Electrico * 0.09 +
                    a.Avance_Terminaciones * 0.34
                )) * m2.M2
            ), '#,##0.0'
        ) AS [M2 Pendiente Módulo],

        -- Estado avance módulo
        CASE 
            WHEN mc.ID IS NOT NULL THEN 'FABRICACIÓN OK'
            WHEN ROUND(
                    a.Avance_Obra_Gruesa * 0.4 +
                    a.Avance_Sanitario * 0.17 +
                    a.Avance_Electrico * 0.09 +
                    a.Avance_Terminaciones * 0.34, 2) > 0 THEN 'EN FABRICACIÓN'
            ELSE 'POR FABRICAR'
        END AS [Estado Avance Módulo],

        -- Estado módulo general
        CASE 
            WHEN u.ubicacion = 'TERRENO' THEN 'Despachado'
            WHEN mc.ID IS NOT NULL THEN 'Cerrado'
            WHEN ROUND(
                    a.Avance_Obra_Gruesa * 0.4 +
                    a.Avance_Sanitario * 0.17 +
                    a.Avance_Electrico * 0.09 +
                    a.Avance_Terminaciones * 0.34, 2) <> 0 THEN 'Activo'
            ELSE 'Pendientes de ingreso'
        END AS [Estado Módulo]

    FROM AVANCE_MODULO00 a
LEFT JOIN MapModulosCerrados mc ON a.ID = mc.ID
LEFT JOIN MapM2Modulos m2 ON a.ID = m2.ID
LEFT JOIN UbicacionTexto u ON a.ID = u.ID

)



SELECT 
    p.ID AS Key_Produccion_Modulos,
    u.Ubicacion AS [Ubicación],
    p.GUIA AS [Guía],
    TRY_CAST(p.PROYECTO AS INT) AS [Nro Proyecto],
    p.PROYECTO + '|' + CAST(p.NSERIE AS VARCHAR) AS Key_Proyecto_Serie,
    p.EDIFICIO,
    p.PISO,
    p.NSERIE AS [Nro Serie],
    RIGHT(p.NSERIE, 5) AS [Nro Serie Corto],
    TRY_CAST(p.NMODULO AS INT) AS [Nro Módulo],
    tm.TipoModulo,
    p.M2 AS M2_Original,
    FORMAT(p.M2, '#,##0.0') AS M2,
    CAST(ROUND(p.M2, 0) AS VARCHAR) + ' m2' AS [M2 Módulo],
    p.LINEA AS [Cod Línea],
    e.Equipo,
    CASE WHEN p.EPROYECTADA = '1900-01-01' THEN NULL ELSE p.EPROYECTADA END AS [Fecha Ingreso Programado],
    DATEFROMPARTS(YEAR(p.EPROYECTADA), MONTH(p.EPROYECTADA), 1) AS [Fecha Start Ingreso Programado],
    YEAR(p.EPROYECTADA) AS [Año Ingreso Programado],
    CASE WHEN p.DPROYECTADO = '1900-01-01' THEN NULL ELSE p.DPROYECTADO END AS [Fecha Salida Programado],
    DATEFROMPARTS(YEAR(p.DPROYECTADO), MONTH(p.DPROYECTADO), 1) AS [Fecha Start Salida Programado],
    YEAR(p.DPROYECTADO) AS [Año Salida Programado],
    CASE WHEN p.EREAL = '1900-01-01' THEN NULL ELSE p.EREAL END AS [Fecha Ingreso Real],
    ai.MotivoAtrasoIngreso,
    CASE WHEN p.EPROGRAMADA = '1900-01-01' THEN NULL ELSE p.EPROGRAMADA END AS [Fecha Ingreso Reprogramado],
    CASE WHEN p.DPROGRAMADO = '1900-01-01' THEN NULL ELSE p.DPROGRAMADO END AS [Fecha Salida Reprogramado],
    CASE WHEN p.DREAL = '1900-01-01' THEN NULL ELSE p.DREAL END AS [Fecha Salida Real],
    asd.MotivoAtrasoSalida,
    mc.EstadoGeneralModulo,
    CASE 
        WHEN p.EPROGRAMADA <> '1900-01-01' THEN 'Reprogramado'
        WHEN p.EPROYECTADA <> '1900-01-01' THEN 'Programado'
        ELSE 'Sin Fecha Programación'
    END AS [Estado Ingreso Programación],
    CASE 
        WHEN p.DPROGRAMADO <> '1900-01-01' THEN 'Reprogramado'
        WHEN p.DPROYECTADO <> '1900-01-01' THEN 'Programado'
        ELSE 'Sin Fecha Programación'
    END AS [Estado Salida Programación],
    CASE 
        WHEN p.EREAL = '1900-01-01' THEN 0
        WHEN DATEPART(WEEK, p.EREAL) = DATEPART(WEEK, p.EPROYECTADA) THEN 1
        ELSE 0
    END AS Flag_Ingreso_Programado,
    CASE 
        WHEN p.DREAL = '1900-01-01' THEN 0
        WHEN DATEPART(WEEK, p.DREAL) = DATEPART(WEEK, p.DPROYECTADO) THEN 1
        ELSE 0
    END AS Flag_Salida_Programada,
    CASE 
        WHEN p.EREAL = '1900-01-01' THEN NULL 
        ELSE DATEADD(DAY, -15, p.EREAL)
    END AS [Fecha Salida Proyectada],
    DATEDIFF(
        DAY, 
        IIF(p.EREAL = '1900-01-01', NULL, p.EREAL), 
        IIF(p.DREAL = '1900-01-01', GETDATE(), p.DREAL)
    ) AS [Días de Fabricación],
    
    -- Campos de AVANCE_MODULO
    am.FechaCalculoAvance,
    am.FechaProyectada,
    am.M2 AS M2_Avance,  -- Cambiado el alias para evitar conflicto con p.M2
    am.Avance_Electrico,
    am.Avance_Obra_Gruesa,
    am.Avance_Sanitario,
    am.Avance_Terminaciones,
    am.[Avance Módulo],
    am.[M2 Avance Módulo],
    am.[M2 Pendiente Módulo],
    am.[Estado Avance Módulo],
    am.[Estado Módulo] AS [Estado Módulo Avance]  -- Cambiado el alias para evitar conflicto
    
FROM TF_WEB.dbo.PRODUCCION_MODULOS p
LEFT JOIN MapModulosCerrados mc ON p.ID = mc.ID
LEFT JOIN MapM2Modulos m2m ON p.ID = m2m.ID
LEFT JOIN MapUbicacion u ON p.ID = u.ID
LEFT JOIN MapAtrasoIngreso ai ON p.MATRASO = ai.CodAtrasoIngreso
LEFT JOIN MapAtrasoSalida asd ON p.MATRASODESPACHO = asd.CodAtrasoSalida
LEFT JOIN MapTipoModulo tm ON p.TIPOMODULO = tm.CodTipoModulo
LEFT JOIN MapEquipo e ON p.EQUIPO = e.CodEquipo
LEFT JOIN AVANCE_MODULO am ON p.ID = am.Key_Produccion_Modulos  -- Aquí integras AVANCE_MODULO
WHERE p.ID IN ('34102','32528');

/*
Descripcion:	Scripts para la generacion de las tablas/vistas para obtener los reumenes de piezometros por pozo
					- v_piezometro_consolidado_v0
					- v_piezometro_consolidado
					- v_piezometro_geom_point
					- v_piezometro_inter_mbloque
					- mv_piezometro_inter_mbloque (tabla)
					- v_piezometro_resumen
					- v_piezometro_pozo_resumen
Parametros?:	Si:
					- SRID asociado al geom de los datos de en coordenadas locales. Por defecto esta en 1000 (MEL LOCAL). En v_piezometro_consolidado_v0
					- Distancia maxima para buscar vecinos en el modelo de bloque. Por defecto esta en 50 (ya que el modelo de bloques esta a 25mts). En v_piezometro_inter_mbloque
Version:		1.1
Cambios:		Se cambia la vista materializada por una tabla, manteniendo el mismo nombre
Fecha:			17/03/2016
Autor:			Arnol
*/



/*
	Eliminar vistas/tablas si existen
*/
DROP VIEW IF EXISTS piezometria.v_piezometro_pozo_resumen;
DROP VIEW IF EXISTS piezometria.v_piezometro_resumen;
DROP TABLE IF EXISTS piezometria.v_piezometro_inter_mbloque;
DROP VIEW IF EXISTS piezometria.v_piezometro_inter_mbloque;
DROP VIEW IF EXISTS piezometria.v_piezometro_geom_point;
DROP VIEW IF EXISTS piezometria.v_piezometro_consolidado;
DROP VIEW IF EXISTS piezometria.v_piezometro_consolidado_v0;



/*
	Creacion de la vista 'piezometria'.'v_piezometro_consolidado_v0'
*/
CREATE VIEW piezometria.v_piezometro_consolidado_v0 AS (
	SELECT
		id_piezometro,
		fecha,
		groundwaterelevation,
		utm_este,
		utm_norte,
		-- Calcular el "x_local" y "y_local" a partir de las coordenadas en WGS84 cuando vengan nulas
		CASE WHEN x_local IS NULL THEN st_x(st_transform(ST_SetSRID (ST_MakePoint (utm_este, utm_norte),24879),1000)) ELSE x_local END AS x_local,
		CASE WHEN y_local IS NULL THEN st_y(st_transform(ST_SetSRID (ST_MakePoint (utm_este, utm_norte),24879),1000)) ELSE y_local END AS y_local,
		cota_superficie,
		cota_sensor,
		-- Agregar geom de cada piezometro en coordenadas locales (SRID: 1000)
		CASE WHEN geom IS NULL THEN st_transform(ST_SetSRID (ST_MakePoint (utm_este, utm_norte),24879),1000) ELSE geom END AS geom
	FROM
		-- Definir la tabla con los datos a utilizar
		piezometria.piezometro_consolidado_v2
)
;


/*
	Crear vista 'piezometria'.'v_piezometro_consolidado'
*/
CREATE VIEW piezometria.v_piezometro_consolidado AS (
 SELECT t1.id_piezometro,
    t2.id_piezometro_pozo,
    t1.fecha,
	-- Se reemplazan los nulos por el valor "-9999"
    GREATEST(t1.groundwaterelevation, ((-9999))::double precision) AS groundwaterelevation,
    GREATEST(t1.cota_superficie, ((-9999))::double precision) AS cota_superficie,
    GREATEST(t1.cota_sensor, ((-9999))::double precision) AS cota_sensor,
    GREATEST((t1.cota_superficie - t1.cota_sensor), ((-9999))::double precision) AS profundidad,
    t1.geom,
    t1.x_local,
    t1.y_local
  FROM 
		piezometria.v_piezometro_consolidado_v0 t1
  JOIN (
		SELECT 
			v_piezometro_consolidado_v0.x_local,
      v_piezometro_consolidado_v0.y_local,
      min((v_piezometro_consolidado_v0.id_piezometro)::text) AS id_piezometro_pozo
    FROM 
			piezometria.v_piezometro_consolidado_v0
    GROUP BY 
			v_piezometro_consolidado_v0.x_local,
			v_piezometro_consolidado_v0.y_local
    ORDER BY 
			min((v_piezometro_consolidado_v0.id_piezometro)::text)
	) t2 
	ON (
		(t1.x_local = t2.x_local) 
		AND (t1.y_local = t2.y_local)
	)
  ORDER BY 
		t1.id_piezometro,
		t1.fecha
)
;


/*
	Crear vista 'piezometria'.'v_piezometro_geom_point'
*/
CREATE VIEW piezometria.v_piezometro_geom_point AS (
	SELECT 
		pz.id_piezometro,
		pz.x_local,
		pz.y_local,
		pz.cota_sensor,
		st_makepoint(pz.x_local, pz.y_local, pz.cota_sensor) AS pz_geom_point
	FROM ( 
			SELECT t1.id_piezometro,
				t1.x_local,
				t1.y_local,
				t1.cota_sensor
			FROM 
				piezometria.v_piezometro_consolidado_v0 t1
			GROUP BY
				t1.id_piezometro, t1.x_local, t1.y_local, t1.cota_sensor
		) pz
	WHERE 
		(st_makepoint(pz.x_local, pz.y_local, pz.cota_sensor) IS NOT NULL)
	ORDER BY 
		pz.id_piezometro
)
;


/*
	Crear tabla 'piezometria'.'mv_piezometro_inter_mbloque' a partir de la vista 'piezometria'.'v_piezometro_inter_mbloque'
*/
-- Crear vista 'piezometria'.'v_piezometro_inter_mbloque'
CREATE  VIEW piezometria.v_piezometro_inter_mbloque AS (
	SELECT DISTINCT
		ON (pz.id_piezometro) 
			pz.id_piezometro,
			pz.x_local,
			pz.y_local,
			pz.cota_sensor,
			pz_geom_point,
			mb.geom_point mb_geom_point,
			mb.xcentre,
			mb.ycentre,
			mb.zcentre,
			mb.litologia,
			mb.alteracion,
			mb.minzone,
			mb.ucs,
			mb.rmr_adic,			
			ST_3DDistance (pz.pz_geom_point, mb.geom_point) AS distancia
	FROM
		"piezometria"."v_piezometro_geom_point" pz,
		modelo_bloques.v_modelo_bloques_geom_point mb
	WHERE
		ST_3DDistance (pz.pz_geom_point, mb.geom_point) < 50
	ORDER BY
		pz.id_piezometro,
		distancia
);

-- Crear tabla 'piezometria'.'mv_piezometro_inter_mbloque'
CREATE TABLE piezometria.mv_piezometro_inter_mbloque AS(
	SELECT * FROM piezometria.v_piezometro_inter_mbloque
)
;


/*
	Crear vista 'piezometria'.'v_piezometro_resumen' integrando piezometros y modelo de bloques
*/
CREATE VIEW piezometria.v_piezometro_resumen AS (
	SELECT 
		pz.id_piezometro,
		pz.x_local,
		pz.y_local,
		pz.geom,
		pz.cota_superficie,
		pz.cota_sensor,
		pz.profundidad,
		pz.fecha_max,
		pz.fecha_min,
		pz.ultima_medicion_gwe,
		pmb.alteracion,
		pmb.litologia,
		pmb.minzone,
		pmb.ucs,
		pmb.rmr_adic,
		pmb.xcentre,
		pmb.ycentre,
		pmb.zcentre,
		pmb.distancia,
		(|/ ((((12.5 ^ (2)::numeric) + (12.5 ^ (2)::numeric)) + (7.5 ^ (2)::numeric)))::double precision) AS dist_maxima_en_bloque,
		(pmb.distancia < (|/ ((((12.5 ^ (2)::numeric) + (12.5 ^ (2)::numeric)) + (7.5 ^ (2)::numeric)))::double precision)) AS en_bloque
	FROM 
		piezometria.mv_piezometro_inter_mbloque pmb
	RIGHT JOIN (
			SELECT 
				t1.id_piezometro,
				t1.x_local,
				t1.y_local,
				t1.geom,
				t1.cota_superficie,
				t1.cota_sensor,
				t1.profundidad,
				t2.fecha_max,
				t2.fecha_min,
				t1.groundwaterelevation AS ultima_medicion_gwe
			FROM 
				piezometria.v_piezometro_consolidado t1
            JOIN ( 
					SELECT 
						t3.id_piezometro,
						max(t3.fecha) AS fecha_max,
						min(t3.fecha) AS fecha_min
					FROM 
						piezometria.v_piezometro_consolidado_v0 t3
					WHERE 
						(t3.groundwaterelevation IS NOT NULL)
					GROUP BY
						t3.id_piezometro
				) t2 
			ON (
				((t1.id_piezometro)::text = (t2.id_piezometro)::text) AND 
				(t1.fecha = t2.fecha_max)
				)
			ORDER BY 
				t1.id_piezometro
		) pz 
	ON (
		(pmb.id_piezometro)::text = (pz.id_piezometro)::text
		)
	ORDER BY
		pz.id_piezometro
)
;



/*
	Crear vista con informacion resumida por pozo para mostrar en geoalert
	- Se resume la infromacion por pozo
	- Sólo se agregan piezometros con al menos un dato de groundwaterelevation (gwe) distinto de NULL y con coordenadas locales (si no no se pueden agrupar por pozo)
	- Se agrega la info relevante de cada piezometro dentro del pozo como una lista ordenada
*/
CREATE VIEW piezometria.v_piezometro_pozo_resumen AS (
	SELECT 
		min((t1.id_piezometro)::text) AS id_piezometro_pozo,
		round((t1.x_local)::numeric, 3) AS x_local,
		round((t1.y_local)::numeric, 3) AS y_local,
		t1.geom,
		round((max(t1.cota_superficie))::numeric, 3) AS cota_superficie,
		(array_agg(t1.id_piezometro ORDER BY t1.profundidad))::character varying AS id_piezometros,
		(array_agg(round((t1.cota_sensor)::numeric, 3) ORDER BY t1.profundidad))::character varying AS cota_sensores,
		(array_agg(round((t1.profundidad)::numeric, 0) ORDER BY t1.profundidad))::character varying AS profundidades,
		(array_agg(round((t1.ultima_medicion_gwe)::numeric, 2) ORDER BY t1.profundidad))::character varying AS ultimas_mediciones,
		(array_agg(to_char(t1.fecha_min, 'DD-MM-YY'::text) ORDER BY t1.profundidad))::character varying AS fechas_minimas,
		(array_agg(to_char(t1.fecha_max, 'DD-MM-YY'::text) ORDER BY t1.profundidad))::character varying AS fechas_maximas,
		(array_agg(t1.litologia ORDER BY t1.profundidad))::character varying AS litologias,
		(array_agg(t1.alteracion ORDER BY t1.profundidad))::character varying AS alteraciones,
		(array_agg(t1.minzone ORDER BY t1.profundidad))::character varying AS minzones,
		(array_agg(round((t1.ucs)::numeric, 2) ORDER BY t1.profundidad))::character varying AS ucs,
		(array_agg(round((t1.rmr_adic)::numeric, 2) ORDER BY t1.profundidad))::character varying AS rmr,
		(array_agg(round((t1.distancia)::numeric, 2) ORDER BY t1.profundidad))::character varying AS distancia_mbloque,
		(array_agg(t1.en_bloque ORDER BY t1.profundidad))::character varying AS en_bloque,
		count(t1.id_piezometro) AS nro_piezometros
	FROM 
		piezometria.v_piezometro_resumen t1
	WHERE 
		((t1.x_local IS NOT NULL) AND (t1.y_local IS NOT NULL))
	GROUP BY 
		t1.x_local,
		t1.y_local,
		t1.geom
	ORDER BY 
		min((t1.id_piezometro)::text)
)
;

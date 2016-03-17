/*
Descripcion:	Scripts para actualizar la tabla 'piezometria','mv_piezometro_inter_mbloque'
					- mv_piezometro_inter_mbloque
				Este metodo es sensible al nombre de las columnas por lo que hay que hacer modificaciones con cuidado
Parametros?:	No
Version:		1.1
Cambios:		Se cambia la vista materializada por una tabla, manteniendo el mismo nombre.
				Ahora la actualizacion de la tabla debe ser mediante el siguiente script, en el futuro automatizar mediante triggres o en el PgAgent.
Fecha:			17/03/2016
Autor:			Arnol
*/



/*
	scripts para actualizar los datos de la tabla 'mv_piezometro_inter_mbloque'
*/
-- Eliminar registros de la tabla
TRUNCATE TABLE piezometria.mv_piezometro_inter_mbloque
;

-- Actualizar tabla 'mv_piezometro_inter_mbloque'
INSERT INTO piezometria.mv_piezometro_inter_mbloque
	SELECT * FROM piezometria.v_piezometro_inter_mbloque
;
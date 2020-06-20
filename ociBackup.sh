#!/bin/bash
#
# BACKUP HOT/COLD/ARCH/EXP - ORACLE
# By Pablo Niklas - Para SBD
# Licencia GPL
#
# 13/07/2006 - PSRN - Version Inicial.
# 14/07/2006 - PSRN - Agrego Archive Logs.
# 23/07/2006 - PSRN - Backup de Control File. Analisis parametrico.
# 24/07/2006 - PSRN - Cambio de nombre debido a parametrizacion.
# 28/07/2006 - PSRN - Paralelizacion con Unidades de Trabajo (!!)
# 29/07/2006 - PSRN - Mejoras generales y COLD backup.
# 01/08/2006 - PSRN - Fix DEBUG y compress de ControlFile
# 06/08/2006 - PSRN - Se cambio orden de backup para optimizaciones.
#                     Backup de pfile y optimizacion de multiprocesamiento.
# 08/08/2006 - PSRN - Mejor salida para el Control.dir
#                     Se hizo funcion el backup de los control files para mejor programacion.
# 28/08/2006 - PSRN - Se adapto salida debido a cambio de version del paralelizador.
# 01/09/2006 - PSRN - Cambios cosmeticos en los logs para mejor lectura de los mismos.
# 07/09/2006 - PSRN - Deteccion de la necesidad de borrado de archives logs.
# 20/11/2006 - PSRN - Agregado de fecha en los logs de export
# 04/12/2006 - PSRN - Agregado de Backup de archives logs en el cold backup y correcciones menores.
#

# Variables de configuracion x default
HOT=false
EXPORT=false
COLD=false
ARCHBACK=false

# BACKUPDIR
# Directorio BASE de Backups
BACKUPDIRP="/BACKUP.DAT"

# DIAS
# Dias de retencion de Archives Logs.
DIAS=7

# Debugging
DEBUG=false

#Tengo 4 micros
PARALELO=4

################################################# FUNCIONES ##################################################

# Backup de ControlFiles
function BKP_control_files() {

	echo 
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- Backupeando Control File..."
	cp $ORACLE_HOME/dbs/init${ORACLE_SID}.ora $BKPTSDIR		# pfile
	CTRLFILES=$(sqlplus -S '/ as sysdba' <<SQL2
	set termout off
	set pages 0
	set lines 120
	set feedback off
	set trimspool on
	set head off
	select value from v\$parameter where name='control_files';
SQL2
)
	rm -f $BKPTSDIR/Control.dir
	echo $CTRLFILES |awk '{split($0,a,","); for (i=1; i<=NF; i++) print a[i]}'|sed 's/ //g' > $BKPTSDIR/Control.dir
	cat $BKPTSDIR/Control.dir

	rm -f $BKPTSDIR/Control.bkp.*
	sqlplus -S '/ as sysdba' <<USU
	set termout off
	set pages 0
	set lines 120
	set feedback off
	set trimspool on
	set head off
	alter database backup controlfile to trace;
	alter database backup controlfile to '$BKPTSDIR/Control.bkp';
	alter system switch logfile;
USU
	$ZIP $BKPTSDIR/Control.bkp.$EXT

	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- Fin Backup Control File..."
	echo
}

##############################################  PRINCIPAL ###############################################

# Ubicacion del shell bash en este sistema
BASHPATH=`which bash`
if [ -z "$BASHPATH" ]; then
	if [ ! -x /usr/local/bin/bash ]; then
		echo "ERROR: No se puede encontrar al interprete BASH."
		echo "       Saliendo..."
		exit 2 
	fi
fi

# Parametros del TAR
if [ "`uname -s`" = "SunOS" ]; then
	TARPARAM="chEvbf 2048 - " 						# tar de SUN Solaris
else
	TARPARAM="--preserve --same-owner -cvlf - " 	# tar de Linux
fi

# Utilizamos la compresion disponible
if [ "`uname -s`" = "Linux" ]; then
	ZIP='gzip -c'
	EXT='gz'
else
	ZIP='compress'
	EXT='Z'
fi

# Load de los Includes
BASEDIR=`dirname $0`
if [ ! -f $BASEDIR/../lib/lib_cpu.sh ]; then
	echo "ERROR: Este script requiere del include $BASEDIR/../lib/lib_cpu.sh."
	echo "       Saliendo..."
	exit 1
else
	if $DEBUG ; then
		echo "Cargando.. $BASEDIR/../lib/lib_cpu.sh"
	fi
	source $BASEDIR/../lib/lib_cpu.sh
fi

# Analizamos los parametros
if [ $# -eq 0 ];then
	echo "Uso `basename $0`: [-h][-c][-e][-a][-d <dir. de backup>]"
	echo
	exit 3
fi

while [ $# != 0 ]; do
	case x$1 in
		x-a)
			ARCHBACK=true
			;;
		x-e)	
			EXPORT=true
			;;
		x-h)
			HOT=true
			;;
		x-c)
			COLD=true
			ARCHBACK=false		# Se desactiva backup HOT de archives, ya que el cold lo incorpora.
			;;
		x-d)
			if [ $# = 1 -o ! -d $2 ]; then
				echo "Error: Falta argumento."
				exit 1
			fi
			BACKUPDIRP=$2
			shift
			;;
			
		x-*)
       		echo "Error: Parametro desconocido: $1"
			exit 1
			;;
	esac
	shift
done

LOG=Backup_$ORACLE_SID.`date +%d`.log
TMPLOG=Backup_$ORACLE_SID.`date +%d`.tmp$$.log
BKPLOGSDIR=$BACKUPDIRP/logs
[ ! -d $BKPLOGSDIR ] && mkdir -p $BKPLOGSDIR

# Todo al log temporario (Si $DEBUG = true)
$DEBUG || exec >>$BKPLOGSDIR/$TMPLOG 2>&1 </dev/null

echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::"
echo "::::: `date +'%d/%m/%Y - %H:%M:%S'` -- COMIENZO PROCESO BATCH de BACKUP"

##############################################
# Backup de archive logs
##############################################

if $ARCHBACK ; then

	# Creamos los directorios si no existen
	BACKUPDIR=$BACKUPDIRP/HOT
	BKPARCHDIR=$BACKUPDIR/ARCH

	[ ! -d $BKPARCHDIR ] && mkdir -p $BKPARCHDIR

	# Buscamos la ubicacion de los Archive LOGS
	ARCHDIR=$(sqlplus -S '/ as sysdba' <<SQL9
	set termout off
	set pages 0
	set lines 120
	set feedback off
	set trimspool on
	set head off
	
	select value from v\$parameter where name = 'log_archive_dest';
SQL9
)

	# Backup de Archive Logs
	echo
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- INICIO BACKUP de Archive Logs de $ARCHDIR.."

	# Fuerzo la rotacion del log y desactivo Archiving
	sqlplus -S '/ as sysdba'  <<SQL
	set termout off
	set pages 0
	set lines 120
	set feedback off
	set trimspool on
	set head off
	alter system switch logfile;
	alter system archive log current;
	archive log stop;
SQL

	tar $TARPARAM $ARCHDIR/*.arc | $ZIP > $BKPARCHDIR/ArchLog.tar.$EXT

	# Activo Archiving
	sqlplus -S '/ as sysdba' <<SQL
	set termout off
	set pages 0
	set lines 120
	set feedback off
	set trimspool on
	set head off
	archive log start;
SQL
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- FIN BACKUP de Archive Logs de $ARCHDIR.."
	echo
fi

##############################################
# HOT BACKUP
##############################################

if $HOT ; then

	# Creamos los directorios si no existen
	BACKUPDIR=$BACKUPDIRP/HOT
	BKPTSDIR=$BACKUPDIR/DATA
	[ ! -d $BKPTSDIR ] && mkdir -p $BKPTSDIR

	# Averiguamos los TABLESPACES
	TABLESPACES=$(sqlplus -S '/ as sysdba' <<SQL1
	set termout off
	set pages 0
	set lines 120
	set feedback off
	set trimspool on
	set head off

	select t.tablespace_name 
	from dba_tablespaces t, dba_data_files f
	where f.tablespace_name = t.tablespace_name
	and t.contents = 'PERMANENT'
	group by t.tablespace_name
	order by sum(f.bytes) desc;

SQL1
)
	# Comienzo ciclo de BACKUP
	ORDEN=0
	for TS in $TABLESPACES; do

		# Creo las unidades de trabajo para disparar al paralelismo.
		NOMBRE_UT="UT_$$_`printf %.3d $ORDEN`_$TS.sh"
		if $DEBUG ; then
			echo "::: Creando Unidad de Trabajo para el tablespace $TS (en /tmp/$NOMBRE_UT)"
		fi
		echo "#!$BASHPATH
#
# COMIENZO UNIDAD DE TRABAJO
# BACKUP del tablespace $TS.
# Creado por el script `basename $0`.
# ATENCION: Al finalizar el mismo, este archivo sera eliminado.
#

# DATAFILES que lo componen
DATAFILES=\"$(sqlplus -S '/ as sysdba' <<SQL2
set termout off
set pages 0
set lines 120
set feedback off
set trimspool on
set head off

select file_name from   sys.dba_data_files where  tablespace_name = '$TS';

SQL2
)\"

echo \":: \`date +'%d/%m/%Y - %H:%M:%S'\` -- INICIO Backup TABLESPACE $TS\"

# Pongo al TABLESPACE en BACKUP
sqlplus -S '/as sysdba' <<SQL3
set termout off
set pages 0
set lines 120
set feedback off
set trimspool on
set head off
alter tablespace $TS begin backup;
SQL3
rm -f ${BKPTSDIR}/ts_${TS}.dir
for i in \$DATAFILES; do
	echo \$i >> ${BKPTSDIR}/ts_${TS}.dir
done
		
tar $TARPARAM \$DATAFILES | $ZIP > ${BKPTSDIR}/${TS}.tar.$EXT

# Saco al TABLESPACE de BACKUP
sqlplus -S '/as sysdba' <<SQL3
set termout off
set pages 0
set lines 120
set feedback off
set trimspool on
set head off
alter tablespace $TS end backup;
SQL3
echo \":: \`date +'%d/%m/%Y - %H:%M:%S'\` --  FIN Backup TABLESPACE $TS\"

exit 0
# FIN UNIDAD DE TRABAJO
#########################
" 		> /tmp/$NOMBRE_UT
		chmod 700 /tmp/$NOMBRE_UT

		ORDEN=$(($ORDEN+1))
	done

	# Backup de Control Files
	BKP_control_files

	# Disparo la paralelizacion.
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- Cediendo el control al algoritmo paralelizador..."
	paralelo /tmp/UT_$$_*.sh
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- El algoritmo paralelizador devolvio el control..."
	echo

	if ! $DEBUG; then
		rm -f /tmp/UT_$$_*
		rm -f /tmp/corrida_paralela.$$.`date +'%d'`.log
	fi
fi

##############################################
# COLD Backup
##############################################

if $COLD ; then

	# Creamos los directorios si no existen
	BACKUPDIR=$BACKUPDIRP/COLD
	BKPTSDIR=$BACKUPDIR/DATA
	BKPARCHDIR=$BACKUPDIR/ARCH

	[ ! -d $BKPARCHDIR ] && mkdir -p $BKPARCHDIR
	[ ! -d $BKPTSDIR ] && mkdir -p $BKPTSDIR

	# Averiguamos los archives logs
	ARCHDIR=$(sqlplus -S '/ as sysdba' <<SQL9
	set termout off
	set pages 0
	set lines 120
	set feedback off
	set trimspool on
	set head off
	
	select value from v\$parameter where name = 'log_archive_dest';
SQL9
)

	# Averiguamos los TABLESPACES
	TABLESPACES=$(sqlplus -S '/ as sysdba' <<SQL1
	set termout off
	set pages 0
	set lines 120
	set feedback off
	set trimspool on
	set head off

	select t.tablespace_name 
	from dba_tablespaces t, dba_data_files f
	where f.tablespace_name = t.tablespace_name
	and t.contents = 'PERMANENT'
	group by t.tablespace_name
	order by sum(f.bytes) desc;

SQL1
)
	# Comienzo ciclo de BACKUP
	ORDEN=0
	for TS in $TABLESPACES; do

		# Creo las unidades de trabajo para disparar al paralelismo.
		NOMBRE_UT="UT_$$_`printf %.3d $ORDEN`_$TS.sh"
		if $DEBUG ; then
			echo "::: Creando Unidad de Trabajo para el tablespace $TS (en /tmp/$NOMBRE_UT)"
		fi
		echo "#!$BASHPATH
#
# COMIENZO UNIDAD DE TRABAJO
# BACKUP del tablespace $TS.
# Creado por el script `basename $0`.
# ATENCION: Al finalizar el mismo, este archivo sera eliminado.
#

# DATAFILES que lo componen
DATAFILES=\"$(sqlplus -S '/ as sysdba' <<SQL2
set termout off
set pages 0
set lines 120
set feedback off
set trimspool on
set head off

select file_name from sys.dba_data_files where tablespace_name = '$TS';

SQL2
)\"

echo \":: \`date +'%d/%m/%Y - %H:%M:%S'\` -- COMIENZO Backup TABLESPACE $TS\"

rm -f ${BKPTSDIR}/ts_${TS}.dir
for i in \$DATAFILES; do
	echo \$i >> ${BKPTSDIR}/ts_${TS}.dir
done
		
tar $TARPARAM \$DATAFILES | $ZIP > ${BKPTSDIR}/${TS}.tar.$EXT

echo \":: \`date +'%d/%m/%Y - %H:%M:%S'\` --  FIN Backup TABLESPACE $TS\"

exit 0
# FIN UNIDAD DE TRABAJO
#########################
"		> /tmp/$NOMBRE_UT
		chmod 700 /tmp/$NOMBRE_UT
		ORDEN=$(($ORDEN+1))
	done

	# Backup de Control Files
	BKP_control_files

	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- INICIO Shutdown IMMEDIATE la Base..."
	sqlplus -S '/ as sysdba' <<CHAU
	shutdown immediate;
CHAU
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- FIN Shutdown IMMEDIATE la Base..."
	echo

	# Resguardo en frio de ARCHIVE LOGS.
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- INICIO Backup de Archive Logs de $ARCHDIR.."
	tar $TARPARAM $ARCHDIR/*.arc | $ZIP > $BKPARCHDIR/ArchLog.tar.$EXT
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- FIN Backup de Archive Logs de $ARCHDIR.."
	echo

	# Borro archives.
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- INICIO Borrado archive logs de mas de $DIAS dias de antiguedad."
	for AL in `find $ARCHDIR -type f -mtime +${DIAS} -print 2>/dev/null`; do
		echo "Borrando $AL..."
		rm -f $AL
	done
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- FIN Borrado archive logs de mas de $DIAS dias de antiguedad."
	echo

	# Disparo la paralelizacion.
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- Cediendo el control al algoritmo paralelizador..."
	paralelo /tmp/UT_$$_*.sh
	#cat /tmp/corrida_paralela.$$.`date +'%d'`.log
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- El algoritmo paralelizador devolvio el control..."
	echo

	# Levanto la instancia
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- INICIO StartUp de la base (puede tomar un tiempo)..."

	sqlplus -S '/ as sysdba' <<CHAU
	startup;
CHAU

	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- FIN StartUp de la base..."
	echo 
	if ! $DEBUG; then
		rm -f /tmp/UT_$$_*
		rm -f /tmp/corrida_paralela.$$.`date +'%d'`.log
	fi

fi

##############################################
# EXPORT de la base
##############################################

if $EXPORT ; then

	# Creamos los directorios si no existen
	BACKUPDIR=$BACKUPDIRP
	BKPEXPDIR=$BACKUPDIR/EXP
	[ ! -d $BKPEXPDIR ] && mkdir -p $BKPEXPDIR

	ExpUsu=JANUS
	ExpPass=J4Nu5`date +%Y%m%d%H%M%S`$$

	echo		

	rm -f $BKPEXPDIR/$ORACLE_SID.dmp.log
	rm -f $BKPEXPDIR/$ORACLE_SID.pipe

	if $DEBUG ; then
		echo ":: Inicializo subsistema de compresión."
	fi
    
	mknod $BKPEXPDIR/$ORACLE_SID.pipe p		 
	chmod 750 $BKPEXPDIR/$ORACLE_SID.pipe
	compress -vc < $BKPEXPDIR/$ORACLE_SID.pipe > $BKPEXPDIR/$ORACLE_SID.dmp.Z &

	if $DEBUG ; then
		echo ":: Creando Usuario para EXPORT..."
	fi

	sqlplus -S '/ as sysdba' <<USU
	set termout off
	set pages 0
	set lines 120
	set feedback off
	set trimspool on
	set head off
	create user $ExpUsu identified by $ExpPass;
	alter user $ExpUsu identified by $ExpPass;
	grant connect,exp_full_database to $ExpUsu;
USU

	TMPF=/tmp/${ORACLE_SID}-export.$$
	echo $ExpUsu/$ExpPass >$TMPF
	chmod 700 $TMPF
			
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` - INICIO export de Oracle..."
	exp full=y file=$BKPEXPDIR/$ORACLE_SID.pipe RECORDLENGTH=1048576 CONSISTENT=y STATISTICS=NONE DIRECT=Y log=$BKPEXPDIR/$ORACLE_SID.dmp.log <$TMPF
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- FIN export de Oracle..."

	if $DEBUG ; then
		echo ":: Dropeando Usuario para EXPORT..."
	fi

	rm -f $TMPF

	sqlplus -S '/ as sysdba' <<USU
	set termout off
	set pages 0
	set lines 120
	set feedback off
	set trimspool on
	set head off
	alter user $ExpUsu identified by external;
	revoke connect,exp_full_database from $ExpUsu;
	drop user $ExpUsu;
USU

	rm -f $BKPEXPDIR/$ORACLE_SID.pipe
fi

# Elimino los Arch Log ANTIGUOS (de mas de $DIAS).
if $ARCHBACK ; then
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- INICIO Borrado archive logs de mas de $DIAS dias de antiguedad."
	for AL in `find $ARCHDIR -type f -mtime +${DIAS} -print 2>/dev/null`; do
		echo "Borrando $AL..."
		rm -f $AL
	done
	echo ":::: `date +'%d/%m/%Y - %H:%M:%S'` -- FIN Borrado archive logs de mas de $DIAS dias de antiguedad."
fi

if ! $DEBUG; then
	mv $BKPLOGSDIR/$TMPLOG $BKPLOGSDIR/$LOG 2> /dev/null
fi

echo 
echo "::::: `date +'%d/%m/%Y - %H:%M:%S'` -- FIN PROCESO BATCH de BACKUP"
echo ":::::::::::::::::::::::::::::::::::::::::::::::::::::::"

exit 0

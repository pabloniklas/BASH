##############################################
# Librerias de bajo nivel
# By Pablo Niklas - Bajo licencia GPL
##############################################

# paralelo(): Administrador de procesos paralelos
# By Pablo Niklas (pablo.niklas@gmail.com)
# Bajo Licencia GPL
#
# Uso: paralelo [<lista de procesos a disparar en forma concurrente>]
# Log de la corrida en /tmp/corrida_paralela.PID($$).<dia>.log
#
# Historico de cambios:
# 27/07/2006 - PSRN - Version Inicial.
# 28/07/2006 - PSRN - Agregado de logs.
#                     Reemplazo seq x myseq. ;)
# 29/07/2006 - PSRN - Autodeteccion de CPUs en Linux.
# 31/07/2006 - PSRN - Compatibilidad con Solaris y debugging.
# 01/08/2006 - PSRN - Autodeteccion de CPUs en Solaris 2.6 y 9.
# 05/08/2006 - PSRN - Anulacion de $DEBUG para que tome el del parent.
# 07/08/2006 - PSRN - $PARALELO se pasa por variable del parent.
# 27/08/2006 - PSRN - Se genera un log temporario para ver el avance en general del proceso.
#                     Se mejoro salida.
#

function paralelo() {

# PARALELO:
# Cantidad de procesos en paralelo.
# Depende de el SO y/o la arquitectura. Puede ser:
# 1) Cant. de cpus + 1 (x86)
# 2) Cant. de cpus * 2 (x86)
# 3) Cant. de cpus     (SPARC)
if [ -z "$PARALELO" ]; then
    if [ "`uname -s`"="SunOS" ]; then
        # Para SunOS...
        if [ "`uname -r`" = "5.6" ]; then
            PARALELO=`/usr/platform/`uname -m`/sbin/prtdiag -v|grep "US-"|wc -l`    # Solaris 2.6
        else
            if [ "`uname -r`" = "5.9" ]; then
                PARALELO=`/usr/platform/`uname -m`/sbin/prtdiag -v|grep ^CPU|wc -l`    # Solaris 9
            else
                PARALELO=1    # Default
            fi
        fi
    else
        PARALELO=$((`cat /proc/cpuinfo |grep ^proces|wc -l`*2)) # Linux
    fi
fi

# DIRLOG:
# Directorio donde se depositan los logs temporarios de cada hilo ejecutado.
DIRLOG="/tmp"
LOGCPU=$DIRLOG/control_corrida.$$.`date +'%d'`.log

############################ COMIENZO DEL ALGORITMO ################################

echo ":::: INICIO CORRIDA (`date +'%d/%m/%Y - %H:%M:%S'`)" >> $LOGCPU
echo ":::: Se correran $# procesos en total ($PARALELO en forma concurrente)." >> $LOGCPU

# Inicializo variables del sistema
I=0;SEQ=""
while [ $I -le $(($PARALELO-1)) ] ; do
    PID[$I]=0
    SEQ=$SEQ+"$I " # Como no tengo seq, lo genero :)
    I=$(($I+1))
done
SEQ=`echo $SEQ|sed 's/+//g'` # Depuro los "+"

TERMINO=false
JOBLOGTMP="job.$$.`date +'%d'`"
TAREA=0
while [ $# != 0 ] || ! $TERMINO; do
    A=0
    for A in $SEQ; do
        # Asigno procesos si tengo lugar.
        if [ ${PID[$A]} -eq 0 ] && [ $# != 0 ]; then
            TAREA=$(($TAREA+1))
            echo "::: Job #$TAREA - Thread #$A - `date +'%d/%m/%Y - %H:%M:%S'` - INICIADO." >> $DIRLOG/$JOBLOGTMP.`printf %.3d $TAREA`.log
            #echo ": COMIENZO detalle del Job." >> $DIRLOG/$JOBLOGTMP.`printf %.3d $TAREA`.log
            #echo $1 >> $DIRLOG/$JOBLOGTMP.`printf %.3d $TAREA`.log
            #echo ": FIN detalle del Job." >> $DIRLOG/$JOBLOGTMP.`printf %.3d $TAREA`.log
            #echo ": COMIENZO salida del Job." >> $DIRLOG/$JOBLOGTMP.`printf %.3d $TAREA`.log
            $1 1>> $DIRLOG/$JOBLOGTMP.`printf %.3d $TAREA`.log 2>&1 &
            PID[$A]=$!
            TID[$!]=$TAREA

            echo "::: Job #$TAREA - Thread #$A - `date +'%d/%m/%Y - %H:%M:%S'` - INICIADO."  >> $LOGCPU

            shift
        fi
        A=$(($A+1))
    done

    # Ciclo de control de finalizacion de cada hilo.
    TERMINO=true
    A=0
    for A in $SEQ; do

        # Los distintos *nix, manejan los procesos a su manera. :)
        FINALIZO=false
        if [ "`uname -s`" = "SunOS" ] && [ ${PID[$A]} -gt 0 ]; then
            [ -z "`ps -p ${PID[$A]}|grep -v "   PID TTY      TIME CMD"`" ] && FINALIZO=true
        fi

        if [ "`uname -s`" = "Linux" ] && [ ${PID[$A]} -gt 0 ]; then
            [ -z "`ps --no-heading --pid ${PID[$A]}`" ] && FINALIZO=true
        fi

        if $FINALIZO ; then
            #echo ": FIN salida del Job." >> $DIRLOG/$JOBLOGTMP.`printf %.3d ${TID[${PID[$A]}]}`.log
            echo "::: Job #${TID[${PID[$A]}]} - Thread #$A - `date +'%d/%m/%Y - %H:%M:%S'` - FINALIZADO." >> $DIRLOG/$JOBLOGTMP.`printf %.3d ${TID[${PID[$A]}]}`.log
            echo >> $DIRLOG/$JOBLOGTMP.`printf %.3d ${TID[${PID[$A]}]}`.log
            echo "::: Job #${TID[${PID[$A]}]} - Thread #$A - `date +'%d/%m/%Y - %H:%M:%S'` - FINALIZADO."  >> $LOGCPU
             cat $DIRLOG/$JOBLOGTMP.`printf %.3d ${TID[${PID[$A]}]}`.log
            echo >> $DIRLOG/$JOBLOGTMP.`printf %.3d ${TID[${PID[$A]}]}`.log
            PID[$A]=0
        fi

        # Salgo del ciclo principal si todas las tareas fueron hechas.
        if [ ${PID[$A]} -gt 0 ]; then
            TERMINO=false
            A=$(($PARALELO-1))
        fi

        A=$(($A+1))

    done
done

echo ":::: FIN CORRIDA (`date +'%d/%m/%Y - %H:%M:%S'`)" >> $LOGCPU

############################### FIN ALGORTIMO ################################

# Mergeo los archivos temporales en un solo log para toda la corrida
cat $DIRLOG/$JOBLOGTMP* > $DIRLOG/corrida_paralela.$$.`date +'%d'`.log
rm -f $DIRLOG/$JOBLOGTMP* $LOGCPU

}

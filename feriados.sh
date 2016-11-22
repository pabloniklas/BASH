#!/bin/bash
#
# Script de calculador de feriados trasladables
#
# 11/07/2008 - PSNR - Version Inicial.-
#

ANIO=$1

[ -z "$ANIO" ] && ANIO=`date +'%Y'`

function tercer_lunes {
MES=$1
# Calculo el tercer lunes del mes
for D in 01 02 03 04 05 06; do
	[ "`date --date \"$ANIO-$MES-$D\" +'%w'`" -eq 1 ] && DIA="$ANIO-$MES-$D"
done
FTL=`date --date "$DIA 14 days" +'%d/%m/%Y'`
}

# Ley Nº 24.445: Los feriados nacionales del 20 de junio y del 17 de agosto 
# se trasladan al tercer lunes del mes respectivo. 

# Paso a la Inmortalidad del General Manuel Belgrano (20/6)
tercer_lunes 06
echo "20/06;$FTL"

# Paso a la Inmortalidad del General José de San Martín (17/8)
tercer_lunes 08
echo "17/08;$FTL"

# Ley Nº 23.555: Las fechas que coincidan en martes y miércoles se trasladan 
# al lunes anterior; las que coincidan en jueves y viernes se trasladan al lunes posterior.

# Día de la Raza
MES=10
DOW="`date --date "$ANIO-$MES-12" +'%w'`"
DIA="12/$MES/$ANIO"
if [ $DOW -eq 2 ] || [ $DOW -eq 3 ]; then	# Martes o Miercoles
	for D in 12 11 10; do
		[ "`date --date \"$ANIO-$MES-$D\" +'%w'`" -eq 1 ] && DIA="$ANIO-$MES-$D"
	done
fi

if [ $DOW -eq 4 ] || [ $DOW -eq 5 ]; then	# Jueves o Viernes
	for D in 12 13 14 15 16; do
		[ "`date --date \"$ANIO-$MES-$D\" +'%w'`" -eq 1 ] && DIA="$ANIO-$MES-$D"
	done
fi
FDR=`date --date "$DIA" +'%d/%m/%Y'`
echo "12/10;$FDR"

# Feriados inamovibles.-
for D in 01/01 24/03 21/03 02/04 01/05 25/05 09/07 08/12 25/12; do
	echo "$D;$D/$ANIO"
done

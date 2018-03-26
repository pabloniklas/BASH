#!/bin/bash
#
# Script implementador de marca de agua.
# By Pablo Niklas
#

function Reducir {

    # Ojo que no pasa la informacion EXIF, hay que reescribirla.
    exit -1

    echo -n "  Reduciendo a resolucion HD..."
    X_IMAGE=`identify -format %w "$1"`
    Y_IMAGE=`identify -format %h "$1"`

    if [ $X_IMAGE -gt $Y_IMAGE ]; then
        # Landscape
        echo -n "Landscape..."
        convert $1 -resize 1920x1080 $1
        RC=$?; echo "RC=$RC"
    else
        # Portrait
        echo -n "Portrait..."
        convert $1 -resize 1080x1920 $1
        RC=$?; echo "RC=$RC"
    fi
}

function TransferirEXIF {

    # Transferir los EXIF - http://ninedegreesbelow.com/photography/exiftool-commands.html
    echo -n "  Transfiriendo informacion EXIF..."
    exiftool -tagsfromfile "$1" -all:all -r -overwrite_original "$2" >/dev/null
    RC=$?; echo "RC=$RC"
}

function MarcaAgua {

    COLORSPACE="sRGB"

    IMAGE="$1"
    echo "Procesando imagen $IMAGE:"
    NAME=`echo "$IMAGE" | cut -f1 -d.`
    EXT=`echo "$IMAGE" | cut -f2 -d.`

    if [ $EXT=="CR2" ]; then
        EXT="png"       #PNG soporta transparencias.
    fi

    X_IMAGE=`identify -format %w "$IMAGE"`
    Y_IMAGE=`identify -format %h "$IMAGE"`

    echo "  Resolucion: $X_IMAGE x $Y_IMAGE"
    echo -n "  Generando banda de marca de agua..."

  	#convert -size ${X_IMAGE}x${Y_IMAGE} xc:transparent -colorspace $COLORSPACE -fill '#0008' \
  	#	-draw "rectangle 0,$Y_IMAGE $X_IMAGE,$(($Y_IMAGE-$Y_WM-5))" "/tmp/$IMAGE.$$.1.$EXT"
    convert -size ${X_IMAGE}x${Y_IMAGE} xc:transparent -colorspace $COLORSPACE -fill '#0008' \
    	-draw "rectangle 0,$Y_IMAGE $X_IMAGE,$(($Y_IMAGE-$Y_WM-5))" "/tmp/$IMAGE.$$.1.$EXT"
    RC=$?; echo "RC=$RC"
    if [ $RC -ne 0 ]; then
        exit $RC
    fi

    composite -dissolve 90% -gravity $DONDE -quality 100 -colorspace $COLORSPACE \( $WM -resize $SCALE% \) \
    	"/tmp/$IMAGE.$$.1.$EXT" "/tmp/$IMAGE.$$.2.$EXT"
    RC=$?; echo "RC=$RC"
    if [ $RC -ne 0 ]; then
        exit $RC
    fi
    echo -n "  Estampando marca de agua..."
    composite -gravity center -colorspace $COLORSPACE -quality 100 "/tmp/$IMAGE.$$.2.$EXT" \
    	"$IMAGE" "${NAME}_$MP.${EXT}"
    RC=$?; echo "RC=$RC"
    if [ $RC -ne 0 ]; then
        exit $RC
    fi

    TransferirEXIF "$IMAGE" "${NAME}_$MP.${EXT}"

    convert "${NAME}_$MP.${EXT}" "${NAME}_$MP.jpg"
    TransferirEXIF "${NAME}_$MP.${EXT}" "${NAME}_$MP.jpg"

    rm -f "/tmp/$IMAGE.$$.2.$EXT" "/tmp/$IMAGE.$$.1.$EXT" "${NAME}_$MP.${EXT}"
}

# Inicializo
#WM=/u02/Gimp/MarcasDeAgua/Watermark01.png
WM=/u02/Gimp/MarcasDeAgua/Watermark02.png
SCALE=100

# Marca de procesamiento
MP="pn"

# Posicion de la marca de agua: http://www.imagemagick.org/script/command-line-options.php#gravity
# NorthWest, North, NorthEast, West, Center, East, SouthWest, South, SouthEast
DONDE=SouthEast

# Resolucion de la marca de agua
X_WM=`identify -format %w $WM`
X_WM=`echo $X_WM*$SCALE/100 | bc`

Y_WM=`identify -format %h $WM`
Y_WM=`echo $Y_WM*$SCALE/100 | bc`

echo "Info de la marca de agua ($WM) ===> $X_WM x $Y_WM (Escala $SCALE%)"

# Bucle principal
if [ -z "$1" ]; then
    echo "AVISO: No se especificaron archivos. Se procesaran todos los que se encuentren en el directorio."

    file -i * | grep image | awk -F':' '{ print $1 }' | grep -v _$MP.* | while read IMAGE;  do
 #       Reducir $IMAGE
        MarcaAgua $IMAGE
    done
    exit 0
else
#    Reducir $1
    MarcaAgua $1
fi

# Para evaluar mas adelante.
# convert -border 11x10 -bordercolor "#FFFFFF" Flores\ macro.png Flores\ macro_borde.png
# convert -font TerminalDosis-Medium.otf -pointsize 100 -background "#000000C0" -fill white -gravity SouthEast -size 800 -direction left-to-right label:@text.txt input.jpg +swap -composite output.jpg



#!/bin/bash
#
# split mosaic image in individual CCDs using
# sequentially imcopy (single threaded version of imcopy)
#
# imcopy - http://stsdas.stsci.edu/cgi-bin/gethelp.cgi?imcopy
# 
# (c) 2017 - Juan Carlos Maureira / Center for Mathematical Modeling

exist_file() {
    [ -f $1 ]
}

exist_dir() {
    [ -d $1 ]
}

get_header() {
    $BIN_GETHEAD -x $2 $1 $3
}

get_binary() {
    BIN=`whereis $1 | cut -f 2 -d":" | xargs`
    if ! exist_file $BIN; then 
        echo "$1 not found"
        exit 1 
    fi
    echo "$BIN"
}

usage() { 
    echo "Usage: $0 -i mosaic.fits.fz -o output_dir [ -c -f ]"
    echo "  -c : write compressed fits (fits.fz)"
    echo "  -f : overwrite output fits if they already exist"
    exit 1
}

COMPRESSED=0
OVERWRITE=0

while getopts ":i:o:cf" o; do
    case "${o}" in
        i)
            MOSAIC_IMAGE="${OPTARG}"
            ;;
        o)
            OUTPUT_DIR="${OPTARG}"
            ;;
        c)
            COMPRESSED=1
            ;;
        f)
            OVERWRITE=1
            ;;
        h | *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "$MOSAIC_IMAGE" ] || [ -z "$OUTPUT_DIR" ];then
    usage
fi

# check inputs and outputs
if ! exist_file $MOSAIC_IMAGE; then
    echo "Mosaic image $MOSAIC_IMAGE not found"
    exit 1
fi

if ! exist_dir $OUTPUT_DIR; then
    echo "Output directory does not exist. creating it"
    mkdir -p $OUTPUT_DIR
fi

# split image
BIN_IMCOPY=`get_binary imcopy`
BIN_GETHEAD=`get_binary gethead`

NUM_CCDS=`get_header $MOSAIC_IMAGE 0 NEXTEND`
OBJECT=`get_header $MOSAIC_IMAGE 0 OBJECT`
MJD=`get_header $MOSAIC_IMAGE 0 MJD-OBS`
PROD_TYPE=`get_header $MOSAIC_IMAGE 0 PRODTYPE`

EXT=`[ $COMPRESSED -eq 1 ] && echo "fits.fz" || echo "fits"`
CMP=`[ $COMPRESSED -eq 1 ] && echo "[compressed]" || echo ""`

if [ $NUM_CCDS -gt 0 ]; then
    for ccd_num in `seq 1 $NUM_CCDS`;
    do
        CCD_NAME=`get_header $MOSAIC_IMAGE $ccd_num EXTNAME`
        CCD_FILENAME=`printf "%s_%s_%s_%s.%s" $OBJECT $CCD_NAME $MJD $PROD_TYPE $EXT`

        if [ $OVERWRITE -eq 1 ]; then
            [ -f $OUTPUT_DIR/${CCD_FILENAME} ] && rm $OUTPUT_DIR/${CCD_FILENAME}
        fi
        echo "extracting $CCD_FILENAME"

        $BIN_IMCOPY $MOSAIC_IMAGE[$ccd_num] $OUTPUT_DIR/${CCD_FILENAME}$CMP
        EXIT_CODE=$?

        if [ $EXIT_CODE -ne 0 ]; then
            echo "pimcopy exit with error code $EXIT_CODE"
            exit $EXIT_CODE
        fi

    done
else
    echo "No CCDs found in $MOSAIC_IMAGE. NEXTEND=$NUM_CCDS"
    exit 1
fi

echo "done"

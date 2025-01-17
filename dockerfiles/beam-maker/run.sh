#!/bin/bash

# OBSID/BEG_END/ch/PTHEAD_PTTAIL
m=$1
# m="1257010784/1257010986_1257011185/132/00001_00003"
my_arr=($(echo $m | tr "_" "\n" | tr "/" "\n"))
OBSID=${my_arr[0]}
BEG=${my_arr[1]}
END=${my_arr[2]}
ch=${my_arr[3]}
PTHEAD=${my_arr[4]}
PTTAIL=${my_arr[5]}
let ii=$((10#${ch}))-108
printf -v i "%02d" $ii

# 加载UTT等元数据信息
source ${DIR_CAL}/${OBSID}/mb_meta.env

echo UTT=${UTT}
# UTT=2019-11-05T17:43:25.00
# PTLIST=${BASEDIR}/1257010784_grid_positions_f0.85_d0.3098_l102.txt
PTLIST=${DIR_CAL}/${OBSID}/pointings.txt
POINTS=$(awk "NR>=${PTHEAD} && NR<=${PTTAIL} {printf \"%s\", \$0; if (NR!=${PTTAIL}) printf \",\"}" ${PTLIST})

cd /work
make_beam -o ${OBSID} -b ${BEG} -e ${END} \
        -P ${POINTS} \
        -z ${UTT} \
        -d ${DIR_DAT}/${OBSID} -f ${ch} \
        -m ${DIR_CAL}/${OBSID}/metafits_ppds.fits \
        -F ${DIR_CAL}/${OBSID}/flagged_tiles.txt \
        -J ${DIR_CAL}/${OBSID}/DI_JonesMatrices_node0${i}.dat \
        -B ${DIR_CAL}/${OBSID}/BandpassCalibration_node0${i}.dat \
        -t 6000 -W 10000 -s 
code=$?
[[ $code -ne 0 ]] && echo exit after make_beam, error_code:$code && exit $code

# 将生成的fits文件转移到规范目录下
declare -i i=0
point_arr=($(echo $POINTS | tr "," "\n" ))
for ii in $(seq $PTHEAD $PTTAIL);
do
    pi=$(printf "%05d" $ii)
    dest_file_r=${OBSID}/${BEG}_${END}/${pi}/ch${ch}.fits
    dest_file=${DIR_1CH}/${dest_file_r}
    orig_file=/work/${point_arr[${i}]}/*.fits

    mkdir -p $(dirname ${dest_file}) && mv $orig_file $dest_file
    code=$?
    [[ $code -ne 0 ]] && echo "exit after mkdir and mv, dest_file:$dest_file, error_code:$code" && exit $code
    # 输出消息 
    echo $dest_file_r >> /work/messages.txt
    # 统计输出文件的字节数
    echo $dest_file >> /work/output-files.txt

    i=$((i + 1))
done

# 统计输入文件的总字节数
num_points=${#point_arr[@]}
num_files=$(expr "$END" - "$BEG")
file_length=327680000
input_bytes=$(( (num_files+1) * file_length * num_points ))
echo '{
    "inputBytes":'${input_bytes}'
}' > /work/task-exec.json

exit $code

# author: David Fager s185120
#!/bin/zsh

# Global variables
absolute_path=""
files=()
images=()
path_collected_results="analysis-collected-results.out"

# Asks if the user has set everything up
echo "Before continuing, please make sure that you have done the following:"
echo "Necessary steps:"
echo " - Replaced this project's image.c file with the one in darknets src folder."
echo " - Compiled (with 'make') the darknet project with gpu=1, cudnn=1 and opencv=0."
echo " - Backed up any important files in your darknet directory."
echo " - Downloaded and unzipped the test-files and test-images folders into the darknet directory."
echo "   Link: -"
echo "Recommended steps:"
echo " - Placed this project in the same directory as darknet, so they share the same directory."
echo " - Got your own weights or images? Then add them to the test-files or test-images folder, with"
echo "   a .txt file describing contents or the .cfg file. Exactly like the other files in the folders."
echo "\nContinue?\n(y/n)"
read answer && [ "${answer}" = "y" ] || exit

# Looks for the darknet directory and enters it
[ -e "../darknet" ] && absolute_path="../darknet" && echo "Darknet folder found."
[ ! -e "../darknet" ] && echo "Please specify the absolute path to darknet:" && read absolute_path
[ ! -e ${absolute_path} ] && echo "Error in darknet path" && exit
echo "" && cd ${absolute_path} && echo "Entered the darknet directory. ($( pwd ))"

# Getting unique names of the test-files folder contents and makes an array for each
[ ! -e "test-files" ] && echo "Failed to find the test-files directory" && exit
cd test-files && find . -name '*.weights' | cut -d "." -f 2 | cut -d "/" -f 2 | sort > 0contents.txt && cd ..
while IFS= read -r line; do
    files+=("$line")
done < test-files/0contents.txt
echo "Loaded array: ${files[*]}"

# Getting unique names of the test-images folder contents and makes an array for each
[ ! -e "test-images" ] && echo "Failed to find the test-images directory" && exit
cd test-images && (find . -name '*.png' && find . -name '*.jpg') | cut -d "." -f 2 | cut -d "/" -f 2 | sort > 0contents.txt && cd ..
while IFS= read -r line; do
   images+=("$line")
done < test-images/0contents.txt
echo "Loaded array: ${images[*]}"

# Make the test-output directory
[ -e "test-output" ] && rm -rf test-output
mkdir test-output && echo "Created a test-output directory."

# Warm up the darknet detector
echo "Running a darknet warmup with weights ${files[1]} and image ${images[1]}"
[ -e "test-images/${images[1]}.png" ] && ./darknet detector test cfg/owndata.data test-files/${files[1]}.cfg test-files/${files[1]}.weights test-images/${images[1]}.png
[ -e "test-images/${images[1]}.jpg" ] && ./darknet detector test cfg/owndata.data test-files/${files[1]}.cfg test-files/${files[1]}.weights test-images/${images[1]}.jpg

echo "---------- collected analysis results ----------" > ${path_collected_results}
for weight_name in ${files[*]}; do
    # Weights specific variables
    exec_time=0.0
    avg_percent=0.0
    avg_count=0
    found_cards=0
    total_cards=0
    total_corners=0
    corners_correct=0
    corners_wrong=0
    corners_missed=0

    # Weights specific paths
    path_file_cfg="test-files/${weight_name}.cfg"
	path_file_weights="test-files/${weight_name}.weights"

    for image_name in ${images[*]}; do
        # Image specific paths
        path_image=""
        path_image_txt="test-images/${image_name}.txt"
        path_result="test-output/${weight_name}-${image_name}.out"
        path_result_full="test-output/${weight_name}-${image_name}-separated.out"
    	path_result_percentages="test-output/${weight_name}-${image_name}-percents.out"
        path_result_detections="test-output/${weight_name}-${image_name}-detections.out"

        # Is image png or jpg
        [ -e "test-images/${image_name}.png" ] && path_image="test-images/${image_name}.png"
        [ -e "test-images/${image_name}.jpg" ] && path_image="test-images/${image_name}.jpg"
        [ ! -e "${path_image}" ] && echo "Error with path_image" && exit

        # Darknet detection
        echo "" && echo "performing analysis with '${weight_name}' on '${path_image}'"
        start_time=$(date +%s.%N)
        ./darknet detector test cfg/owndata.data ${path_file_cfg} ${path_file_weights} ${path_image} > ${path_result}
        end_time=$(date +%s.%N)
        exec_time=$(( ${exec_time} + (${end_time} - ${start_time}) ))

        sed -i '1d' ${path_result}
        total_corners=$(( ${total_corners} + $(cat ${path_image_txt} | wc -l) ))

        # Handle multiple guesses
        while read unseparated; do
            spaces=$(echo "${unseparated}" | grep -o ' ' | wc -l)
            val1=$(echo "${unseparated}" | cut -d " " -f $(( ${spaces} - 2 )))
            val2=$(echo "${unseparated}" | cut -d " " -f $(( ${spaces} - 1 )))
            val3=$(echo "${unseparated}" | cut -d " " -f $(( ${spaces} + 0 )))
            val4=$(echo "${unseparated}" | cut -d " " -f $(( ${spaces} + 1 )))
            spaces=$(( ${spaces} - 3 ))

            index=1
            while  [ ${index} -lt ${spaces} ]; do
                guess=$(echo "${unseparated}" | cut -d " " -f ${index})
                percent=$(echo "${unseparated}" | cut -d " " -f $(( ${index} + 1)))
                echo "${guess} ${percent} ${val1} ${val2} ${val3} ${val4}" >> ${path_result_full}
                index=$(( ${index} + 2 ))
            done
        done < ${path_result}

        # Add all detected percentages and count detected corners
        cat ${path_result_full} | cut -d " " -f 2 | cut -d "%" -f 1 > ${path_result_percentages}
        while read percentage; do
            avg_percent=$(( ${avg_percent} + ${percentage} ))
        done < ${path_result_percentages}
        avg_count=$(( ${avg_count} + $(cat ${path_result_percentages} | wc -l) ))

        total_cards=$(( ${total_cards} + $(cat ${path_image_txt} | cut -d " " -f 1 | sort | uniq | wc -l) ))

        # Properly count correct and wrong guesses
        while read actual; do
            actual_card=$(echo "${actual}" | cut -d " " -f 1)
            actual_centerX=$(( 1920.0 / 100.0 * $(echo "${actual}" | cut -d " " -f 2) * 100.0 ))
            actual_centerY=$(( 1080.0 / 100.0 * $(echo "${actual}" | cut -d " " -f 3) * 100.0 ))
            actual_width=$(( 1920.0 / 100.0 * $(echo "${actual}" | cut -d " " -f 4) * 100.0 ))
            actual_height=$(( 1080.0 / 100.0 * $(echo "${actual}" | cut -d " " -f 5) * 100.0 ))

            act_x_left=$(( ${actual_centerX} - (${actual_width} / 2.0) ))
            act_x_left=${act_x_left%.*}
            act_x_right=$(( ${actual_centerX} + (${actual_width} / 2.0) ))
            act_x_right=${act_x_right%.*}

            act_y_top=$(( ${actual_centerY} - (${actual_height} / 2.0) ))
            act_y_top=${act_y_top%.*}
            act_y_bottom=$(( ${actual_centerY} + (${actual_height} / 2.0) ))
            act_y_bottom=${act_y_bottom%.*}

            correct_before=${corners_correct}
            wrong_before=${corners_wrong}

            while read detected; do
                det_center_x=$(( $(echo "${detected}" | cut -d " " -f 3) + ($(echo "${detected}" | cut -d " " -f 5) - $(echo "${detected}" | cut -d " " -f 3)) / 2 ))
                det_center_y=$(( $(echo "${detected}" | cut -d " " -f 6) + ($(echo "${detected}" | cut -d " " -f 4) - $(echo "${detected}" | cut -d " " -f 6)) / 2 ))

                if [ ${det_center_x} -gt ${act_x_left} ] && [ ${det_center_x} -lt ${act_x_right} ] && [ ${det_center_y} -gt ${act_y_top} ] && [ ${det_center_y} -lt ${act_y_bottom} ]; then
                    if [ "${actual_card}" = "$(echo "${detected}" | cut -d " " -f 1)" ]; then
                        corners_correct=$(( ${corners_correct} + 1 ))
                    else
                        corners_wrong=$(( ${corners_wrong} + 1 ))
                    fi
                    echo "${detected}" | cut -d " " -f 1 >> ${path_result_detections}
                fi
            done < ${path_result_full}

            [ ${corners_correct} -eq ${correct_before} ] && [ ${corners_wrong} -eq ${wrong_before} ] && corners_missed=$(( ${corners_missed} + 1 ))

        done < ${path_image_txt}

        found_cards=$(( ${found_cards} + $(cat ${path_result_detections} | sort | uniq | wc -l) ))

        #[ "${image_name}" = "${images[4]}" ] && break # REMOVE THE COMMENT TO DEBUG
    done

    avg_percent=$(( ${avg_percent} / ${avg_count} ))
    exec_time=$(( ${exec_time} / ${#images[@]} ))

    # Adding this weights results to the results file
    printf "${weight_name} results:\n" >> ${path_collected_results}
    printf "darknet detection time %.2fs\n" "${exec_time}" >> ${path_collected_results}
    printf "average percent ...... %.2f%%\n" "${avg_percent}" >> ${path_collected_results}
    printf "cards found .......... %d / %d (%.2f%%)\n" "${found_cards}" "${total_cards}" "$(( ${found_cards}.0 / ${total_cards}.0 * 100.0))" >> ${path_collected_results}
    printf "correct corners ...... %d / %d (%.2f%%)\n" "${corners_correct}" "${total_corners}" "$(( ${corners_correct}.0 / $total_corners.0 * 100.0 ))" >> ${path_collected_results}
    printf "wrong corners ........ %d / %d (%.2f%%)\n" "${corners_wrong}" "${total_corners}" "$(( ${corners_wrong}.0 / $total_corners.0 * 100.0 ))" >> ${path_collected_results}
    printf "missed corners ....... %d / %d (%.2f%%)\n" "${corners_missed}" "${total_corners}" "$(( ${corners_missed}.0 / $total_corners.0 * 100.0 ))" >> ${path_collected_results}
    printf "\n" >> ${path_collected_results}
    cat ${path_collected_results} | tail -8

done

# Printing everything calculated
clear
cat ${path_collected_results}

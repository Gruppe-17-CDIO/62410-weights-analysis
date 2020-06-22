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
echo " - Compiled (with 'make') the darknet project with gpu=1, cudnn=1 and opencv=0"
echo " - Backed up any important files in your darknet directory"
echo " - Downloaded and unzipped the test-files and test-images files into the darknet directory."
echo "   Link: https://drive.google.com/file/d/1jrqQi3YgKfDs7x58z_3cxXpseI7dJgDM/view"
echo "Recommended steps:"
echo " - Placed this project in the same directory as darknet, so they share the same directory"
echo " - Got your own weights or images? Then add them to the test-files or test-images folder, with"
echo "   a .txt file describing contents or the .cfg file. Exactly like the other files in the folders."
echo "\nContinue\n(y/n)"
read answer && [ "${answer}" = "y" ] || exit

# Looks for the darknet directory and enters it
[ -e "../darknet" ] && absolute_path="../darknet" && echo "Darknet folder found."
[ ! -e "../darknet" ] && echo "Please specify the absolute path to darknet:" && read absolute_path
[ ! -e ${absolute_path} ] && echo "Error in darknet path" && exit
echo "" && cd ${absolute_path} && echo "Entered the darknet directory. ($( pwd )))"

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
#images=("all-clubs") # outcomment for debugging
echo "Loaded array: ${images[*]}"

# Make the test-output directory
[ -e "test-output" ] && rm -rf test-output
mkdir test-output && echo "Created a test-output directory."

# Warm up the darknet detector
echo "Running a darknet warmup" && ./darknet detector test cfg/owndata.data test-files/v3-retrained.cfg test-files/v3-retrained.weights test-images/overlaying-clubs-diamonds.png

echo "---------- collected analysis results ----------" > ${path_collected_results}
for weight_name in ${files[*]}; do
    # Weights specific variables
    exec_time=0.0
    avg_percent=0.0
    total_corners=0
    total_cards=0
    guesses_cards=0

    # Weights specific paths
    path_file_cfg="test-files/${weight_name}.cfg"
	path_file_weights="test-files/${weight_name}.weights"

    for image_name in ${images[*]}; do
        # Image specific paths
        path_image=""
        path_image_txt="test-images/${image_name}.txt"
        path_result_full="test-output/${weight_name}-${image_name}.out"
    	path_result_percentages="test-output/${weight_name}${image_name}-percents.out"
        path_result_detections="test-output/${weight_name}-${image_name}-detections.out"

        # Is image png or jpg
        [ -e "test-images/${image_name}.png" ] && path_image="test-images/${image_name}.png"
        [ -e "test-images/${image_name}.jpg" ] && path_image="test-images/${image_name}.jpg"
        [ ! -e "${path_image}" ] && echo "Error with path_image" && exit

        # Darknet detection
        echo "" && echo "performing analysis with '${weight_name}' on '${path_image}'"
        start_time=$(date +%s.%N)
        ./darknet detector test cfg/owndata.data ${path_file_cfg} ${path_file_weights} ${path_image} > ${path_result_full}
        end_time=$(date +%s.%N)
        exec_time=$(( ${exec_time} + (${end_time} - ${start_time}) ))

        # Add all detected percentages and count detected corners
        cat ${path_result_full} | cut -d " " -f 2 | cut -d "%" -f 1 | sed '1d' > ${path_result_percentages}
        while read percentage; do
            avg_percent=$(( ${avg_percent} + ${percentage} ))
        done < ${path_result_percentages}
        total_corners=$(( ${total_corners} + $(cat ${path_result_percentages} | wc -l) ))

        # Count number of guesses
        guesses_cards=$(( ${guesses_cards} + $(cat ${path_result_full} | cut -d " " -f 1 | cut -d ":" -f 1 | sed '1d' | uniq | wc -l) ))

        total_cards=$(( ${total_cards} + $(cat ${path_image_txt} | uniq | wc -l) ))

    done

    avg_percent=$(( ${avg_percent} / ${total_corners} ))
    exec_time=$(( ${exec_time} / ${#images[@]} ))

    # Adding this weights results to the results file
    printf "${weight_name} results:\n" >> ${path_collected_results}
    printf "darknet detection time %.2fs\n" "${exec_time}" >> ${path_collected_results}
    printf "average percent ...... %.2f%%\n" "${avg_percent}" >> ${path_collected_results}
    printf "detections ........... %s (%.2f%%)\n" "${guesses_cards} / ${total_cards}" "$(( ${guesses_cards}.0/${total_cards}.0*100.0 ))" >> ${path_collected_results}
    printf "\n" >> ${path_collected_results}

done

echo "darknet detection time: average of how fast darknet loaded the weights and detected on the image" >> ${path_collected_results}
echo "average percent ......: average of darknets percent certainty it found a given card" >> ${path_collected_results}
echo "detections ...........: how many cards darknet detected out of how many cards were in the image" >> ${path_collected_results}

# Printing everything calculated
clear
cat ${path_collected_results}

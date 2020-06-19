# author: David Fager s185120
#!/bin/zsh

weights=("v3-tiny-14200" "v3-tiny-17600" "v3-tiny-18500" "v3-tiny-20000" \
"v3-tiny-21000" "v3-tiny-22000" "v3-retrained")

images=("all-clubs" "all-diamonds" "all-hearts" "all-spades" \
"overlaying-clubs-diamonds" "overlaying-spades-hearts" \
"solitaire-chaotic-nomove-nodeck" "solitaire-neat-nomove-nodeck" \
"solitaire-simple-nomove-nodeck")


# Find the darknet folder
if [ "$(basename $PWD)" = "darknet" ]; then
	echo "Found the darknet folder. It is the current directory."
elif [ -d "darknet" ]; then
	cd darknet && echo "Found the darknet folder. Entering." \
    || echo "Unable to enter the darknet folder."
else
	echo "Failed to find the darknet folder. Put this script in the same \
    directory where darknet is or inside the darknet folder."
fi


# Make or remake the test-results directory
if [ -d "test-results" ]; then
	rm -rf test-results && echo "Removed the test-results directory."
fi
mkdir test-results && echo "Created the test-results directory."


path_collected_results="test-results/analysis-collected-results.out"

# Data analysis loop, goes through each image for each weights file
for weight_name in ${weights[*]}; do

    # Each weights file's average guessing percentage
    avg_percent=0.0
    possible_detections=0
    actual_detections=0
    darknet_exec_time=0.0

    # The paths of existing files and result saving destination
    path_file_cfg="test-files/${weight_name}.cfg"
	path_file_weights="test-files/${weight_name}.weights"
	path_result_percentages="test-results/${weight_name}-percents.txt"


    echo "Performin analysis on ${weight_name}"

    # Looping through each image for the current weights file
    for image_name in ${images[*]}; do

        # Path of image and results destinations
        path_image_png="test-images/${image_name}.png"
        path_image_txt="test-images/${image_name}.txt"
        path_result_full="test-results/${weight_name}-${image_name}.out"
        path_result_cards="test-results/${weight_name}-${image_name}-cards.txt"


        # Darknet performing its detection and saving the output
        start_time=$(date +%s.%N)
        ./darknet detector test cfg/owndata.data ${path_file_cfg} \
        ${path_file_weights} ${path_image_png} > ${path_result_full}
        end_time=$(date +%s.%N)
        echo "${end_time} - ${start_time} = $((end_time - start_time))"
        darknet_exec_time=$(($darknet_exec_time + (end_time - start_time)))


        # Taking the output and trimming it to the percentage integer
        # and appending it to a percentage file
		cat ${path_result_full} | cut -d " " -f 2 | cut -d "%" -f 1 | sed '1d' \
        >> ${path_result_percentages}

        # Trimming output to only consist of the card values and suits
        cat ${path_result_full} | cut -d " " -f 1 | cut -d ":" -f 1 | sed '1d' \
        >> ${path_result_cards}


        # Find how many detections should have occured at max
        possible_detections=$(( $possible_detections + \
        $(cat ${path_image_txt} | wc -l) ))

        # TODO: do a proper check of actual detections
        actual_detections=$(( $actual_detections + \
        $(cat ${path_result_cards} | wc -l) ))

        while read possible; do
            echo "${possible}"
        done < $(sort ${path_image_txt} | uniq)


        # Print this image's sum of possible_detections and actual_detections
        echo "Found ${actual_detections}/${possible_detections} (~ $((\
        ${actual_detections}.0/${possible_detections}.0))%)"

    done

    # Saving the average execution time of darknet
    twodecimals=$((${darknet_exec_time} / ${#images[@]})) \
    && echo "Darknet average detection execution time:\t${twodecimals}" \
    >> ${path_collected_results}


    # Goes through the whole percentage file for the current weights file,
    # calculates the average percentage and appends it to the percentage file
	while read percentage; do
        avg_percent=$(( $avg_percent + $percentage ))
    done < ${path_result_percentages}

    avg_percent=$(( $avg_percent / $(cat ${path_result_percentages} | wc -l) ))
    twodecimals=$(printf '%.2f' "${avg_percent}") # rounds to two decimals
    echo "Average detection percentage: ${twodecimals}%" \
    && echo "${weight_name} average detection percentage:\t${twodecimals}%" \
    >> ${path_collected_results}


    # Save how many actual detection occured out of possible detections
    twodecimals=$(printf '%.2f' \
    "$((${actual_detections}.0/${possible_detections}.0))") \
    && echo "${weight_name} correctly detected ${actual_detections}\
    /${possible_detections} (~ ${twodecimals}%)"


    echo "" >> ${path_collected_results}
done


# Printing the results by reading the last line of each percentage file
clear
echo "Collected results:"
while read result; do
    echo "${result}"
done < ${path_collected_results}

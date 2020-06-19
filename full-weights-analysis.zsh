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
    # Looking for the darknet outside the current directory
    cd ..
    if [ -d "darknet" ]; then
        cd darknet && \
        echo "Found the darknet folder outside the current directory. Entering"
    else
        echo "Failed to find the darknet folder. Put this script in the same \
        directory where darknet is or inside the darknet folder."
    fi
fi


# Make or remake the test-results directory
if [ -d "test-results" ]; then
	rm -rf test-results && echo "Removed the test-results directory."
fi
mkdir test-results && echo "Created the test-results directory."


path_collected_results="test-results/analysis-collected-results.out"

# Data analysis loop, goes through each image for each weights file
for weight_name in ${weights[*]}; do

    # Each weights file's results initialisation
    darknet_exec_time=0.0
    avg_percent=0.0

    number_of_cards=0
    possible_detections=0
    hits=0
    guesses=0
    misses=0
    ignored=0


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
        echo "Execution time $((end_time - start_time)) seconds"
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

        # Find how many correct guesses it had and how many wrong
        guesses=$(( ${guesses} + $(cat ${path_result_cards} | wc -l) ))
        sort ${path_image_txt} | uniq > temp_sorted_actual.txt
        sort ${path_result_cards} | uniq > temp_sorted_detected.txt

        while read possible; do
            hits=$(( ${hits} + $(cat ${path_result_cards} | grep ${possible} | wc -l) ))
            sed -i "/${possible}/d" ${path_result_cards}
        done < temp_sorted_actual.txt
        misses=$(( ${misses} + $(cat ${path_result_cards} | wc -l) ))

        number_of_cards=$(( ${number_of_cards} + $(cat temp_sorted_actual.txt | wc -l) ))
        while read detection; do
            sed -i "/${detection}/d" temp_sorted_actual.txt
        done < temp_sorted_detected.txt
        ignored=$(cat temp_sorted_actual.txt | wc -l)

        rm temp_sorted_actual.txt
        rm temp_sorted_detected.txt


        # Print the collective hits as of this image
        twodecimals=$(printf '%.2f' \
        "$((${hits}.0/${possible_detections}.0*100.0))") \
        && echo \
        "Correct detection ${hits}/${possible_detections} (~ ${twodecimals}%)"

        # Print the collective misses as of this image
        twodecimals=$(printf '%.2f' \
        "$((${misses}.0/${guesses}.0*100.0))") \
        && echo \
        "False detection ${misses}/${guesses} (~ ${twodecimals}%)"

        # Print the collective ignored as of this image
        twodecimals=$(printf '%.2f' \
        "$((${ignored}.0/${number_of_cards}.0*100.0))") \
        && echo \
        "Ignored cards ${ignored}/${number_of_cards} (~ ${twodecimals}%)"

    done

    echo "${weight_name} results:" >> ${path_collected_results}

    # Saving the average execution time of darknet
    twodecimals=$( printf '%.2f' "$((${darknet_exec_time} / ${#images[@]}))" ) \
    && echo -e "Darknet execution time ..... ${twodecimals}s" \
    >> ${path_collected_results}


    # Goes through the whole percentage file for the current weights file,
    # calculates the average percentage and appends it to the percentage file
	while read percentage; do
        avg_percent=$(( $avg_percent + $percentage ))
    done < ${path_result_percentages}
    avg_percent=$(( $avg_percent / $(cat ${path_result_percentages} | wc -l) ))

    twodecimals=$(printf '%.2f' "${avg_percent}") \
    && echo -e "Average detection percentage ${twodecimals}%" \
    >> ${path_collected_results}


    # Save information of hits with all images processed
    twodecimals=$(printf '%.2f' \
    "$((${hits}.0/${possible_detections}.0*100.0))") \
    && echo -e \
    "Correct detection .......... ${hits}/${possible_detections} (~ ${twodecimals}%)" \
    >> ${path_collected_results}

    # Save information of misses with all images processed
    twodecimals=$(printf '%.2f' \
    "$((${misses}.0/${guesses}.0*100.0))") \
    && echo -e \
    "False detection ............ ${misses}/${guesses} (~ ${twodecimals}%)" \
    >> ${path_collected_results}

    # Save information of ignored cards with all images processed
    twodecimals=$(printf '%.2f' \
    "$((${ignored}.0/${number_of_cards}.0*100.0))") \
    && echo -e \
    "Ignored cards .............. ${ignored}/${number_of_cards} (~ ${twodecimals}%)" \
    >> ${path_collected_results}


    echo "-" >> ${path_collected_results}
done


# Printing everything in the collected results txt file
clear
echo "---------- Collected results: ----------"
while read result; do
    echo "${result}"
done < ${path_collected_results}

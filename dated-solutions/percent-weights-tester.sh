# author: David Fager s185120
#!/bin/bash
# This script is no longer in use. See the full-weights-analysis.zsh script instead.

list=("v3-tiny-14200" "v3-tiny-17600" "v3-tiny-18500" "v3-tiny-20000" "v3-tiny-21000" "v3-tiny-22000" "v3-retrained")

cd darknet
mkdir test-results

# Calculation
for index in ${list[*]}; do

    echo -e "Testing on ${index}"

    avg=0

    ./darknet detector test cfg/owndata.data test-files/${index}.cfg test-files/${index}.weights \
    test-images/all-clubs.png | cut -d " " -f 2 | cut -d "%" -f 1 >> test-results/${index}-percents.txt \
    && sed -i '1d' test-results/${index}-percents.txt

    while read line; do
        avg=$(( $avg + $line ))
    done < test-results/${index}-percents.txt

    avg=$(( $avg / $(wc -l test-results/${index}-percents.txt | cut -d " " -f 1) ))
    echo "AVG IS ${avg}%" && echo "AVG IS ${avg}%" >> test-results/${index}-percents.txt

done

# Printing the results
for index in ${list[*]}; do
    echo "${index}: $(tail -1 test-results/${index}-percents.txt)"
done

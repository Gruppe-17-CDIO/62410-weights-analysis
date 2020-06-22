# author: David Fager s185120
#!/bin/bash
# This script is no longer in use. See the full-weights-analysis.zsh script instead.

list=("v3-tiny-14200" "v3-tiny-17600" "v3-tiny-18500" "v3-tiny-20000" "v3-tiny-21000" "v3-tiny-22000" "v3-retrained")

cd darknet
mkdir test-results
mkdir test-results/overlaying-clubs-diamonds
mkdir test-results/overlaying-spades-hearts

for index in ${list[*]}; do

    echo -e "Testing on ${index}"

    ./darknet detector test cfg/owndata.data test-files/${index}.cfg test-files/${index}.weights \
    test-images/overlaying-clubs-diamonds.png > test-results/overlaying-clubs-diamonds/${index}-output.txt \
    && mv predictions.jpg test-results/overlaying-clubs-diamonds/${index}-predictions.jpg

    ./darknet detector test cfg/owndata.data test-files/${index}.cfg test-files/${index}.weights \
    test-images/overlaying-spades-hearts.png > test-results/overlaying-spades-hearts/${index}-output.txt \
    && mv predictions.jpg test-results/overlaying-spades-hearts/${index}-predictions.jpg

done

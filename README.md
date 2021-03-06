# 62410-weights-analysis
A Z shell script to analyse the accuracy of several Darknet models and compare their performance.

## Introduction
This script is a part of a project in course 62410 CDIO-project at Denmarks Technical University (DTU). Its purpose is to analyse how well a machine learning model, trained via the Darknet repository (linked under the 'Links' section), is at guessing playing card suits and values correctly. Its a Z shell script because it needs to include decimal values.  
The model is then used in another program, to be able to provide the solution, step by step, in a solitaire, that has its playing cards recognised via the model and a webcam.  
The image.c file in this project, originates from pjreddie's Darknet project, and is modified to fit this script.

The scripts in the 'dated-solutions' folder has been improved upon and therefore they are not used anymore.

The test images were manually labeled with the labelimg project. See 'Links' for source.

## Links
* Labelimg by tzutalin: https://github.com/tzutalin/labelImg  
* The test images and files used in this script is located on Google Drive at: https://drive.google.com/file/d/1rwsorNLXJ9kM3XEsINHE9Hde0egH_qQf/view  
* The Darknet repository by pjreddie: https://github.com/pjreddie/darknet (Where the image.c file is from)  
* The other GitHub projects, that are part of the courses project: https://github.com/Gruppe-17-CDIO  

## How to use
1. Make sure you have zsh: $ sudo apt-get install zsh
2. Clone this project and change into the directory
3. Run with: $ zsh full-weights-analysis-reworked.zsh
4. Make sure the 'necessary steps' mentioned in the script is done.

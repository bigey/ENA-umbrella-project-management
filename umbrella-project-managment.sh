#!/bin/bash
set -euo pipefail

# Author: Frederic BIGEY - INRAE
# Last update: 2026-03-09


#================================================================================
# PARAMETERS
#================================================================================

# Submit or test?
# One of the following:
# "true": real data submission,
# "false": submit to testing server, validation only
SUBMISSION="false"

# CREDENTIAL FILE
# File containing the credentials.
# One line containing:
# username password
CREDENDIAL=".credential"

# Submission XML file
# The XML file contains the submission information, including the actions to perform.
# Action types include: ADD, HOLD, MODIFY, RELEASE
SUBMISSION_XML="new-submission.xml"
# SUBMISSION_XML="update-submission.xml"
# SUBMISSION_XML="release-submission.xml"

# Umbrella project XML file
# The XML file contains the umbrella project information.
UMBRELLA_PROJECT_XML="blank-umbrella-project.xml"
# UMBRELLA_PROJECT_XML="blank-umbrella-project-with-childs.xml"


#===============================================================================
# DO NOT MODIFY BELOW THIS LINE
#===============================================================================

# CHECKING INPUT FILES
echo "# Checking input files..."

# Check if the credential file exists
if [ ! -f "$CREDENDIAL" ]; then
    echo "  ERROR: Credential file '$CREDENDIAL' not found!"
    exit 1
else
    echo "  Credential file '$CREDENDIAL' found."
fi

# CHECK IF XML FILES WERE AVAILABLE
files="" # used to pass files to curl (-F option)

if [ -f ${SUBMISSION_XML} ]; then

    echo "  Submission XML file: $SUBMISSION_XML is available."
    files="$files -F SUBMISSION=@${SUBMISSION_XML} "

    if [ ${SUBMISSION_XML} == "release-submission.xml" ]; then

        echo "  This is a release submission and no project XML file is needed."

    elif [ -f ${UMBRELLA_PROJECT_XML} ]; then

        echo "  Umbrella project XML file: $UMBRELLA_PROJECT_XML is available."
        files="$files -F PROJECT=@${UMBRELLA_PROJECT_XML}"
        
    else
        
        echo "  ERROR: Project XML file: ${UMBRELLA_PROJECT_XML} not found!"
    fi
else
    
    echo "  ERROR: Submission XML file: $SUBMISSION_XML not found!"
    exit 1
fi


#===============================================================================
# ENA SUBMISSION
#===============================================================================

# ENA SERVERS
URL_TEST="https://wwwdev.ebi.ac.uk/ena/submit/drop-box/submit/"
URL_PROD="https://www.ebi.ac.uk/ena/submit/drop-box/submit/"

# SELECT SERVER
if [ $SUBMISSION = "true" ]
then
    URL=$URL_PROD
    echo "# This is a real submission..."
else
    URL=$URL_TEST
    echo "# This a test submission, and files will be discarded within 24 hours..."
fi

# IMPORT CREDENTIALS
read user pass < $CREDENDIAL

# ENA SUBMISSION
echo "# Submit XML files to ENA server..."
curl -u ${user}:${pass} ${files} --url ${URL} > server-receipt.xml

# CHECK SERVER RESPONSE
if grep "RECEIPT" server-receipt.xml &> /dev/null; then
    
    echo "    - server connection was ok."
    success=$(perl -ne 'm/success="(true|false)"/ && print $1' server-receipt.xml)

    if [ $success = "true" ]; then

        echo "# Submission was successful."

        # PARSE RECEIPT XML RESPONSE
        ./parse-receipt.py -t -o server-receipt.txt server-receipt.xml

        echo "  See the server receipts returned: "
        echo "     - server-receipt.xml (original receipt)"
        echo "     - server-receipt.txt (tabular format)"

    else

        echo "# Submission failed!"
        
        echo "    - see server receipt XML returned: server-receipt.xml."
        echo "    - check the receipt for error messages and after making corrections, "
        echo "        try the submission again."
        echo
        exit 2

    fi

else

    echo "# Server connection error!"
    echo "    - see server receipt file: server-receipt.xml."
    echo
    exit 1
fi

# END
echo
echo "# Done"

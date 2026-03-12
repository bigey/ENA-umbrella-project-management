#!/bin/bash

# Author: Frederic BIGEY - INRAE
# TUI for ENA Umbrella Project Management
# Requires: whiptail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
TITLE="ENA Umbrella Project Manager"


#================================================================================
# PREREQUISITES CHECK
#================================================================================

check_prerequisites() {
    if ! command -v whiptail &>/dev/null; then
        echo "ERROR: whiptail is not installed."
        echo "Install with: apt install whiptail"
        exit 1
    fi
    if ! command -v curl &>/dev/null; then
        echo "ERROR: curl is not installed."
        echo "Install with: apt install curl"
        exit 1
    fi
    if [ ! -d "$TEMPLATES_DIR" ]; then
        echo "ERROR: templates/ directory not found in $SCRIPT_DIR"
        exit 1
    fi
}


#================================================================================
# XML GENERATION
#================================================================================

# Generate a blank project.xml with N child placeholders (0 = no children)
# If add_accession=true, adds accession="TODO: PRJEBxxxxxx" to <PROJECT> (for updates)
generate_project_xml() {
    local n_children=$1
    local add_accession=${2:-false}
    local xml_file="$SCRIPT_DIR/project.xml"

    if [ "$add_accession" = true ]; then
        cat > "$xml_file" <<'EOF'
<PROJECT_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <PROJECT center_name="" alias="TODO: alias" accession="TODO: PRJEBxxxxxx">
        <NAME>TODO: Name text here</NAME>
        <TITLE>TODO: Title text here</TITLE>
        <DESCRIPTION>TODO: Description text here</DESCRIPTION>
        <UMBRELLA_PROJECT/>
EOF
    else
        cat > "$xml_file" <<'EOF'
<PROJECT_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <PROJECT center_name="" alias="TODO: alias">
        <NAME>TODO: Name text here</NAME>
        <TITLE>TODO: Title text here</TITLE>
        <DESCRIPTION>TODO: Description text here</DESCRIPTION>
        <UMBRELLA_PROJECT/>
EOF
    fi

    if [ "$n_children" -gt 0 ]; then
        echo "        <RELATED_PROJECTS>" >> "$xml_file"
        for _ in $(seq 1 "$n_children"); do
            cat >> "$xml_file" <<'EOF'
            <RELATED_PROJECT>
                <CHILD_PROJECT accession="PRJEBxxxxxx"/>
            </RELATED_PROJECT>
EOF
        done
        echo "        </RELATED_PROJECTS>" >> "$xml_file"
    fi

    cat >> "$xml_file" <<'EOF'
    </PROJECT>
</PROJECT_SET>
EOF
}

# Inject N child placeholders into an existing project.xml before </PROJECT>
inject_children_xml() {
    local n_children=$1
    local xml_file="$SCRIPT_DIR/project.xml"
    local tmp_file
    tmp_file=$(mktemp)

    local block="        <RELATED_PROJECTS>"$'\n'
    for _ in $(seq 1 "$n_children"); do
        block+="            <RELATED_PROJECT>"$'\n'
        block+="                <CHILD_PROJECT accession=\"PRJEBxxxxxx\"/>"$'\n'
        block+="            </RELATED_PROJECT>"$'\n'
    done
    block+="        </RELATED_PROJECTS>"

    awk -v cb="$block" '/[[:space:]]*<\/PROJECT>/ { print cb } { print }' \
        "$xml_file" > "$tmp_file"
    mv "$tmp_file" "$xml_file"
}

# Ask for an existing XML file path, validate it exists, return path in $REPLY
# Returns 1 if user cancelled
ask_existing_xml() {
    local path
    while true; do
        path=$(whiptail --title "$TITLE" \
            --inputbox "Path to existing project XML file:" 8 65 "" \
            3>&1 1>&2 2>&3) || return 1

        if [ -f "$path" ]; then
            REPLY=$path
            return 0
        else
            whiptail --title "$TITLE" \
                --msgbox "File not found:\n  $path\n\nPlease try again." 9 65
        fi
    done
}

# Ask user for a hold date (YYYY-MM-DD), default to today + 2 years, return in $REPLY
# Returns 1 if user cancelled
ask_hold_date() {
    local default
    default=$(date -d "+2 years" +%Y-%m-%d 2>/dev/null \
        || date -v+2y +%Y-%m-%d)  # fallback for macOS

    local d
    while true; do
        d=$(whiptail --title "$TITLE" \
            --inputbox "Hold until date (YYYY-MM-DD):\n(project will remain private until this date)" \
            9 55 "$default" \
            3>&1 1>&2 2>&3) || return 1

        if [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            REPLY=$d
            return 0
        else
            whiptail --title "$TITLE" \
                --msgbox "Invalid date: $d\n\nExpected format: YYYY-MM-DD (e.g. 2028-03-12)" \
                9 55
        fi
    done
}

# Ask user for number of children, validate input, return value in $REPLY
# Returns 1 if user cancelled
ask_n_children() {
    local n
    while true; do
        n=$(whiptail --title "$TITLE" \
            --inputbox "How many child sub-projects?" 8 40 "1" \
            3>&1 1>&2 2>&3) || return 1

        if [[ "$n" =~ ^[1-9][0-9]*$ ]]; then
            REPLY=$n
            return 0
        else
            whiptail --title "$TITLE" \
                --msgbox "Please enter a valid positive integer." 7 45
        fi
    done
}


#================================================================================
# ACTIONS
#================================================================================

action_create() {
    whiptail --title "$TITLE" \
        --yesno "Does this project have child sub-projects?" 8 60
    local rc=$?

    # ESC pressed → back to main menu
    [ $rc -eq 255 ] && return

    local n_children=0
    if [ $rc -eq 0 ]; then
        ask_n_children || return
        n_children=$REPLY
    fi

    generate_project_xml "$n_children"

    # Ask for hold date and inject into submission.xml
    ask_hold_date || return
    local hold_date="$REPLY"
    sed "s/YYYY-MM-DD/$hold_date/" \
        "$TEMPLATES_DIR/new-submission.xml" > "$SCRIPT_DIR/submission.xml"

    local msg
    msg="Working files created in $(basename "$SCRIPT_DIR")/:\n\n"
    msg+="  project.xml\n"
    msg+="  submission.xml    (HoldUntilDate: $hold_date)\n\n"
    msg+="Edit project.xml and fill in:\n"
    msg+="  - center_name    your institution name\n"
    msg+="  - alias          unique local identifier\n"
    msg+="  - NAME           short project name\n"
    msg+="  - TITLE          full project title\n"
    msg+="  - DESCRIPTION    project description\n"
    if [ "$n_children" -gt 0 ]; then
        msg+="  - PRJEBxxxxxx    replace with child accessions ($n_children slot(s))\n"
    fi

    whiptail --title "$TITLE" --msgbox "$msg" 20 65
}

action_update() {
    # Step 1: existing project XML?
    whiptail --title "$TITLE" \
        --yesno "Do you have an existing project XML file to use as base?" 8 65
    local rc=$?
    [ $rc -eq 255 ] && return

    local used_existing=false
    if [ $rc -eq 0 ]; then
        ask_existing_xml || return
        cp "$REPLY" "$SCRIPT_DIR/project.xml"
        used_existing=true
    else
        generate_project_xml 0 true
    fi

    # Step 2: add child sub-projects?
    whiptail --title "$TITLE" \
        --yesno "Does this update include adding child sub-projects?" 8 65
    local rc2=$?
    [ $rc2 -eq 255 ] && return

    local n_children=0
    if [ $rc2 -eq 0 ]; then
        ask_n_children || return
        n_children=$REPLY
        inject_children_xml "$n_children"
    fi

    cp "$TEMPLATES_DIR/update-submission.xml" "$SCRIPT_DIR/submission.xml"

    local msg
    msg="Working files created in $(basename "$SCRIPT_DIR")/:\n\n"
    msg+="  project.xml\n"
    msg+="  submission.xml\n\n"
    if [ "$used_existing" = false ]; then
        msg+="Edit project.xml and fill in:\n"
        msg+="  - accession      PRJEBxxxxxx of the project to update\n"
        msg+="  - center_name    your institution name\n"
        msg+="  - alias          unique local identifier\n"
        msg+="  - NAME           short project name\n"
        msg+="  - TITLE          full project title\n"
        msg+="  - DESCRIPTION    project description\n"
    else
        msg+="project.xml loaded from your existing file.\n"
    fi
    if [ "$n_children" -gt 0 ]; then
        msg+="  - PRJEBxxxxxx    replace with child accessions ($n_children slot(s))\n"
    fi

    whiptail --title "$TITLE" --msgbox "$msg" 22 65
}

action_submit() {
    local credential="$SCRIPT_DIR/.credential"
    local submission_xml="$SCRIPT_DIR/submission.xml"
    local project_xml="$SCRIPT_DIR/project.xml"

    # Check credential file
    if [ ! -f "$credential" ]; then
        whiptail --title "$TITLE" --msgbox \
            "Credential file not found: .credential\n\nCreate a file named '.credential'\nin the project directory containing:\n  Webin-XXXXX password" \
            12 65
        return
    fi

    # Check submission.xml
    if [ ! -f "$submission_xml" ]; then
        whiptail --title "$TITLE" --msgbox \
            "No submission.xml found.\n\nGenerate working files first using\nCreate, Update, or Release." \
            10 60
        return
    fi

    # Detect release submission (no project.xml needed)
    local is_release=false
    grep -q "<RELEASE" "$submission_xml" && is_release=true

    # Check project.xml if needed
    if [ "$is_release" = false ] && [ ! -f "$project_xml" ]; then
        whiptail --title "$TITLE" --msgbox \
            "No project.xml found.\n\nGenerate working files first using\nCreate or Update." \
            10 60
        return
    fi

    # Test or Production?
    local mode
    mode=$(whiptail --title "$TITLE" \
        --menu "Select submission mode:" 11 65 2 \
        "test" "Test server  (validation only, discarded after 24h)" \
        "prod" "Production  (real submission)" \
        3>&1 1>&2 2>&3) || return

    # Confirmation summary
    local summary="Ready to submit:\n\n"
    summary+="  submission.xml  found\n"
    [ "$is_release" = false ] && summary+="  project.xml     found\n"
    summary+="\n  Mode: "
    [ "$mode" = "prod" ] && summary+="PRODUCTION (real submission)" \
                         || summary+="TEST (validation only)"
    summary+="\n\nProceed?"

    whiptail --title "$TITLE" --yesno "$summary" 14 60 || return

    # Extra confirmation for production
    if [ "$mode" = "prod" ]; then
        whiptail --title "!!! WARNING !!!" --msgbox \
            "You are about to submit to the ENA PRODUCTION server.\n\nThis is a REAL submission:\n  - Data will be registered in ENA\n  - This action cannot be undone\n\nMake sure your XML files are correct\nbefore proceeding." \
            14 62

        local confirm
        confirm=$(whiptail --title "!!! PRODUCTION CONFIRMATION !!!" \
            --inputbox "Type YES (uppercase) to confirm real submission:" \
            8 62 "" \
            3>&1 1>&2 2>&3) || return

        if [ "$confirm" != "YES" ]; then
            whiptail --title "$TITLE" --msgbox \
                "Submission cancelled.\n\nYou did not type YES." \
                8 45
            return
        fi
    fi

    # Select URL
    local url
    [ "$mode" = "prod" ] \
        && url="https://www.ebi.ac.uk/ena/submit/drop-box/submit/" \
        || url="https://wwwdev.ebi.ac.uk/ena/submit/drop-box/submit/"

    # Build curl file arguments
    local files="-F SUBMISSION=@${submission_xml}"
    [ "$is_release" = false ] && files="$files -F PROJECT=@${project_xml}"

    # Read credentials
    local user pass
    read -r user pass < "$credential"

    # Submit
    whiptail --title "$TITLE" --infobox "Submitting to ENA server...\nPlease wait." 6 45
    curl -u "${user}:${pass}" $files --url "$url" \
        > "$SCRIPT_DIR/server-receipt.xml" 2>/dev/null

    # Check server response
    if ! grep -q "RECEIPT" "$SCRIPT_DIR/server-receipt.xml"; then
        whiptail --title "$TITLE" --msgbox \
            "Server connection error!\n\nSee server-receipt.xml for details." \
            9 55
        return
    fi

    local success
    success=$(perl -ne 'm/success="(true|false)"/ && print $1' \
        "$SCRIPT_DIR/server-receipt.xml")

    if [ "$success" = "true" ]; then
        local msg="Submission successful!\n\nReceipt files saved:\n  server-receipt.xml  (original)"
        if [ -x "$SCRIPT_DIR/parse-receipt.py" ]; then
            "$SCRIPT_DIR/parse-receipt.py" --tsv \
                --out "$SCRIPT_DIR/server-receipt.txt" \
                "$SCRIPT_DIR/server-receipt.xml" 2>/dev/null \
                && msg+="\n  server-receipt.txt  (tabular)"
        fi
        whiptail --title "$TITLE" --msgbox "$msg" 12 55
    else
        whiptail --title "$TITLE" --msgbox \
            "Submission failed!\n\nSee server-receipt.xml for error details.\nCorrect the issues and try again." \
            11 60
    fi
}

action_release() {
    # Ask for project accession
    local accession
    while true; do
        accession=$(whiptail --title "$TITLE" \
            --inputbox "Enter the accession of the umbrella project to release:" \
            8 65 "PRJEB" \
            3>&1 1>&2 2>&3) || return

        if [[ "$accession" =~ ^PRJEB[0-9]+$ ]]; then
            break
        else
            whiptail --title "$TITLE" \
                --msgbox "Invalid accession: $accession\n\nExpected format: PRJEBxxxxxx (e.g. PRJEB12345)" \
                9 65
        fi
    done

    # Generate submission.xml with the accession filled in
    sed "s/PRJEBxxxxxx/$accession/" \
        "$TEMPLATES_DIR/release-submission.xml" > "$SCRIPT_DIR/submission.xml"

    whiptail --title "$TITLE" --msgbox \
        "Working file created in $(basename "$SCRIPT_DIR")/:\n\n  submission.xml\n\nTarget accession set to: $accession" \
        11 65

    whiptail --title "$TITLE" \
        --yesno "Do you want to proceed to submission now?" 7 55 \
        && action_submit
}


#================================================================================
# MAIN
#================================================================================

main() {
    check_prerequisites

    while true; do
        local choice
        choice=$(whiptail --title "$TITLE" \
            --menu "Select an action:" 16 60 5 \
            "1" "Create a new umbrella project" \
            "2" "Update an existing umbrella project" \
            "3" "Release an umbrella project" \
            "4" "Submit to ENA" \
            "5" "Quit" \
            3>&1 1>&2 2>&3) || exit 0

        case $choice in
            1) action_create ;;
            2) action_update ;;
            3) action_release ;;
            4) action_submit ;;
            5) exit 0 ;;
        esac
    done
}

main

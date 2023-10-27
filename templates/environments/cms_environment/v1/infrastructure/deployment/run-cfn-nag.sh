#!/bin/bash

showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF
Usage: ./deployment/run-cfn-nag.sh --help

Run "cdk-nag" and cfn-nag in this project.

-h, --help               Display help

-dl, --deny-list-path  Pass the file name which contains cfn-nag rules to suppress

EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}


deny_list_path=""
while [[ $# -gt 0 ]]
do
key="$1"
  case $key in
    -h|--help)
        showHelp
        exit 0
        ;;
    -dl|--deny-list-path)
        deny_list_path="$2"
        shift
        shift
        ;;
    *)
        shift
  esac
done

# If getting called from CMS, change PWD to the expected location
if [[ "$0" == *"templates"* ]]; then
  while IFS='/' read -ra ADDR; do
    for i in "${ADDR[@]}"; do
      if [[ "$i" == "deployment" ]]; then
        break
      fi
      cd $i
    done
  done <<< "$0"
fi

# Activate local environment
echo "===================================================="
echo "Activating venv found in $PWD"
echo "===================================================="
source ./.venv/bin/activate

cdk_out_dir=$PWD/cdk.out

# Synthesize the latest stack template files
rm -rf $cdk_out_dir
cdk synth --context nag-enforce=True --quiet
if [ $? != 0 ]
then
    echo "===================================================="
    echo "CDK SYNTH failed, can not perform CFN NAG Scan"
    echo "===================================================="
    exit 1
fi


# Loop through all files with extension .template.json inside the cdk.out folder
for file in "${cdk_out_dir}"/*.template.json
do
    # Check if the file exists and is a file (not a directory)
    if [[ -f "${file}" ]]; then
        # Run cfn_nag on the file
        if [ "$deny_list_path" == "" ]; then
            output=$(cfn_nag "${file}"  2>&1)
        else
            output=$(cfn_nag "${file}" --deny-list-path=$deny_list_path 2>&1)
        fi
        # Check if there are any warnings in the output
        if [[ "${output}" == *"WARN"*  || "${output}" == *"FAIL"* ]]; then
            # Set the warnings_exist flag to true
            warnings_exist=true
        fi

        echo "$output"
    fi
done

# If there were any warnings, exit with code 1
if [ "${warnings_exist}" = true ]; then
    echo "===================================================="
    echo "CFN NAG Scan failed"
    echo "===================================================="
    exit 1
fi

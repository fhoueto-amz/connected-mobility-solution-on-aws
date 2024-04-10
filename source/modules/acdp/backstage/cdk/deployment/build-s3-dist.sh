#!/bin/bash

set -e && [[ "$DEBUG" == 'true' ]] && set -x

showHelp() {
cat << EOF
Usage: ./deployment/build-s3-dist.sh --help

Build and synthesize the CFN template. Package the templates into the deployment/global-s3-assets
folder and the build assets in the deployment/regional-s3-assets folder.

Example:
./deployment/build-s3-dist.sh
The template will then expect the build assets to be located in the solutions-features-[region_name] bucket.
EOF
}

# Get reference for all important folders
root_dir="$(dirname "$(dirname "$(realpath "$0")")")"
deployment_dir="$root_dir/deployment"
staging_dist_dir="$deployment_dir/staging"
template_dist_dir="$deployment_dir/global-s3-assets"
build_dist_dir="$deployment_dir/regional-s3-assets"

printf "%b[VirtualEnv] Activating venv found in %s\n%b" "${GREEN}" "${root_dir}" "${NC}"
source "$root_dir/.venv/bin/activate"

printf "%b[Init] Remove old dist files from previous runs\n%b" "${GREEN}" "${NC}"
rm -rf "$template_dist_dir"
rm -rf "$build_dist_dir"
rm -rf "$staging_dist_dir"

mkdir -p "$template_dist_dir"
mkdir -p "$build_dist_dir"
mkdir -p "$staging_dist_dir"

printf "%b[Init] Install dependencies for cdk-solution-helper\n%b" "${GREEN}" "${NC}"
npm ci --prefix "$deployment_dir/cdk-solution-helper"

printf "%b[Build] Build project specific assets\n%b" "${GREEN}" "${NC}"

printf "%b[Synth] Synthesize Stack\n%b" "${GREEN}" "${NC}"
cd "$root_dir"
cdk synth --output="$staging_dist_dir" >> /dev/null

printf "%b[Packing] Template artifacts\n%b" "${GREEN}" "${NC}"
rm -f "$staging_dist_dir/tree.json"
rm -f "$staging_dist_dir/manifest.json"
rm -f "$staging_dist_dir/cdk.out"

for f in "$staging_dist_dir"/*.template.json; do
  mv "$f" "${f%.template.json}.template";
  mv "${f%.template.json}.template" "$template_dist_dir";
done

cd "$deployment_dir/cdk-solution-helper"
node index
cd "$root_dir"

printf "%b[Packing] Updating placeholders\n%b" "${GREEN}" "${NC}"
sedi=(-i)
if [[ "$OSTYPE" == "darwin"* ]]; then
  sedi=(-i "")
fi

for file in "$template_dist_dir"/*.template
do
    sed "${sedi[@]}" -E "s/\"\/([^asset][a-z0-9]+.zip)\"/\"\/asset\1\"/g" "$file"
done

printf "%b[Packing] Source code artifacts\n%b" "${GREEN}" "${NC}"
# For each asset.*.zip source code artifact in the temporary /staging folder
while IFS=  read -r f; do
    # Rename the artifact, removing the period for handler compatibility
    zip_file_name="$(basename "$f")"
    modified_zip_file_name="${zip_file_name/asset\./asset}"

    # Copy the artifact from /staging to /regional-s3-assets
    mv "$f" "$build_dist_dir/$modified_zip_file_name"
done < <(find "$staging_dist_dir" -name "*.zip" -mindepth 1 -maxdepth 1 -type f)

while IFS=  read -r d; do
    # Rename the artifact, removing the period for handler compatibility
    dir_name="$(basename "$d")"
    modified_dir_name="${dir_name/\./}"

    # Zip artifacts from asset folder
    cd "$d"
    zip -r "$staging_dist_dir/$modified_dir_name.zip" . > /dev/null
    cd "$root_dir"

    # Copy the zipped artifact from /staging to /regional-s3-assets
    mv "$staging_dist_dir/$modified_dir_name.zip" "$build_dist_dir"

    # Remove the old artifacts from /staging
    rm -rf "$d"
done < <(find "$staging_dist_dir" -mindepth 1 -maxdepth 1 -type d)

printf "%b[Cleanup] Remove temporary files\n%b" "${GREEN}" "${NC}"
rm -rf "$staging_dist_dir"

printf "%b[Move] Move assets into module specific asset directory\n%b" "${GREEN}" "${NC}"
mkdir -p "$template_dist_dir/$MODULE_NAME"
mkdir -p "$build_dist_dir/$MODULE_NAME"

find "$template_dist_dir" -name "*.template" -maxdepth 1 -exec mv {} "$template_dist_dir/$MODULE_NAME/" \;
find "$build_dist_dir" -name "*.zip" -maxdepth 1 -exec mv {} "$build_dist_dir/$MODULE_NAME/" \;

printf "%bBuild script finished.\n%b" "${GREEN}" "${NC}"

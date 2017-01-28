pushd . > /dev/null
cd "$(dirname "$0")"
templates_folder="templates"
mkdir -p dist
for language in $(ls $templates_folder); do
	language_folder="$templates_folder/$language"
	pushd . > /dev/null
	cd "$language_folder"
	zip -r ../../dist/$language-project-template.zip *
	popd > /dev/null
done
popd > /dev/null


function compile_templates () {
	local distribution_folder="dist"
	local language_spec_file="language-spec.txt"
	local templates_folder="src/templates"

	rm -rf "$distribution_folder"
	./clean.sh
	mkdir -p "$distribution_folder"

	for language in $(ls "$templates_folder"); do
		local language_source_folder="$templates_folder/$language"
		cp -r "$language_source_folder" "$distribution_folder"
		local language_distribution_folder="$distribution_folder/$language"

		pushd . > /dev/null

		cd "$language_distribution_folder"
		local language_archive="$language-project-template.zip"
		echo "$language" > "$language_spec_file"
		echo -e "Zipping \"$language_source_folder\" into \"$language_archive\""
		zip -r "../$language_archive" .

		popd > /dev/null

		rm -rf "$language_distribution_folder"
	done
}

pushd . > /dev/null
cd "$(dirname "$0")"
compile_templates
popd > /dev/null

function test_templates () {
	./compile-templates.sh

	if [ $? != 0 ]; then
		echo "Unable to compile templates -- see output for more details" 1>&2
		exit 1
	fi

	echo "CWD: $(pwd)"
	local test_folder="test"
	mkdir -p $test_folder
	local distribution_folder="dist"
	for archive in $(ls $distribution_folder); do
		local archive_path="$distribution_folder/$archive"
		echo "Testing $archive_path"
		local test_folder="$test_folder/$archive"
		unzip "$archive_path" -d "$test_folder"

		pushd . > /dev/null

		cd "$test_folder"
		../../grade.sh

		popd > /dev/null
	done
}


pushd . > /dev/null
cd "$(dirname "$0")"
test_templates
popd > /dev/null

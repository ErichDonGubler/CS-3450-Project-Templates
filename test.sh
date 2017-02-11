function test_templates () {
	./build.sh
	. ./src/grade.sh

	if [ $? != 0 ]; then
		echo "Unable to build -- see output for more details" 1>&2
		exit 1
	fi

	echo "CWD: $(pwd)"
	local test_folder="test"
	mkdir -p $test_folder
	local distribution_folder="dist"
	for archive in $(ls $distribution_folder); do
		local archive_path="$distribution_folder/$archive"
		echo "Testing $archive_path"
		local archive_test_folder="$test_folder/$archive"
		unzip "$archive_path" -d "$archive_test_folder"

		pushd . > /dev/null

		cd "$archive_test_folder"
		grade

		popd > /dev/null
	done
}


pushd . > /dev/null
cd "$(dirname "$0")"
test_templates
popd > /dev/null

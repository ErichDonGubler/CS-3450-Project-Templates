function grade () {
	if [ "$#" -ne 1 ]; then
		echo "Expected invocation of the form \"grade <language>\""
		return 1
	fi

	local student_language="$1"
	# TODO: Add detection logic based on .language-spec

	local teacher_files=".teacher_files"
	function log_execution () {
		echo -e "---- RUNNING STUDENT PROGRAM ----\n"
		"$@" | tee $teacher_files/output.log
		echo -e "---- END STUDENT PROGRAM ----\n"
	}

	function find_files () {
		find . -type f -regextype posix-extended -iregex "$@"
	}

	function wait_for_input () {
		read -p "Press any key to continue..."
	}

	function open_documents () {
		for file in "$(find_files ".*\.(doc|pdf|png|jpg)")"; do # FIXME: This will break if there's more than one file
			echo "Found displayable file \"$file\""
			xdg-open "$file"
		done
	}
	function open_source_files () {
		echo "Opening source files that match \"$@\"..."
		find_files "$@" | xargs vim -O
		stty sane
	}

	local source_code_pattern=""
	function open_student_code () {
		open_source_files "$source_code_pattern"
	}

	function run_student_code () {
		echo "Running normal build script for $student_language language"
		./build.sh
	}

	function clean_up () {
		unset clean_up
		unset find_files
		unset log_execution
		unset open_documents
		unset open_source_files
		unset open_student_code
		unset run_student_code
		unset teacher_files
	}

	mkdir -p $teacher_files

	case $language in
		"cplusplus"*)
			;&
		"c++"*)
			source_code_pattern='.*\.(h|cpp)'
			;;

		"csharp_standalone"*)
			;&
		"cs-single"*)
			source_code_pattern='(.*\.cs)'
			;;

		"csharp_visual_studio"*)
			;&
		"cs-vs"*)
			source_code_pattern='(.*\.cs)'
			function run_student_code () {
				echo "Running script for C# Visual Studio..."
				rm -rf */bin
				xbuild *.sln

				for file in $(find . -type f -executable -name "*.exe"); do
					log_execution "$file"
				done
			}
			;;

		"d"*)
			echo "Go D!"
			source_code_pattern='(.*\.d)'
			;;

		"java"*)
			echo "Go Java!"
			source_code_pattern='(.*\.java)'
			function run_student_code () {
				rm ./program.jar
				ant
				java -jar ./program.jar
			}
			;;

		*)
			echo "Unrecognized programming language"
			clean_up
			return 1
			;;
	esac

	open_documents
	wait_for_input
	run_student_code
	wait_for_input
	open_student_code
	clean_up

	return 0
}


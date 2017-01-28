function grade () {
	if [ "$#" -ne 1 ]; then
		echo "Expected invocation of the form \"grade <language>\""
		return 1
	fi

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

	function run_student_code () { :; }

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

	case $1 in
		"c++"*)
			function run_student_code () {
				rm ./program.exe
				make
				log_execution ./program.exe
			}
			source_code_pattern='.*\.(h|cpp)'
			;;

		"cs-single"*)
			function run_student_code () {
				rm Program.exe
				mcs Program.cs
				log_execution ./Program.exe
			}
			source_code_pattern='(.*\.cs)'
			;;

		"cs-vs"*)
			echo "Go CS from VS!"
			function run_student_code () {
				rm -rf */bin
				xbuild *.sln

				for file in $(find . -type f -executable -name "*.exe"); do
					log_execution "$file"
				done
			}
			source_code_pattern='(.*\.cs)'
			;;

		"d"*)
			echo "Go D!"
			function run_student_code () {
				log_execution rdmd ./program.d
			}
			source_code_pattern='(.*\.d)'
			;;

		"java"*)
			echo "Go Java!"
			function run_student_code () {
				rm ./program.jar
				ant
				java -jar ./program.jar
			}
			source_code_pattern='(.*\.java)'
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


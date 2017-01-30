function grade () {
	local LANGUAGE_SPEC_FILE=".language-spec"
	local student_language=""

	if [ -f "$LANGUAGE_SPEC_FILE" ]; then
		student_language=$(cat $LANGUAGE_SPEC_FILE)

		echo -e "Found language spec file for \"$student_language\""
		if [ -z "$student_language" ]; then
			echo -e "Language in \"$LANGUAGE_SPEC_FILE\" is invalid! Fix or delete it before continuing."
		fi
	elif [ "$#" -ne 1 ]; then
		echo -e "Expected \"$LANGUAGE_SPEC_FILE\" file or invocation of the form \"grade <language>\""
		return 1
	else
		student_language="$1"
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
		echo "--- OPENING DOCUMENT FILES ---"
		for file in $(find_files '.*\.(doc|docx|pdf|png|jpg|html)'); do # FIXME: This will break if there's a file with spaces in it
			echo "Found displayable file \"$file\""
			xdg-open "$file"
		done
		wait_for_input
	}
	function open_source_files () {
		echo "--- OPENING SOURCE FILES ---"
		echo "Opening source files that match \"$@\"..."
		find_files "$@" | xargs vim -O
		stty sane
	}

	local source_code_pattern=""
	function open_student_code () {
		open_source_files "$source_code_pattern"
	}

	function print_run_error () {
		echo -e "ERROR: $@ -- Time to talk to the student!" 1>&2
	}

	function run_student_code_fallback () {
		echo "No fallback script defined!" 1>&2
		return 1
	}

	function run_student_code () {
		echo "--- BUILDING STUDENT CODE ---"

		local NORMAL_BUILD_SCRIPT="./build.sh"

		local return_code=0

		if [ -f "$NORMAL_BUILD_SCRIPT" ]; then
			echo "$NORMAL_BUILD_SCRIPT detected -- running normal build script for $student_language language"
			$NORMAL_BUILD_SCRIPT; return_code="$?"
		elif declare -f run_student_code_fallback > /dev/null; then
			echo "No $NORMAL_BUILD_SCRIPT found, running fallback builder"
			run_student_code_fallback; return_code="$?"
			if [ ! $return_code ]; then
				print_run_error "Fallback failed."
			fi
		else
			print_run_error "Internal error: no build script or fallback build script found for this language."
		fi

		wait_for_input

		return $return_code
	}

	function remove_file () {
		[ -f "$1"] && rm "$1"
	}

	function clean_up () {
		unset clean_up
		unset find_files
		unset LANGUAGE_SPEC_FILE
		unset log_execution
		unset open_documents
		unset open_source_files
		unset open_student_code
		unset print_run_error
		unset run_student_code
		unset student_language
		unset teacher_files
	}

	mkdir -p $teacher_files

	case "$student_language" in
		"cplusplus"*)
			;&
		"c++"*)
			source_code_pattern='.*\.(h|cpp)'
			function run_student_code_fallback () {
				remove_file "./program.exe"
				remove_file "./a.out"
				local makefile="make"
				if [ -f "$makefile" ]; then
					make
				else
					local source_location="src"

					if ! [ -d "$source_location" ]; then
						echo -e "\"$source_location\" not found, trying to compile at root..."
						source_location="."
					fi

					g++ "$source_location"/*.cpp && log_execution ./a.out
				fi
			}
			;;

		"csharp_standalone"*)
			;&
		"cs-single"*)
			source_code_pattern='(.*\.cs)'
			function run_student_code_fallback () {
				remove_file Program.exe
				mcs Program.cs
				log_execution ./Program.exe
			}
			;;

		"csharp_visual_studio"*)
			;&
		"cs-vs"*)
			source_code_pattern='(.*\.cs)'
			function run_student_code_fallback () {
				echo "Running solution build script for C# Visual Studio..."
				rm -rf */bin
				xbuild *.sln

				for file in $(find . -type f -executable -name "*.exe"); do
					log_execution "$file"
				done
			}
			;;

		"d"*)
			source_code_pattern='(.*\.d)'
			function run_student_code_fallback () {
				log_execution rdmd ./program.d
			}
			;;

		"java"*)
			source_code_pattern='(.*\.java)'
			function run_student_code_fallback () {
				remove_file ./program.jar
				ant
				java -jar ./program.jar
			}
			;;


		"python3"*)
			source_code_pattern='(.*\.py)'
			;;

		*)
			echo "Unrecognized programming language"
			clean_up
			return 1
			;;
	esac

	open_documents
	run_student_code
	open_student_code
	clean_up

	return 0
}

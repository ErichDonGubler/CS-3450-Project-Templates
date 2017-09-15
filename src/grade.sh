#! /bin/bash

grade_OS="${OSTYPE//[0-9.]/}"

function grade_convert_windows_paths () {
	cygpath --absolute -w "$@"
}

case "$grade_OS" in
	"msys")
		function grade_open_files_in_browser () {
			grade_convert_windows_paths "$@" | while read -r path; do
				explorer "$path"
			done
		}
		;;
	*)
		function grade_open_files_in_browser () {
			echo "$@" | while read -r path; do
				xdg-open "$path"
			done
		}
		;;
esac

grade_grader_files=".grader_files"

function grade_find_files () {
	find . -type f -regextype posix-extended -iregex "$@"
}

if ! declare -f grade_editor > /dev/null; then
	function grade_editor () {
		echo "Grade editor not specified, defaulting to Vim"
		local main_file="$1"
		vim "$main_file"
	}
fi

function grade_get_language () {
	for filename in "language-spec.txt" ".language-spec"; do
		if [ -f "$filename" ]; then
			cat "$filename" | tr '[:upper:]' '[:lower:]'
			return
		fi
	done
}

function grade_open_documents () {
	echo "--- OPENING DOCUMENT FILES ---"
	grade_find_files '.*\.(doc|docx|pdf|png|jpg|html|vsdx)' | while read file; do
		echo "  Found displayable file \"$file\""
		grade_open_files_in_browser "$file"
	done
}

function grade_remove_file () {
	[ -f "$1" ] && rm "$1"
}

function grade_compile_and_run () {
	local student_language="$1"
	if [ -z "$student_language" ] || [[ "$student_language" == "--" ]]; then
		local student_language="$(grade_get_language)"
	fi
	shift

	if [ -z "$student_language" ]; then
		echo "Expected language spec file or invocation of the form \"$FUNCNAME <language>\""
		return 1
	fi

	local source_code_pattern=""

	mkdir -p "$grade_grader_files"

	function run_student_code_fallback () {
		echo "No fallback script defined!" 1>&2
		return 1
	}

	function run_student_code () {
		grade_remove_file build.bat # XXX: Get rid of this once we fix the templates and they get distributed
		grade_remove_file build.sh # XXX: Get rid of this once we fix the templates and they get distributed

		echo "--- BUILDING STUDENT CODE ---"

		local NORMAL_BUILD_SCRIPT="./build.sh"

		local return_code=0

		if [ -f "$NORMAL_BUILD_SCRIPT" ]; then
			echo "$NORMAL_BUILD_SCRIPT detected -- running normal build script for $student_language language"
			chmod +x "$NORMAL_BUILD_SCRIPT"
			"$NORMAL_BUILD_SCRIPT" "$@"; return_code="$?"
		elif declare -f run_student_code_fallback > /dev/null; then
			echo "No $NORMAL_BUILD_SCRIPT found, running fallback builder"
			run_student_code_fallback "$@"; return_code="$?"
			if [ ! $return_code ]; then
				grade_print_error "Fallback failed."
			fi
		else
			grade_print_error "Internal error: no build script or fallback build script found for this language."
			return_code=1
		fi

		return $return_code
	}

	case "$student_language" in
		"cpp"*)
			;&
		"cplusplus"*)
			;&
		"c++"*)
			source_code_pattern='.*\.(h|cpp)'
			function run_student_code_fallback () {
				grade_remove_file *.exe

				if [ -f "make" ]; then
					grade_log_build make
					return $?
				else
					local default_binary_output="./a.exe"
					local source_location="src"

					if ! [ -d "$source_location" ]; then
						echo -e "\"$source_location\" not found, trying to compile at root..."
						source_location="."
					fi

					g++ "$source_location"/*.cpp && grade_log_execution "$default_binary_output" "$@"
					return $?
				fi
			}
			;;

		"cs")
			;&
		"csharp")
			;&
		"c#")
			echo -e "error: \"$student_language\" has several possible organizations, use one of the following:\n  cs_visual_studio\n  cs-single"
			return 1
			;;

		"csharp_standalone"*)
			;&
		"c#-single"*)
			;&
		"cs-single"*)
			source_code_pattern='(.*\.cs)'
			function run_student_code_fallback () {
				grade_remove_file *.exe
				case "$grade_OS" in
					"msys"*)
						csc src/*.cs
						;;
					*)
						mcs src/*.cs
						;;
				esac
				if [ $? ]; then
					grade_log_execution ./Program.exe "$@"
				fi
			}
			;;

		"c#_visual_studio"*)
			;&
		"csharp_visual_studio"*)
			;&
		"c#-vs"*)
			;&
		"cs-vs"*)
			source_code_pattern='(.*\.cs)'
			function run_student_code_fallback () {
				echo "Running solution build script for C# Visual Studio..."
				rm -rf */bin
				case "$grade_OS" in
					"msys"*)
						msbuild *.sln
						;;
					*)
						xbuild *.sln
						;;
				esac

				if [ $? ]; then
					for file in $(ls */bin/Debug/*.exe); do
						echo "Running $file"
						grade_log_execution "$file" "$@"
					done
				fi
			}
			;;

		"d"*)
			source_code_pattern='(.*\.d)'
			function run_student_code_fallback () {
				grade_log_execution rdmd ./program.d "$@"
			}
			;;

		"java"*)
			source_code_pattern='(.*\.java)'
			function run_student_code_fallback () {
				grade_remove_file ./*.jar
				if ant ; then
					local jar_execution_command="java -jar $(ls *.jar) $@"
					echo "$jar_execution_command"
					case "$grade_OS" in
						"msys"*)
							grade_log_execution start cmd //k "$jar_execution_command"
							;;
						*)
							grade_log_execution $jar_execution_command
							;;
					esac
				fi
			}
			;;

		"php"*)
			source_code_pattern='(.*\.php)'
			function run_student_code_fallback () {
				case "$grade_OS" in
					"msys"*)
						grade_log_execution ./php/php program.php "$@"
						;;
					*)
						grade_log_execution php program.php "$@"
						;;
				esac
			}
			;;

		"python2"*)
			source_code_pattern='(.*\.py)'
			function run_student_code_fallback () {
				grade_log_execution python2 program.py "$@"
			}
			;;

		"python3"*)
			source_code_pattern='(.*\.py)'
			function run_student_code_fallback () {
				grade_log_execution python3 program.py "$@"
			}
			;;

		*)
			echo "Unrecognized programming language \"$student_language\""
			return 1
			;;
	esac

	run_student_code "$@"

	unset run_student_code_fallback
	unset run_student_code
}

function grade_log () {
	local output_filename="$1"
	shift

	echo -e "---- RUNNING STUDENT PROGRAM ----\n"
	"$@" | tee $grade_grader_files/"$output_filename"
	local result=${PIPESTATUS[0]}
	echo -e "---- END STUDENT PROGRAM ----\n"
	return $result
}

function grade_log_build () {
	grade_log "build.log" "$@"
	return $?
}

function grade_log_execution () {
	grade_log "output.log" "$@"
	return $?
}

function grade_print_error () {
	echo -e "ERROR: $@ -- Time to talk to the student!" 1>&2
}

function grade () {
	grade_open_documents
	grade_compile_and_run
	grade_editor .

	return 0
}

function grade_extract_submissions () {
	function extract_zip () {
		unzip "$1" -d "$2"
	}

	function extract_tarball ()  {
		tar -xvf "$1" -C "$2"
	}

	function extract_files () {
		local file_pattern="$1"
		local extractor="$2"
		grade_find_files "$file_pattern" | while read from; do
			local to="$from-extracted"
			mkdir -p "$to"
			$2 "$from" "$to"
			rm -f "$from"
		done
	}

	extract_files '.*\.(zip)' extract_zip
	extract_files '.*\.tar.*' extract_tarball

	unset extract_zip
	unset extract_tarball
	unset extract_files
}

function grade_loop () {
	grade_extract_submissions

	while : ; do
		pushd . > /dev/null
		next=$(ls | grep '.*-extracted' | fzf --height=40% --reverse)

		if [[ -z "$next" ]]; then
			break
		fi

		cd "$next"

		if [ -z "$(grade_get_language)" ]; then
			read -p "$(echo -e "WARNING: This student doesn't have a language spec file! Here's their files:\n$(find .)\n\nWhat language to grade with? ")" language

			if [ "$language" ]; then
				grade "$language"
			else
				echo "No language specified, skipping"
			fi
		else
			grade
		fi

		popd > /dev/null
	done
}

alias gl='grade_loop'

function grade_all () {
	grade_extract_submissions

	declare -A submissions_results

	for folder in $(ls); do
		if [ -d "$folder" ]; then
			pushd "$folder" > /dev/null

			echo "=== GRADING STUDENT CODE: $folder ==="
			grade_compile_and_run "$@"; local result=$?

			submissions_results[$folder]=$result

			popd > /dev/null
		fi
	done

	for key in "${!submissions_results[@]}"; do
		echo "$key: ${submissions_results[$key]}"
	done
}


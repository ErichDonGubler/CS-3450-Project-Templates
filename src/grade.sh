#! /bin/bash

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

function grade () {
	local LANGUAGE_SPEC_FILE="language-spec.txt"
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

	function open_documents () {
		echo "--- OPENING DOCUMENT FILES ---"
		grade_find_files '.*\.(doc|docx|pdf|png|jpg|html|vsdx)' | while read file; do
			echo "  Found displayable file \"$file\""
			xdg-open "$file"
		done
	}

	local source_code_pattern=""

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
			chmod +x "$NORMAL_BUILD_SCRIPT"
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

		return $return_code
	}

	function remove_file () {
		[ -f "$1" ] && rm "$1"
	}

	function clean_up () {
		unset clean_up
		unset LANGUAGE_SPEC_FILE
		unset log_execution
		unset open_documents
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
					log_execution make
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
				log_execution java -jar ./program.jar
			}
			;;

		"php"*)
			source_code_pattern='(.*\.php)'
			function run_student_code_fallback () {
				log_execution php program.php
			}
			;;

		"python3"*)
			source_code_pattern='(.*\.py)'
			function run_student_code_fallback () {
				log_execution python program.py
			}
			;;

		*)
			echo "Unrecognized programming language"
			clean_up
			return 1
			;;
	esac

	open_documents
	run_student_code
	grade_editor .
	clean_up

	return 0
}

function grade_loop () {
	local LANGUAGE_SPEC_FILE="language-spec.txt"

	grade_find_files '.*\.(zip)' | while read archive; do
		mkdir -p "$archive-extracted"
		unzip "$archive" -d "$archive-extracted"
		rm -f "$archive"
	done

	grade_find_files '.*\.tar.*' | while read archive; do
		mkdir -p "$archive-extracted"
		tar -xvf "$archive" -C "$archive-extracted"
		rm -f "$archive"
	done

	while : ; do
		pushd . > /dev/null
		next=$(ls | grep '.*-extracted' | fzf --height=40% --reverse)

		if [[ -z "$next" ]]; then
			break
		fi

		cd "$next"

		if [ -f "$LANGUAGE_SPEC_FILE" ]; then
			grade
		else
			read -p "$(echo -e "WARNING: This student doesn't have a $LANGUAGE_SPEC_FILE! Here's their files:\n$(find .)\n\nWhat language to grade with? ")" language

			if [ "$language" ]; then
				grade "$language"
			else
				echo "No language specified, skipping"
			fi
		fi

		popd > /dev/null
	done
}


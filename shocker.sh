#!/bin/bash

#-----------------------------------------------------------------------------------------------------------------#
# A script that parses DocBlocks formatted comments in shell scripts and outputs markdown formatted documentation
# Copyright (C) 2014 Niklas Rosenqvist
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#-----------------------------------------------------------------------------------------------------------------#

# Abort on errors
set -e

# Globals
SHLANG="sh"
TITLE=""
OUTPUT=""
EXTENSION=1
FORCE=1
COPYRIGHT=""
ToC=1
CAPITALIZE=1
declare -A PARAMS=()
declare -A PROPERTIES=()

#/
# Used to find out the longest table cell
#
# To get properly formatted tables, where all the cells are aligned,
# we have to find out what the maximum length is. We do that by passing
# both the old and new value to compare with and sets provided variable
# by using eval. That way we can loop easily and find it quickly.
#
# @param int $1 The currently highest value
# @param int $2 The new value to compare with
# @param string $3 The name of the variable to set, we use the variable
#                  name of the one we provide for $1.
#
# @author Niklas Rosenqvist
#/
function take_if_higher() {
    local oldval=$1
    local newval=$2
    local saveto="$3"

    if [ $newval -gt $oldval ]; then
        eval "$saveto=$2"
    fi
}

#/ Pads string so that tables are properly formatted #/
function pad_string() {
    printf "%-${2}s" "$1"
}

#/ Repeat a character multiple a user set of times #/
function repeat_character() {
    local str="$(printf "%-${2}s" "$1")"
    echo "${str// /$1}"
}

#/ Simple sed command to remove trailing and leading whitespace #/
function trim_whitespace() {
    echo "$1" | sed -e 's/^[ \t]*//;s/[ \t]*$//'
}

#/ Removes multiple slashes, used only to get proper paths for the table of contents #/
function strip_multi_slash() {
    echo "$1" | sed 's#//*#/#g'
}

#/
# A shorthand for writing to file
#
# It uses the global variable OUTPUT to determine where stdout should be directed
#
# @param string $1 The line that should be written
# @author Niklas Rosenqvist
#/
function write() {
    echo "$1" >> "$OUTPUT"
}

#/
# Write's a DocBlock to the output file
#
# In addition to the parameters given, it also uses the global variables PARAMS and PROPERTIES,
# from which the data is extracted from.
#
# @param string $1 The function name
# @param string $2 The summary describing the function
# @param string $3 The longer explanation giving more information about the function's usage
# @return int It only returns 0 if no errors hindered the execution
#
# @author Niklas Rosenqvist
#/
function write_block() {
    local funcname="$1"
    local summary="$2"
    local description="$3"

    local tableparamskey=()
    local tableparamsval=()
    local maxkeylength=0
    local maxvallength=0
    local towrite=""
    declare -A temparray=()

    # Write what we've got
    write "## $funcname()"
    write ""
    write "\`\`\`$SHLANG"
    write "$funcname() "
    write "\`\`\`"
    write ""

    if [ -n "$summary" ]; then
        write "*$summary*"
        write ""
    fi

    if [ -n "$description" ]; then
        write "$description"
        write ""
    fi

    if [ ${#PARAMS[@]} -gt 0 ]; then
        # Separate the keys and their values into each their own array
        for key in "${!PARAMS[@]}"; do
            tableparamskey+=("${key#*:} (${key%%:*})")
            tableparamsval+=("${PARAMS[$key]}")
        done

        # Get the longest lines so that we can pad and properly format tables
        for key in "${tableparamskey[@]}"; do
            take_if_higher $maxkeylength ${#key} "maxkeylength"
        done
        for val in "${tableparamsval[@]}"; do
            take_if_higher $maxvallength ${#val} "maxvallength"
        done

        # Write out the parameters and their descriptions into a formatted table
        # We loop from the back since the associative arrays are reversed
        for ((i=${#PARAMS[@]}-1; i>=0; i--)); do
            towrite="| $(pad_string "${tableparamskey[$i]}" $maxkeylength) |"
            towrite+=" $(pad_string "${tableparamsval[$i]}" $maxvallength) |"
            write "$towrite"
        done

        maxkeylength=0
        maxvallength=0
        write ""
    fi

    # Write out return type
    if [ -n "${PROPERTIES[return]}" ]; then
        line="${PROPERTIES[return]}"
        local returnpropertytype="${line%% *}"
        line="${line#* }"

        write "**return ($returnpropertytype)** - $line"
        write ""

        # Remove return from array by recreating one
        for key in "${!PROPERTIES[@]}"; do
            if [ "$key" != "return" ]; then
                temparray[$key]="${PROPERTIES[$key]}"
            fi
        done

        PROPERTIES=()

        for key in "${!temparray[@]}"; do
            PROPERTIES[$key]="${temparray[$key]}"
        done
    fi

    # Write the remaining properties in a list
    local count=0
    local proplength=${#PROPERTIES[@]}

    if [ $proplength -gt 0 ]; then
        towrite=""

        for key in "${!PROPERTIES[@]}"; do
            count=$(($count+1))

            if [ $count -lt $proplength ]; then
                towrite+="$key: ${PROPERTIES[$key]}, "
            else
                towrite+="$key: ${PROPERTIES[$key]}"
            fi
        done

        write "*$towrite*"
        write ""
    fi

    return 0
}


#/
# Parses the file's comments to markdown
#
# The function writes the content to OUTPUT which can be set by the -o flag.
# It can parse both single and multiline comments. A DocBlock comment is started
# and ended with the "#/" character combination
#
# @param string $1 The file that will be processed
# @param string $2 An optional file heading. If not set then it will be extracted from the file name
# @return int It only returns 0 if no errors hindered the execution
#
# @author Niklas Rosenqvist
#/
function parse_file() {
    local file="$1"
    local lineno=0
    local title=""
    local parsingblock=1
    local summary=""
    local description=""
    local property=1
    local param=1
    local lastproperty=""
    local lineofblock=0
    local singleline=1
    local checkname=1
    local funcname=""
    local first=""
    local second=""

    # Write file heading
    if [ -n "$2" ]; then
        title="$2"
    else
        title="$(basename "$file")"

        if [ $EXTENSION -ne 0 ]; then
            title="${title%.*}"
        fi

        if [ $CAPITALIZE -eq 0 ]; then
            title="${title^}"
        fi
    fi

    write "$title"
    write "$(repeat_character "=" ${#title})"
    write ""

    # Process the file
    while IFS= read -r line; do
        lineno=$(($lineno+1))

        # Convert tabs to spaces and remove double spaces
        line="${line//	/ }" # tabs
        line="${line//  / }" # double spaces

        # Trim trailing and leading whitespace from line
        line="$(trim_whitespace "$line")"

        # Get the shell script language for syntax highlighting from the first line of the file
        if [ $lineno -eq 1 ] && [ "${line:0:2}" = "#!" ]; then
            SHLANG="$(basename "${line:2}")"

            # Only allow GitHub supported shells (sh/zsh/bash), if not one then default to "sh"
            if ! [ "$SHLANG" = "bash" -o "$SHLANG" = "sh" -o "$SHLANG" = "zsh" ]; then
                SHLANG="sh"
            fi
            continue
        fi

        # Check if this line contains the function name,
        # if it does we start printing out what we've collected
        if [ $checkname -eq 0 ] && [ -n "$line" ]; then
            checkname=1

            # Extract the function name
            first="${line%% *}"
            line="${line#* }"
            second="${line%% *}"

            if [ "$first" = "function" ]; then
                funcname="${second%%()*}"
            fi

            # Write the DocBlock to the output file
            write_block "$funcname" "$summary" "$description"
            continue
        fi

        # If this is the end of a DocBlock we will start searching for the function definition
        if [ "$line" = "#/" ] && [ $parsingblock -eq 0 ]; then
            parsingblock=1
            checkname=0
            continue
        fi

        # Is this the start of a DocBlock? Reset variables and start parsing
        if [[ "$line" == "#/"* ]] && [ $parsingblock -eq 1 ]; then
            parsingblock=0
            lineofblock=0
            description=""
            summary=""
            funcname=""
            property=1
            PARAMS=()
            PROPERTIES=()

            # Is it a single line block?
            if [ ${#line} -gt 2 ] && [ "${line:$((${#line}-2)):2}" = "#/" ]; then
                # Change the line so that it's formatted as a regular DocBlock content line
                line="# $(trim_whitespace "${line:2:$((${#line}-4))}")"
                singleline=0
            else
                continue
            fi
        fi

        # Are we parsing a comment block?
        if [ $parsingblock -eq 0 ]; then
            lineofblock=$(($lineofblock+1))
            line="${line:2}"

            # Only parse lines that aren't blank
            if [ -n "$line" ]; then
                # Parse property
                if [ "${line:0:1}" = "@" ]; then
                    lastproperty="${line:1}"
                    lastproperty="${lastproperty%% *}"
                    param=1
                    property=0

                    # Is the property a param?
                    if [ "$lastproperty" = "param" ]; then
                        param=0
                        line="${line#* }"
                        first="${line%% *}"
                        line="${line#* }"
                        second="${line%% *}"

                        if [ "${first:0:1}" = "$" ]; then
                            lastproperty="any:$first"
                        else
                            lastproperty="$first:$second"
                            line="${line#* }"
                        fi

                        PARAMS["$lastproperty"]="$line"
                    else
                        PROPERTIES["$lastproperty"]="${line#* }"
                    fi
                else
                    line="$(trim_whitespace "$line")"

                    if [ $property -eq 0 ]; then
                        if [ $param -eq 0 ]; then
                            PARAMS["$lastproperty"]+=" $line"
                        else
                            PROPERTIES["$lastproperty"]+=" $line"
                        fi
                    else
                        # If not a property then either a summary or description
                        if [ $lineofblock -eq 1 ]; then
                            summary="$line"
                        else
                            # Add a space if we're on a multiline description
                            if [ -n "$description" ]; then
                                description+=" "
                            fi

                            description+="$line"
                        fi
                    fi
                fi
            fi

            # Is this the end of a single line block?
            if [ $singleline -eq 0 ]; then
                parsingblock=1
                singleline=1
                checkname=0
            fi
        fi
    done < "$file"

    # Append the copyright statement
    if [ -n "$COPYRIGHT" ]; then
        write "$(repeat_character "-" ${#COPYRIGHT})"
        write "$COPYRIGHT"
        write ""
    fi

    return 0
}

# Parse the options
while getopts "t:fo:xc:TC" opt; do
    case "$opt" in
        t)
            # Specify file heading
            TITLE="$(trim_whitespace "$OPTARG")"
        ;;
        f)
            # Set if you want to allow overwrites
            FORCE=0
        ;;
        o)
            # Specify output file/dir
            OUTPUT="$OPTARG"
        ;;
        x)
            # Set if you want file extensions in headings
            EXTENSION=0
        ;;
        c)
            # Copyright statement
            COPYRIGHT="$(trim_whitespace "$OPTARG")"
        ;;
        C)
            # Capitalize file names
            CAPITALIZE=0
        ;;
        T)
            # Create a Table Of Contents
            ToC=0
        ;;
        \?)
            echo "Invalid option: $OPTARG" 1>&2
            echo "Aborting..."
            exit 1
        ;;
    esac
done

shift $(($OPTIND-1))

# If a directory is specified we parse a directory and create an index file with a table of contents
if [ -d "$1" ]; then
    # Set the output dirs
    if [ -z "$OUTPUT" ]; then
        OUTPUT="./"
    fi

    files_parsed=()
    filesdir="$OUTPUT"
    mkdir -p "$filesdir"

    # Loop through all files found in the directory
    while IFS= read -r file; do
        filename="$(basename "$file")"
        filename="${filename%.*}.md"

        if [ $CAPITALIZE -eq 0 ]; then
            filename="${filename^}"
        fi

        OUTPUT="$filesdir/$filename"

        # Abort if we have to overwrite a file and the forced flag is off
        if [ -e "$OUTPUT" ]; then
            if [ $FORCE -ne 0 ]; then
                echo "The file \"$OUTPUT\" already exists. If you want to continue anyway and overwrite, specify the flag -f (force)." 1>&2
                echo "Aborting..."
                exit 1
            else
                rm -f "$OUTPUT"
            fi
        fi

        # Parse the file and save a reference for the table of contents
        parse_file "$file"
        files_parsed+=("$OUTPUT")
    done < <(find "$1" -maxdepth 1 -type f -iregex ".*\.\(sh\|bash\|zsh\)" | sort -V)

    # Create the Table of Contents if set to do so
    if [ $ToC -eq 0 ]; then
        # Write file heading
        outputroot="$(dirname "$filesdir")"
        OUTPUT="$outputroot/Home.md"

        # Abort if we have to overwrite a file and the forced flag is off
        if [ -e "$OUTPUT" ]; then
            if [ $FORCE -ne 0 ]; then
                echo "The file \"$OUTPUT\" already exists. If you want to continue anyway and overwrite, specify the flag -f (force)." 1>&2
                echo "Aborting..."
                exit 1
            else
                rm -f "$OUTPUT"
            fi
        fi

        # Set the file heading
        if [ -n "$TITLE" ]; then
            heading="$TITLE"
        else
            heading="Table of contents"
        fi

        write "$heading"
        write "$(repeat_character "=" ${#heading})"
        write ""

        # Write the table of contents
        for file in "${files_parsed[@]}"; do
            title="$(basename "$file")"

            if [ $EXTENSION -ne 0 ]; then
                title="${title%.*}"
            fi
            #echo "$outputroot : $file"
            write "- [$title]($(strip_multi_slash "${file/$outputroot\//}"))"
        done
    fi
# Processing a single file
else
    # Set the output file
    if [ -z "$OUTPUT" ]; then
        OUTPUT="$(basename "$1")"
        OUTPUT="${OUTPUT%.*}.md"

        if [ $CAPITALIZE -eq 0 ]; then
            OUTPUT="${OUTPUT^}"
        fi
    else
        # If output is set to directory we create the new file within the directory
        if [ -d "$OUTPUT" ]; then
            filename="$(basename "$1")"

            if [ $CAPITALIZE -eq 0 ]; then
                filename="${filename^}"
            fi

            OUTPUT="$OUTPUT/$filename"
            OUTPUT="${OUTPUT%.*}.md"
        fi
    fi

    # Abort if we have to overwrite a file and the forced flag is off
    if [ -e "$OUTPUT" ]; then
        if [ $FORCE -ne 0 ]; then
            echo "The file \"$OUTPUT\" already exists. If you want to continue anyway and overwrite, specify the flag -f (force)." 1>&2
            echo "Aborting..."
            exit 1
        else
            rm -f "$OUTPUT"
        fi
    fi

    # Parse the file
    if [ -n "$TITLE" ]; then
        parse_file "$1" "$TITLE"
    else
        parse_file "$1"
    fi
fi

exit 0

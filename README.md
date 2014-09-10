Shocker
=======

Shocker is an utility to generate markdown formatted documentation from shell source files. The resulting files can easily be used to create an online API since it's compatible with the excellent [mkdocs](http://www.mkdocs.org/)! The generated markdown is "[GitHub flavoured](https://help.github.com/articles/github-flavored-markdown)", meaning that it supports GitHub's (and mkdocs) syntax highlighting and table definitions.

Comments should be formatted in a DocBlocks syntax and can be either single line or multiline. The start and end of a comment that should be processed is marked by the following character combination: `#/`

An example of a multiline comment:
```bash
#/
# The first line is a short one line summary of the function
#
# The second line/paragraph is a longer description that IDE's
# sometimes use for giving helpful tooltips. Here you can explain
# the usage of the function much more detailed. As you can see
# can all parts of the DocBlock, except the summary, consist of
# multiple lines.
#
# @param string   $1   You can use as much spacing, both tabs and
#                      space, to make the definitions more readable
# @param int      $2   A second parameter which is defined as int
# @return int          Either 0 or 1
#
# @author Niklas Rosenqvist
# @other  If you don't want to write a summary or description can
#         both be omitted without any issues.
#/
function example() {
    ...
}
```

Examples of singleline comments:
```bash
#/ Boy! That was a short summary #/
function example() {
    ...
}

#/ @author Niklas Rosenqvist #/
function example2() {
    ...
}
```

The wiki is the result of Shocker running on it's own source file. [Check it out!](https://github.com/nsrosenqvist/shocker/wiki)

## Installation

Clone the repository and then use make.

```bash
git clone https://github.com/nsrosenqvist/shockey.git && cd shocker
make && sudo make install
```

## Usage

The argument you provide can either be a directory containing shell files or a single file. The program's output is a bit different depending on what you specify.

Single file example:
```bash
shocker -x 1 -c "Copyright © 2014, Niklas Rosenqvist" -o documentation.md input-file.sh
```

In the above example the input was a single source file. By default the output would have been written to "input-file.md" but we specifically told it to output it to "documentation.md". The -x flag made the resulting file's heading to be "input-file" instead of "input-file.sh", it removed the extension from the file name (-t could be used instead to set a custom heading). The flag -c set a copyright statement to the bottom of the file.

Directory example:
```bash
shocker -Tx 1 -c "Copyright © 2014, Niklas Rosenqvist" -t "API" -o docs dir/input-dir
```

This time we process all the files in the directory "dir/input-dir" and output it to "docs/". We've set the flag -T (uppercase) which generates a table of contents file in the directory above the output directory. Now the -t (lowercase) sets the heading of the Table of contents file instead since we can't set the same heading for each and every file, it wouldn't make sense. A project that uses this for it's documentation is the QuickScript framework - refer to [their Makefile](https://github.com/nsrosenqvist/quickscript/blob/master/Makefile) for more information.

### Parameters

Parameter | Explanation
--------- | -----------
-t        | Set the file heading
-f        | Allow file overwrites. If not set the program will abort when it attempts to overwrite an existing file.
-o        | Output file or directory
-x        | Set to include file extensions in headings.
-c        | Specify a copyright statement that will be added to the end of each file.
-T        | Create an index file with a table of contents (Will be named "Home.md"), only applicable when processing directories.
-C        | Set to capitalize file names and headings.
-G        | Optimize output for GitHub, rather than mkdocs (this changes how files in the table of contents are linked)

## Development

Feel free to make pull requests with your own contributions. If you want to help out and don't know what to do you can try to tackle an issue from the [issue tracker](https://github.com/nsrosenqvist/shocker/issues).

## Notice

The program is licensed under LGPL v2.1, please refer to the LICENSE file for more information.

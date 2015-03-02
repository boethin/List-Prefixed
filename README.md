# NAME

List::Prefixed - Prefixed string list implementation

# SYNOPSIS

    use List::Prefixed;

    # construct a new prefixed tree
    $folded = List::Prefixed->fold(qw( Fu Foo For Form Foot Food Ba Bar Baz ));

    # get all items sharing a common prefix
    @list = $folded->list('Fo'); # Foo, Food, Foot, For, Form

    # serialize as regular expression
    $regex = $folded->regex; # '(?:Ba(?:r|z)?|F(?:o(?:o(?:d|t)?|r(?:m)?)|u))'

    # de-serialize from regular expression
    $unfolded = List::Prefixed->unfold($regex);

# DESCRIPTION

The idea of Prefixed Lists comes from regular expressions determining a finite
list of words, like this:

    /(?:Ba(?:r|z)?|F(?:o(?:o(?:d|t)?|r(?:m)?)|u))/
    

The expression above matches exactly these strings:

    "Ba", "Bar", "Baz", "Foo", "Food", "Foot", "For", "Form", "Fu".

Representing a string list that way may have some advantages in certain situations:

- The representation as a regular expression provides efficient methods to test whether
or not an arbitrary string starts or ends with an element from the list or is contained
in the list itself.
- The representaion is compressing, depending on how many shared prefixes appear in a list.
- Conversely, a prefixed list can be efficiently set up from such a regular expression.
Thus, the prefixed list leads to a natural way of serialization and de-serialization.
- Sub lists sharing a common prefix can be extracted efficently from a prefixed list. 
This leads to an efficient implementation of auto-completion.

# METHODS

## new

    $prefixed = List::Prefixed->new( @list );

This is an alias of the [fold](http://search.cpan.org/perldoc?fold) method.

## fold

    $prefixed = List::Prefixed->fold( @list );

Constructs a new [List::Prefixed](http://search.cpan.org/perldoc?List::Prefixed) tree from the given string list.

## unfold

    $prefixed = List::Prefixed->unfold( $regex );

Constructs a new [List::Prefixed](http://search.cpan.org/perldoc?List::Prefixed) tree from a regular expression string.
The string argument shuld be obtained from the [regex](http://search.cpan.org/perldoc?regex) method.

## list

    @list = $prefixed->list;
    @list = $prefixed->list( $string );

Returns the list of strings starting with the given argument if a string argument
is present or the whole list otherwise. In scalar context an ARRAY reference is
returned.

## regex

    $regex = $prefixed->regex;

Returns a minimized regular expression (as string) matching exactly the strings
the object has been constructed with.

You can control the escaping style of the expression. The default behavior is
to apply Perl's P<quotemeta> function and replace any non-ASCII character with
`\x{FFFF}`, where `FFFF` is the hexadecimal character code. This is the
Perl-compatible or PCRE style. To obtain an expression compatible with Java
and the like, use

    use List::Prefixed uc_escape_style => 'Java'; # \uFFFF style

To skip Unicode escaping completely, use

    use List::Prefixed uc_escape_style => undef;  # do not escape

Alternatively, you can control the style at runtime by way of
[CONFIGURATION VARIABLES](#configuration variables).

# CONFIGURATION VARIABLES

- _$UC\_ESCAPE\_STYLE_

Control the escaping style for Unicode (non-ASCII) characters.
The value can be ono of the following:

    - _'PCRE'_

    Default style `\x{FFFF}`

    - _'Java'_

    Java etc. style `\uFFFF`

    - _undef_

    Do not escape Unicode characters at all. This may result in shorter expressions
    but may cause encoding issues under some circumstances.

    - _$REGEX\_ESCAPE_, _$REGEX\_UNESCAPE_

    By providing string functions one can customize the escaping behavior arbitrarily.
    In this case, `$UC_ESCAPE_STYLE` has no effect.

# EXPORT

Strictly OO, exports nothing.

# REPOSITORY

[https://github.com/boethin/List-Prefixed](https://github.com/boethin/List-Prefixed)

# AUTHOR

Sebastian Böthin, <boethin@xn--domain.net>

# COPYRIGHT AND LICENSE

Copyright (C) 2015 by Sebastian Böthin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

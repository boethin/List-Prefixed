package List::Prefixed;
use 5.014002;
use strict;
use warnings;
use Carp;

# -- globals --

our $VERSION = '0.01';

# Public global variables.
our (
    $UC_ESCAPE_STYLE,   # "PCRE" | "Java" | undef
    $REGEX_ESCAPE,      # CODE: Str -> Str
    $REGEX_UNESCAPE     # CODE: Str -> Str
  );

# The default unicode escape format is the PCRE style \x{FF}.
# - To output regular expressions in \uFFFF (Java, etc.) style, set $UC_ESCAPE_STYLE to 'Java'.
# - To avoid replacement of non-ASCII characters at all, set $UC_ESCAPE_STYLE to undef.
$UC_ESCAPE_STYLE = 'PCRE';

# Unicode escape styles
my %UC_escape = (
  PCRE => [ '\\x{%X}' => qr/\\x\{([0-9A-F]{2,6})}/i ],
  Java => [ '\\u%04X' => qr/\\u([0-9A-F]{4,6})/i ],
);

# Get the escape form (0) / unescape regex (1) depending on $UC_ESCAPE_STYLE.
my $UC_ESCAPE = sub {
  return undef unless defined $UC_ESCAPE_STYLE;
  return $UC_escape{$UC_ESCAPE_STYLE}[$_[0]] if exists $UC_escape{$UC_ESCAPE_STYLE};
  croak "Unsupported UC_ESCAPE_STYLE: '$UC_ESCAPE_STYLE'"; # RTFM
};

# The default escape procedure.
$REGEX_ESCAPE = sub {

  # quotemeta EXPR
  #   Returns the value of EXPR with all non-"word" characters backslashed.
  #   (That is, all characters not matching "/[A-Za-z_0-9]/" will be preceded by
  #   a backslash in the returned string, regardless of any locale settings.)
  local $_ = quotemeta $_[0];

  # additionally apply $UC_ESCAPE_STYLE
  if ( defined(my $uc_form = &$UC_ESCAPE(0)) ) {
    s/(\P{ASCII})/ sprintf $uc_form => ord $1 /eg;
  }
  
  $_;
};

# The default unescape procedure.
$REGEX_UNESCAPE = sub {
  local $_ = $_[0];

  # apply $UC_ESCAPE_STYLE first
  if ( defined(my $uc_re = &$UC_ESCAPE(1)) ) {
    s/$uc_re/ chr hex $1 /eg;
  }

  # replace backslash escapes as inserted by quotemeta
  s/\\([^A-Z0-9_])/$1/gi;
  
  $_;
};

# Globals may passed as module arguments, e.g.:
#
#   use List::Prefixed uc_escape_style => 'Java';
#
sub import {
  shift; # __PACKAGE__;
  my %args = @_;

  $UC_ESCAPE_STYLE = $args{uc_escape_style} if exists $args{uc_escape_style};
  $REGEX_ESCAPE = $args{regex_escape} if exists $args{regex_escape};
  $REGEX_UNESCAPE = $args{regex_unescape} if exists $args{regex_unescape};
}

# -- private --

#my $RE_PREFIX = qr//;


# -- public --



# Construct a Prefixed object from a string list
sub fold {

  local *reduce = sub {
    my ($prefix, $nlist, $opt) = @{$_[0]};

    return $_[0] unless ref $nlist && @$nlist > 1;

    # 1st char of the prefix of 1st node in list
    my ($c);

    # check whether 2nd prefix starts with same letter as the 1st
    if ( length $nlist->[0][0] ) {
      $c = substr $nlist->[0][0], 0, 1; # first char
      undef $c unless $c eq substr $nlist->[1][0], 0, 1;
    }

    unless ( defined $c )
    {
      return $_[0] unless @$nlist > 2;

      # try to reduce next list part
      my $first = shift @$nlist;
      my $next = reduce(bless ['', $nlist, 0]);
      return bless [ $prefix, [ $first, $next ], $opt] if length $next->[0];

      # couldn't be reduced
      return bless [ $prefix, [ $first, @{$next->[1]} ], $opt ];
    }

    # reduce any ensuing node whose prefix starts with $c
    my @new;
    my $newopt = undef;
    my $qc = quotemeta $c;
    while ( @$nlist )
    {
      last unless $nlist->[0][0] =~ s/^$qc//;

      # reduce node or detect new optional node
      my $n = shift @$nlist;
      if ( length $n->[0] )
      {
        push @new, $n;
        next;
      }
      $newopt = 1;
    }

    if ( @$nlist || $opt )
    {
      my $new = reduce(bless [ $c, [ @new ], $newopt ]);
      if ( @$nlist )
      {
        # reduce remaining nlist
        my $next = reduce(bless ['', $nlist, 0]);
        return bless [ $prefix, [ $new, $next ], $opt] if length $next->[0];

        # couldn't be reduced
        return bless [ $prefix, [ $new, @{$next->[1]} ], $opt ];
      }

      # current node is optional
      return bless [ $prefix, [ $new, @$nlist ], $opt ];
    }

    # nothing left to reduce
    reduce(bless [ $prefix.$c, [ @new ], $newopt ]);
  };

  shift; # __PACKAGE__
  my @s = sort keys %{ { map{ $_ => 1 } @_ } }; # unique sorted
  return bless [$_[0],[],undef] if @s == 1; # singleton
  reduce(bless [ '', [( map { [$_] } @s )],undef]);
};

my $RE_PREFIX = qr/(?:\\(?:.|\n)|[^\|\(\)])+/;

# Construct a Prefixed object from a regular expression.
#
# Solution based on basic regular expression evaluation.
sub unfold {
  shift; # __PACKAGE__
  my ($regex) = @_;
  my ($nn,$cn,@st);
  while ( length $regex ) {

    # prefix string
    if ( $regex =~ s/^\|?($RE_PREFIX)// ) {
      my $p = &$REGEX_UNESCAPE($1);
      if ( $cn ) {
        $cn->[1] = [] unless ref $cn->[1];
        push @{$cn->[1]}, ($nn = bless [$p]);
      }
      else {
        $cn = $nn = bless [$p];
      }
      next;
    }

    # node start
    if ( $regex =~ s/^\(\?:// ) {
      if ( $nn ) {
        $cn = $nn;
      }
      else {
        $cn = $nn = bless [''];
      }
      push @st, $nn;
      next;
    }

    # node end
    if ( $regex =~ s/^\)(\?)?// ) {
      $cn = pop @st;
      $cn->[2] = defined $1 ? 1 : undef;
      $cn = $st[$#st] if @st;
      next;
    }

    die "invalid: '$regex'";
  }
  $cn;
};


sub regex {

  local *to_regex_rec = sub {
    my ($prefix, $nlist, $opt) = @{$_[0]};
    my $rv = &$REGEX_ESCAPE($prefix);
    if ( $nlist && @$nlist )
    {
      $rv .= '(?:'.(join '|', map { to_regex_rec($_) } @$nlist).')';
      $rv .= '?' if $opt;
    }
    $rv;
  };

  my $node = shift;
  to_regex_rec($node);
}

sub list {
  my $node = shift;
  my ($s) = @_;
  $s = '' unless defined $s;
  my $qs = quotemeta $s;

  local *list_rec = sub {
    my ($p,$n,$list) = @_;
    my ($prefix, $nlist, $opt) = @$n;
    my $p2 = $p.$prefix;
    my $qp2 = quotemeta $p2;
    my ($push,$continue);
    if ( $p2 =~ m/^$qs/ ) {
      # current prefix starts with search string
      $push = $continue = 1;
    }
    elsif ( $s =~ m/^$qp2/ ) {
      # search string starts with current prefix
      $continue = 1;
    }

    if ($nlist && @$nlist) {
      push @$list, $p2 if $push && $opt;
      if ( $continue ) {
        list_rec($p2,$_,$list) foreach @$nlist;
      }
    }
    elsif ( $push ) {
      push @$list, $p2;
    }
  };

  my @list;
  list_rec('',$node,\@list);
  wantarray ? @list : \@list;
}


# Standard new constructor is an alias for fold.
*new = \&fold;

1;
__END__

=encoding utf8

=head1 NAME

List::Prefixed - Prefixed string list implementation

=head1 SYNOPSIS

  use List::Prefixed;

  # construct a new prefixed tree
  $folded = List::Prefixed->fold(qw( Fu Foo For Form Foot Food Ba Bar Baz ));

  # get all items sharing a common prefix
  @list = $folded->list('Fo'); # Foo, Food, Foot, For, Form

  # serialize as regular expression
  $regex = $folded->regex; # '(?:Ba(?:r|z)?|F(?:o(?:o(?:d|t)?|r(?:m)?)|u))'

  # de-serialize from regular expression
  $unfolded = List::Prefixed->unfold($regex);

=head1 DESCRIPTION

The idea of Prefixed Lists comes from regular expressions determining a finite
list of words, like this:

  /(?:Ba(?:r|z)?|F(?:o(?:o(?:d|t)?|r(?:m)?)|u))/
  
The expression above matches exactly these strings:

  "Ba", "Bar", "Baz", "Foo", "Food", "Foot", "For", "Form", "Fu".

Representing a string list that way may have some advantages in certain situations:

=over 4

=item *

The representation as a regular expression provides efficient methods to test whether
or not an arbitrary string starts or ends with an element from the list or is contained
in the list itself.

=item *

The representaion is compressing, depending on how many shared prefixes appear in a list.

=item *

Conversely, a prefixed list can be efficiently set up from such a regular expression.
Thus, the prefixed list leads to a natural way of serialization and de-serialization.

=item *

Sub lists sharing a common prefix can be extracted efficently from a prefixed list. 
This leads to an efficient implementation of auto-completion.

=back

=head1 METHODS

=head2 new

  $prefixed = List::Prefixed->new( @list );

This is an alias of the L<fold|fold> method.

=head2 fold

  $prefixed = List::Prefixed->fold( @list );

Constructs a new L<List::Prefixed|List::Prefixed> tree from the given string list.

=head2 unfold

  $prefixed = List::Prefixed->unfold( $regex );

Constructs a new L<List::Prefixed|List::Prefixed> tree from a regular expression string.
The string argument shuld be obtained from the L<regex|regex> method.

=head2 list

  @list = $prefixed->list;
  @list = $prefixed->list( $string );

Returns the list of strings starting with the given argument if a string argument
is present or the whole list otherwise. In scalar context an ARRAY reference is
returned.

=head2 regex

  $regex = $prefixed->regex;

Returns a minimized regular expression (as string) matching exactly the strings
the object has been constructed with.

You can control the escaping style of the expression. The default behavior is
to apply Perl's P<quotemeta> function and replace any non-ASCII character with
C<\x{FFFF}>, where C<FFFF> is the hexadecimal character code. This is the
Perl-compatible or PCRE style. To obtain an expression compatible with Java
and the like, use

  use List::Prefixed uc_escape_style => 'Java'; # \uFFFF style

To skip Unicode escaping completely, use

  use List::Prefixed uc_escape_style => undef;  # do not escape

Alternatively, you can control the style at runtime by way of
L<CONFIGURATION VARIABLES|configuration variables>.

=head1 CONFIGURATION VARIABLES

=over 4

=item I<$UC_ESCAPE_STYLE>

Control the escaping style for Unicode (non-ASCII) characters.
The value can be ono of the following:

=over 4

=item I<'PCRE'>

Default style C<\x{FFFF}>

=item I<'Java'>

Java etc. style C<\uFFFF>

=item I<undef>

Do not escape Unicode characters at all. This may result in shorter expressions
but may cause encoding issues under some circumstances.

=item I<$REGEX_ESCAPE>, I<$REGEX_UNESCAPE>

By providing string functions one can customize the escaping behavior arbitrarily.
In this case, C<$UC_ESCAPE_STYLE> has no effect.

=back

=back

=head1 EXPORT

Strictly OO, exports nothing.

=head1 REPOSITORY

L<https://github.com/boethin/List-Prefixed>

=head1 AUTHOR

Sebastian Böthin, E<lt>boethin@xn--domain.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by Sebastian Böthin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

package Lingua::Stem;

# $RCSfile: Stem.pm,v $ $Revision: 1.2 $ $Date: 1999/06/16 17:45:28 $ $Author: snowhare $

#######################################################################
# Initial POD Documentation 
#######################################################################

=head1 NAME

Lingua::Stem - Stemming of words  

=head1 SYNOPSIS

    use Lingua::Stem qw(stem);
    my $stems   = stem(@words);

    or for the OO inclined,

    use Lingua::Stem;
    my $stemmer = Lingua::Stem->new(-locale => 'EN-UK');
    my $stems   = $stemmer->stem(@words);

=head1 DESCRIPTION

This routine applies stemming algorithms to its parameters,
returning the stemmed words as appropriate to the selected
locale.

You can import some or all of the class methods.

use Lingua::Stem qw (stem add_exceptions delete_exceptions 
                     get_exceptions set_locale get_locale 
                     :all :locale :exceptions :stem);

 :all        - imports  stem add_exceptions delete_exceptions get_exceptions 
               set_locale get_locale
 :stem       - imports  stem
 :locale     - imports  set_locale get_locale
 :exceptions - imports  add_exceptions delete_exceptions get_exceptions

=head1 CHANGES

 0.30 1999.06.24 - Replaced core of 'En' stemmers with code from
                   Jim Richardson <jimr@maths.usyd.edu.au>
                   Aliased 'en-us' and 'en-uk' to 'en'
                   Fixed 'SYNOPSIS' to correct return value
                   type for stemmed words (SYNOPIS error spotted 
                   by <Arved_37@chebucto.ns.ca>)

 0.20 1999.06.15 - Changed to '.pm' module, moved into Lingua:: namespace,
                   added OO interface, optionalized the export of routines 
                   into the caller's namespace, added named parameter
                   initialization, stemming exceptions, autoloaded
                   locale support and isolated case flattening to
                   localized stemmers prevent i18n problems later. 
 
                   Input and output text are assumed to be in UTF8
                   encoding (no operational impact right now, but
                   will be important when extending the module to
                   non-English).

=cut

#######################################################################
# Initialization
#######################################################################

use strict;
use Exporter;
use Carp;
use Lingua::Stem::AutoLoader;
use vars qw (@ISA @EXPORT_OK %EXPORT_TAGS @EXPORT $VERSION);

BEGIN {
    $VERSION     = '0.30';
    @ISA         = qw (Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw (stem add_exceptions delete_exceptions get_exceptions set_locale get_locale);
    %EXPORT_TAGS = ( 'all' => [qw (stem add_exceptions delete_exceptions get_exceptions set_locale get_locale)],
                    'stem' => [qw (stem)],
                  'locale' => [qw (set_locale get_locale)],
              'exceptions' => [qw (add_exceptions delete_exceptions get_exceptions)],
                 );
}

my $defaults = {
         -locale => 'en',
        -stemmer => \&Lingua::Stem::En::stem,
     -exceptions => {},
  -known_locales => { 'en' => \&Lingua::Stem::En::stem,
                   'en-us' => \&Lingua::Stem::En::stem,
                   'en-uk' => \&Lingua::Stem::En::stem, 
                   },
    };

#######################################################################
# Methods
#######################################################################

=head1 METHODS

=cut

#######################################################################

=over 4

=item C<new(...);>

Returns a new instance of a Lingua::Stem object and, optionally, selection
of the locale to be used for stemming.

Examples:

  # By default the locale is us-en 
  $us_stemmer = Lingua::Stem->new;

  # Overriding the default for a specific instance
  $uk_stemmer = Lingua::Stem->new({ -locale => 'en-uk' });

  # Overriding the default for a specific instance and changing the default
  $uk_stemmer = Lingua::Stem->new({ -default_locale => 'en-uk' });

=back

=cut

sub new {
    my $proto = shift;
    my $class = ref ($proto) || $proto;
    my $self = bless {},$class;

    # Set the defaults
    %{$self->{'Lingua::Stem'}->{-exceptions}} = %{$defaults->{-exceptions}};
    $self->{'Lingua::Stem'}->{-locale}        = $defaults->{-locale};
    $self->{'Lingua::Stem'}->{-stemmer}       = $defaults->{-stemmer};

    # Handle any passed parms
    my @errors = ();
    if ($#_ > -1) {
        my $parm_ref = $_[0];
        if (not ref $parm_ref) {
            $parm_ref = {@_};
        }
        foreach my $key (keys %$parm_ref) {
            my $lc_key = lc ($key);
            if    ($lc_key eq '-locale')         { $self->set_locale($parm_ref->{$key});  }
            elsif ($lc_key eq '-default_locale') { set_locale($parm_ref->{$key});         }
            else { push (@errors," '$key' => '$parm_ref->{$key}'"); }
        }
    }
    if ($#errors > -1) {
        croak (__PACKAGE__ . "::new() - unrecognized parameters passed:" . join(', ',@errors));
    }

    $self;
}

#######################################################################

=over 4

=item C<set_locale($locale);>

Sets the locale to one of the recognized locales. Currently,
'en', 'en-us' and 'en-uk' are the only recognized locales. All
locale identifiers are converted to lowercase.

Called as a class method, it changes the default locale for all 
subseqently generated object instances.

Called as an instance method, it only changes the locale for 
that particular instance. 

'croaks' if passed an unknown locale.

Examples:

 # Change default locale 
 Lingua::Stem::set_locale('en-uk'); # UK's spellings 

 # Change instance locale
 $self->set_locale('en-us');  # US's spellings 

=back

=cut

sub set_locale {
    my ($self)   = shift;

    my ($locale);
    if (ref $self) {
        ($locale) = @_;
        $locale   = lc $locale;
        if (not exists $defaults->{-known_locales}->{$locale}) {
            croak (__PACKAGE__ . "::set_locale() - Unknown locale '$locale'");
        }
        $self->{'Lingua::Stem'}->{-locale} = $locale;
        $self->{'Lingua::Stem'}->{-stemmer} = $defaults->{-known_locales}->{$locale};
    } else {
        $locale = lc $self;
        if (not exists $defaults->{-known_locales}->{$locale}) {
            croak (__PACKAGE__ . "::set_locale() - Unknown locale '$locale'");
        }
        $defaults->{-locale} = $locale;
        $defaults->{-stemmer} = $defaults->{-known_locales}->{$locale};
    }
}

#######################################################################

=over 4

=item C<get_locale;>

Called as a class method, returns the current default locale.

Example:

 $default_locale = Lingua::Stem::get_locale;

Called as an instance method, returns the locale for the instance

 $instance_locale = $stemmer->get_locale;

=back

=cut

sub get_locale {
    my ($self) = shift;

    if (ref $self) {
        return $self->{'Lingua::Stem'}->{-locale};
    } else {
        return $defaults->{-locale};
    }
}

#######################################################################

=over 4

=item C<add_exceptions($exceptions_hash_ref);>

Exceptions allow overriding the stemming algorithm on a case by case
basis. It is done on an exact match and substitution basis: If a passed
word is identical to the exception it will be replaced by the specified
value. No case adjustments are performed.

Called as a class method, adds exceptions to the default exceptions list
used for subsequently instantations of Lingua::Stem objects.

Example:

 # adding default exceptions
 Lingua::Stem::add_exceptions({ 'emily' => 'emily',
                                'driven' => 'driven',
                            });

Called as an instance method, adds exceptions only to the specific
instance.

 # adding instance exceptions
 $stemmer->add_exceptions({ 'steely' => 'steely' });

The exceptions shortcut the normal stemming - if an exception matches
no further stemming is performed after the substitution.

Adding an exception with the same key value as an already defined
exception replaces the pre-existing exception with the new value.

=back

=cut

sub add_exceptions {
    my ($self);

    my ($exceptions,$exception_list);
    my $reference =ref $_[0];
    if ($reference eq 'HASH') {
        ($exceptions) =  @_;
        $exception_list = $defaults->{-exceptions};
    } elsif (not $reference) {
        $exceptions = { @_ };
        $exception_list = $defaults->{-exceptions};
    } else {
        $self = shift;
        ($exceptions) = @_;
        $exception_list = $self->{'Lingua::Stem'}->{-exceptions};
    }
    while (my ($exception,$replace_with) = each %$exceptions) {
            $exception_list->{$exception} = $replace_with;
    }
}

#######################################################################

=over 4

=item C<delete_exceptions(@exceptions_list);>

The mirror of add_exceptions, this allows the _removal_ of exceptions
from either the defaults for the class or from the instance.

 # Deletion of exceptions from class default exceptions
 Lingua::Stem::delete_exceptions('aragorn','frodo','samwise');

 # Deletion of exceptions from instance
 $stemmer->delete_exceptions('smaug','sauron','gollum');

 # Deletion of all class default exceptions 
 delete_exceptions;

 # Deletion of all exceptions from instance
 $stemmer->delete_exceptions;

=back

=cut

sub delete_exceptions {
    my $self;

    my ($exception_list,$exceptions);
    if ($#_ == -1) {
        $defaults->{-exceptions} = {};    
        return;
    }
    my $reference =ref $_[0];
    if ($reference eq 'ARRAY') {
        ($exceptions) =  @_;
        $exception_list = $defaults->{-exceptions};
    } elsif (not $reference) {
        $exceptions = [@_];
        $exception_list = $defaults->{-exceptions};
    } else {
        $self = shift;
        if ($#_ == -1) {
            $self->{'Lingua::Stem'}->{-exceptions} = {};
        } else {
            $reference = ref $_[0];
            if ($reference eq 'ARRAY') {
                ($exceptions) =  @_;
                $exception_list = $self->{'Lingua::Stem'}->{-exceptions};
            } else {
                ($exceptions) = [@_];
                $exception_list = $self->{'Lingua::Stem'}->{-exceptions};
            }
        }
    }

    foreach (@$exceptions) { delete $exception_list->{$_}; }
}

#######################################################################

=over 4

=item C<get_exceptions;>

As a class method with no parameters it returns all the default exceptions 
as an anonymous hash of 'exception' => 'replace with' pairs.

Example:

 # Returns all class default exceptions
 $exceptions = Lingua::Stem::get_exceptions;

As a class method with parameters, it returns the default exceptions listed
in the parameters as an anonymous hash of 'exception' => 'replace with' pairs.
If a parameter specifies an undefined 'exception', the value is set to undef.

 # Returns class default exceptions for 'emily' and 'george'
 $exceptions = Lingua::Stem::get_exceptions('emily','george');

As an instance method, with no parameters it returns the currently active 
exceptions for the instance.

 # Returns all instance exceptions
 $exceptions = $stemmer->get_exceptions;

As an instance method with parameters, it returns the instance exceptions listed
in the parameters as an anonymous hash of 'exception' => 'replace with' pairs.
If a parameter specifies an undefined 'exception', the value is set to undef.

 # Returns instance exceptions for 'lisa' and 'bart'
 $exceptions = $stemmer->get_exceptions('lisa','bart');

=back

=cut

sub get_exceptions {

    my $exception_list = {};
    if ($#_ == -1) {
        %$exception_list = %{$defaults->{-exceptions}};
        return $exception_list;
    }
    my $reference = ref $_[0];
    if ($reference eq 'ARRAY') {
        %$exception_list = %{$defaults->{-exceptions}};
    } elsif ($reference) {
        my $self = shift;
        if ($#_ > -1) {
            foreach (@_) {
                $exception_list->{$_} = $self->{'Lingua::Stem'}->{-exceptions}->{$_};
            }
        } else {
            %$exception_list = %{$self->{'Lingua::Stem'}->{-exceptions}};
        }
    } else {
        foreach (@_) {
            $exception_list->{$_} = $_;
        }
    }
    $exception_list;
}

#######################################################################

=over 4

=item C<stem(@list);>

Called as a class method, it applies the default settings
and stems the list of passed words, returning an anonymous
array with the stemmed words in the same order as the passed
list of words.

Example:
    
    # Default settings applied
    my $stemmed_words = Lingua::Stem::stem(@words);

Called as an instance method, it applies the instance's settings
and stems the list of passed words, returning an anonymous
array with the stemmed words in the same order as the passed
list of words.

   # Instance's settings applied
   my $stemmed_words = $stemmer->stem(@words);

=back

=cut

sub stem {
    my $self;
    return [] if ($#_ == -1);
    my ($exceptions,$locale,$stemmer,$words);
    if (ref $_[0]) {
        my $self = shift;
        $exceptions = $self->{'Lingua::Stem'}->{-exceptions};
        $stemmer    = $self->{'Lingua::Stem'}->{-stemmer};
        $locale     = $self->{'Lingua::Stem'}->{-locale};
    } else {
        $exceptions = $defaults->{-exceptions};
        $stemmer    = $defaults->{-stemmer};
        $locale     = $defaults->{-locale};
    }
    &$stemmer({ -words => \@_, 
               -locale => $locale,
           -exceptions => $exceptions });
}

#######################################################################
# Terminal POD Documentation 
#######################################################################

=head1 NOTES

This is version 0.30. It started with the 'Text::Stem' module which
has been adapted into a more general frameword and moved into the more 
language oriented 'Lingua' namespace and re-organized to support a OOP
interface as well as switch core 'En' locale stemmers. 

Organization is such that extending this module to any number 
of languages should be direct and simple.

Case flattening is a function of the language, so the 'exceptions'
methods have to be used appropriately to the language. For 'En'
family stemming, use lower case words, only, for exceptions.

=head1 AUTHORS

 Benjamin Franz <snowhare@nihongo.org>
 Jim Richardson <imr@maths.usyd.edu.au>

=head1 SEE ALSO

 Lingua::Stem::En Lingua:Stem::En_Us Lingua::Stem::En_Uk

=head1 COPYRIGHT

Copyright 1999 

FreeRun Technologies, Inc (FreeRun), 
Jim Richardson, University of Sydney <imr@maths.usyd.edu.au>
and Benjamin Franz <snowhare@nihongo.org>. All rights reserved.

This software may be freely copied and distributed under the same
terms and conditions as Perl.

=head1 BUGS

None known.

=head1 TODO

Add more languages. Specifically integrate Text::German for 'de' locale.

=cut

1;

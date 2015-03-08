package Strehler::Helpers;

use strict;
use Dancer2 0.154000;
use Strehler;
use Unicode::Normalize;
use Text::Unidecode;

#Barely copied from http://stackoverflow.com/questions/4009281/how-can-i-generate-url-slugs-in-perl
sub slugify
{
    my $input = shift;
    $input = NFKD($input);         # Normalize the Unicode string
    $input = unidecode($input);    # make accented letters not accented
    $input =~ tr/\000-\177//cd;    # Strip non-ASCII characters (>127)
    $input =~ s/[^\w\s-]//g;       # Remove all characters that are not word characters (includes _), spaces, or hyphens
    $input =~ s/^\s+|\s+$//g;      # Trim whitespace from both ends
    $input = lc($input);
    $input =~ s/[-\s]+/-/g;        # Replace all occurrences of spaces and hyphens with a single hyphen
    return $input;
} 

sub get_categorized_entities
{
    my @entities = entities_list();
    my @out;
    for(@entities)
    {
        my $cl = class_from_entity($_);
        push @out, $_ if $cl->categorized();
    }
    return @out;
}
sub standard_entities
{
    return ('article', 'image', 'user', 'log');
}
sub entities_list
{
    my @entities = standard_entities();
    my @configured_entities = keys %{config->{'Strehler'}->{'extra_menu'}};
    foreach my $e (@configured_entities)
    {
        push @entities, $e if(! grep {$_ eq $e} @entities);
    }
    return @entities;
}
sub top_bars
{
    my @entities = entities_list();
    my @editor_menu;
    my @admin_menu;
    foreach my $e (@entities)
    {
        my $c = class_from_entity($e);
        if($c && $c->visible())
        {
            if($c->allowed_role() && $c->allowed_role() eq "admin")
            {
                push @admin_menu, { name => $e, label => $c->label() };
            }
            else
            {
                push @editor_menu, { name => $e, label => $c->label() };
            }
        }
    }
    return \@editor_menu, \@admin_menu;
}


sub class_from_entity
{
    my $entity = shift;
    my $class;
    if($entity eq 'article')
    {
        $class = "Strehler::Element::Article";
    }
    elsif($entity eq 'image')
    {
        $class = "Strehler::Element::Image";
    }
    elsif($entity eq 'user')
    {
        $class = "Strehler::Element::User";
    }
    elsif($entity eq 'log')
    {
        $class = "Strehler::Element::Log";
    }
    else
    {
        $class = config->{'Strehler'}->{'extra_menu'}->{$entity}->{class};
    }
    if($class)
    {
        eval("require $class");
        return $class;
    }
}

sub class_from_plural
{
    my $plural = shift;
    foreach my $class ('Strehler::Element::Article', 'Strehler::Element::Image', 'Strehler::Element::User', 'Strehler::Element::Log')
    {
        eval("require $class");
        if($class->plural() eq $plural)
        {
            return $class;
        }
    }
    foreach my $entity (keys %{config->{'Strehler'}->{'extra_menu'}})
    {
        my $entity_class = config->{'Strehler'}->{'extra_menu'}->{$entity}->{'class'};
        eval("require $entity_class");
        if($entity_class->plural() eq $plural)
        {
            return $entity_class;
        }
    }
    return undef;
}

sub public_directory
{
    my $public_directory = app->config->{public} || path( app->config_location, 'public' );
    return $public_directory;
}

sub check_statics
{
    my $public_directory = public_directory();
    open(my $version_file, "< $public_directory/strehler/VERSION") || return 0;
    my $data = <$version_file>;
    chomp $data;
    return $data eq $Strehler::STATICS_VERSION ? 1: 0;
}

sub list_parameters_init
{
    my $entity = shift; 
    my $session = shift;
    my $params = shift;

    my %output;

    # Params init
    $output{'page'} = exists $params->{'page'} ? $params->{'page'} : $session->read($entity . '-page');
    $output{'category-input'} = exists $params->{'category-filter'} ? $params->{'category-filter'} : $session->read($entity . '-cat-input');
    $output{'order'} = exists $params->{'order'} ? $params->{'order'} : $session->read($entity . '-order');
    $output{'order_by'} = exists $params->{'order-by'} ? $params->{'order-by'} : $session->read($entity . '-order-by');
    $output{'search'} = exists $params->{'search'} ? $params->{'search'} : $session->read($entity . '-search');
    $output{'language'} = exists $params->{'language'} ? $params->{'language'} : $session->read($entity . '-language');
    $output{'backlink'} = $params->{'strehl-from'};

    #reset management
    if(exists $params->{'reset-filter'})
    {
        $output{'page'} = undef;
        $output{'category'} = undef;
        $output{'language'} = undef;
        return %output;
    }
    if(exists $params->{'reset-search'})
    {
        $output{'page'} = undef;
        $output{'search'} = undef;
        return %output;
    }

    #strehl-catname converted to category id (override category-filter)
    if(exists $params->{'strehl-catname'})
    {
        my $wanted_cat = Strehler::Meta::Category->explode_name(params->{'strehl-catname'});
        if(! $wanted_cat->exists())
        {
            $output{'error'} = "1";
            return %output;
        }
        $output{'category-input'} = $wanted_cat->get_attr('id');
    }

    #Ancestor-mode management
    if($output{'category-input'} && $output{'category-input'} =~ m/anc:([0-9]+)/)
    {
        $output{'category'} = undef;
        $output{'ancestor'} = $1;
    }
    else
    {
        $output{'category'} = $output{'category-input'};
        $output{'ancestor'} = undef;
    }
    
    #Some default values
    $output{'page'} ||= 1;
    $output{'order'} ||= 'desc';
    if($output{'category'} || $output{'ancestor'} || $output{'language'} || $output{'search'})
    {
        $output{'filtered'} = 1;
    }
    else
    {
        $output{'filtered'} = 0;
    }

    return %output;
}

=encoding utf8

=head1 NAME

Strehler::Helpers - Helpers

=head1 DESCRIPTION

Just few methods used in Strehler that could come useful throughtout in the application and also while developing on top of Strehler.

=head1 FUNCTIONS

=over 4

=item slugify 

arguments: $string

return value: $slugified

This method take a string and return the slugified version of it. Used to retrieve articles.

=item class_from_entity

arguments: entity

return value $class

Return the $class related to the given entity

=back

=cut

1;



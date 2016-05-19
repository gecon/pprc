#
# The Perl Pure RayCaster
# Perl Pure RayCaster is a simple Raycaster written completely in Perl, without use of any external libraries (like OpenGL etc.).
# This is for educational purposes, you can study methods commonly used and easily test new things.
# Do not expect advanced features found in ray tracers and speed of compiled languages.
#
# This file is part of the Perl Pure RayCaster
#
# Author:  Giannis Economou (geconomou@gmail.com)
# Created: 5/2004. Some additions, changes and the initial public release made on 1/2006
#
#
#DISCLAIMER
#This software is distributed in the hope that it will be useful, but is provided "AS IS" WITHOUT WARRANTY OF ANY KIND,
# either expressed or implied, INCLUDING, without limitation, the implied warranties of MERCHANTABILITY and FITNESS FOR A PARTICULAR PURPOSE.
#The ENTIRE RISK as to the quality and performance of the software IS WITH YOU (the holder of the software).
# Should the software prove defective, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.
#IN NO EVENT WILL ANY COPYRIGHT HOLDER OR ANY OTHER PARTY WHO MAY CREATE, MODIFY, OR DISTRIBUTE THE SOFTWARE BE LIABLE OR RESPONSIBLE TO YOU
# OR TO ANY OTHER ENTITY FOR ANY KIND OF DAMAGES (no matter how awful - not even if they arise from known or unknown flaws in the software).
#
#Please refer to 'Perl Pure RayCaster' site and to the Artistic License that came with your Perl distribution for more details.
#
#

# Ray - class representing a Ray for Ray Casting
package Ray;
use strict;

use overload '""' => \&stringify;


use Vertex;
use Vector;

#object fields
#origin: a Vertex representing the origin/start point of the ray
#origin: a Vertex representing the end point of the ray
#direction: a normalized Vector holding the direction of the Ray
use fields qw (origin destination direction);

#object constructor
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my Ray $self = fields::new($class);    #use pseudohash (array ref) for object

    $self->{origin}      = shift;
    $self->{destination} = shift;

    #create, normalize and store direction Vector
    my Vector $dir = new Vector( $self->{origin}, $self->{destination} );
    $dir->normalize();
    $self->{direction} = $dir;

    return $self;
}

#getters and setters for origin, destination, direction
#usually we access object fields directly because it is faster.
for my $field (qw(origin destination direction)) {
    no strict "refs";
    *$field = sub {
        my $self = shift;
        $self->{$field} = shift if @_;
        return $self->{$field};
    };
}

#object stringification
sub stringify {
    my $self   = shift;
    my $string = undef;
    $string .= "ray: start= " . $self->{origin} . ", end= " . $self->{destination};
    return $string;
}

1;

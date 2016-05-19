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

# Vector - class to represent Vector and  perform  vector operations
#

package Vector;
use strict;
use overload '""' => \&stringify;

use Vertex;

#object fields
#startVertex: 3D Point (Vertex) where the Vector starts
#endVertex: 3D Point (Vertex) where the Vector ends
#x y z: Vector coordinates
#_norm: "hidden" field - the vector norm
use fields qw (startVertex endVertex x y z _norm);

#object constructor
sub new {
    my ( $proto, @args ) = @_;
    my $class = ref($proto) || $proto;

    my Vector $self = fields::new($class);    #use pseudohash (array ref) for object
    #it would be nice to use a hash to have named arguments, but this is quite faster (tested on ray casting timings)

    my Vertex $startV = $args[0];
    my Vertex $endV   = $args[1];

    #1 arguments supplied, create the new vector from Origin, 1 argument is the endVertex
    if ( !defined($endV) ) {
        $endV = $startV;
        $startV = new Vertex( 0, 0, 0 );
    }

    #set x,y,z fields
    $self->{x} = $endV->{x} - $startV->{x};
    $self->{y} = $endV->{y} - $startV->{y};
    $self->{z} = $endV->{z} - $startV->{z};

    #set startVertex and endVertex fields
    $self->{startVertex} = $startV;
    $self->{endVertex}   = $endV;

    return $self;
}

#getters and setters for object fields (eg. getx(), setz(), getstartVertex
#usually we access object fields directly in the source because it is faster.
for my $field (qw(x y z)) {
    no strict "refs";
    *$field = sub {
        my $self = shift;
        $self->{$field} = shift if @_;
        return $self->{$field};
    };
}

#add aVector to the Vector
sub add {
    my $self    = shift;
    my $aVector = shift;

    $self->{x} += $aVector->{x};
    $self->{y} += $aVector->{y};
    $self->{z} += $aVector->{z};
}

#subtract aVector from the Vector
sub subtract {
    my $self    = shift;
    my $aVector = shift;

    $self->{x} -= $aVector->{x};
    $self->{y} -= $aVector->{y};
    $self->{z} -= $aVector->{z};
}

#multiply the Vector with a number
sub multiply {
    my $self = shift;
    my $num  = shift;
    $self->{x} *= $num;
    $self->{y} *= $num;
    $self->{z} *= $num;
}

#return the dot product of Vector the with aVector
sub dot {
    my $self    = shift;
    my $aVector = shift;
    return ( $self->{x} * $aVector->{x} + $self->{y} * $aVector->{y} + $self->{z} * $aVector->{z} );
}

#calculate cross product of the Vector with aVector
#return the new result Vector as a new Vector
sub cross {
    my $self    = shift;
    my $aVector = shift;
    my ( $resultX, $resultY, $resultZ ) = undef;

    $resultX = $self->{y} * $aVector->{z} - $self->{z} * $aVector->{y};
    $resultY = $self->{z} * $aVector->{x} - $self->{x} * $aVector->{z};
    $resultZ = $self->{x} * $aVector->{y} - $self->{y} * $aVector->{x};

    my Vector $resultVector = new Vector( new Vertex( $resultX, $resultY, $resultZ ) );
    return $resultVector;
}

#calculate the norm of the Vector, store it it _norm field
sub norm {
    my $self = shift;
    $self->{_norm} = sqrt( $self->{x} * $self->{x} + $self->{y} * $self->{y} + $self->{z} * $self->{z} );
    return $self->{_norm};
}

#normalize the Vector
sub normalize {
    my $self = shift;
    my $len  = $self->norm();
    if ( $len == 0 ) {

        #print "Vector::normalize() with len = 0!\n";
        $self->{x} = 1;
        $self->{y} = 1;
        $self->{z} = 1;
    }
    else {
        $self->{x} = $self->{x} / $len;
        $self->{y} = $self->{y} / $len;
        $self->{z} = $self->{z} / $len;
    }
}

sub transform {
    my $self = shift;
    my $T    = shift;
    die "Vector::transform a transformation is not defined!\n"        if !defined($T);
    die "Vector::transform transformTable has less that 16 elements!" if ( scalar(@$T) < 16 );

    my $x = $self->{x};
    my $y = $self->{y};
    my $z = $self->{z};

    my $x1 = $x * $T->[0] + $y * $T->[1] + $z * $T->[2] + $T->[3];
    my $y1 = $x * $T->[4] + $y * $T->[5] + $z * $T->[6] + $T->[7];
    my $z1 = $x * $T->[8] + $y * $T->[9] + $z * $T->[10] + $T->[11];
    my $w  = $x * $T->[12] + $y * $T->[13] + $z * $T->[14] + $T->[15];

    #set x,y,z to new values
    $self->{x} = $x1 / $w;
    $self->{y} = $y1 / $w;
    $self->{z} = $z1 / $w;

}

#object stringification
sub stringify {
    my $self   = shift;
    my $string = undef;
    $string .= defined( $self->x ) ? $self->x : "undef";
    $string .= ", ";
    $string .= defined( $self->y ) ? $self->y : "undef";
    $string .= ", ";
    $string .= defined( $self->z ) ? $self->z : "undef";
    return $string;
}

1;
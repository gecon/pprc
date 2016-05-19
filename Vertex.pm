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

# Vertex - class to represent Vertices (our points in 3D space) and perform vertices operations
#

package Vertex;
use strict;


use overload
  '""'     => \&stringify,
  '=='     => \&equals,
  fallback => 1;

use Vector;

#object fields
#x,y,z: coordinates
#clipped: set to 1 when vertex is clipped
#normal: the vertex normal (in use for Phong model shading)
use fields qw (x y z clipped normal);


#object constructor
sub new {
    my ( $proto, @args ) = @_;
    my $class = ref($proto) || $proto;

    #use pseudohash (array ref) for object
    my Vertex $self = fields::new($class);

    #construction by supplying 3 arguments, the (x,y,z) of the new Vertex
    if ( scalar(@args) == 3 ) {
        $self->{x} = $args[0];
        $self->{y} = $args[1];
        $self->{z} = $args[2];
        $self->{clipped} = 0;
        $self->{normal} = undef;
    }

    #construction by supplying an existing vertex
    elsif ( scalar(@args) == 1 ) {
        my Vertex $aVertex = $args[0];
        $self->{x} = $aVertex->{x};
        $self->{y} = $aVertex->{y};
        $self->{z} = $aVertex->{z};
        $self->{clipped} = 0;
        $self->{normal} = Vector->new($aVertex->{normal}->{endVertex}) if defined($aVertex->{normal});
    }
 
    return $self;
}

	  
#getters and setters for x,y,z (using a closure)
#are automatically generated this way.
#usually in source we directly access object fields for gaining speed (after some tests this prooves to makes noticable difference)
for my $field (qw(x y z clipped normal)) {
    no strict "refs";
    *$field = sub {
        my $self = shift;
        $self->{$field} = shift if @_;
        return $self->{$field};
    };
}

#add aVertex to the Vertex
sub add {
    my $self    = shift;
    my $aVertex = shift;

    $self->{x} += $aVertex->{x};
    $self->{y} += $aVertex->{y};
    $self->{z} += $aVertex->{z};
}

#subtract aVertex from the Vertex
sub subtract {
    my $self    = shift;
    my $aVertex = shift;

    $self->{x} -= $aVertex->{x};
    $self->{y} -= $aVertex->{y};
    $self->{z} -= $aVertex->{z};
}

#multiply the Vertex with a number
sub product {
    my $self = shift;
    my $num  = shift;

    $self->{x} *= $num;
    $self->{y} *= $num;
    $self->{z} *= $num;
}

#returns the distance of the Vertex from aVertex
sub distance {
    my $self    = shift;
    my $aVertex = shift;

    my $xd = $self->{x} - $aVertex->{x};
    my $yd = $self->{y} - $aVertex->{y};
    my $zd = $self->{z} - $aVertex->{z};

    return sqrt( $xd * $xd + $yd * $yd + $zd * $zd );
}

#apply a 4x4 Transform Matrix
#method expects an array reference ($T) - the transformation matrix
sub transform {
    my $self = shift;
    my $T    = shift;

		die "Vertex::transform a transformation is not defined!\n"        if !defined($T);
    print "Vertex::transform TransformTable has less that 16 elements!" if ( scalar(@$T) < 16 );

    #return if ($self->{clipped} == 1); #we do not proceed in case if vertex is clipped

    my $x = $self->{x};
    my $y = $self->{y};
    my $z = $self->{z};

    my $x1 = $x * $T->[0] + $y * $T->[1] + $z * $T->[2] + $T->[3];
    my $y1 = $x * $T->[4] + $y * $T->[5] + $z * $T->[6] + $T->[7];
    my $z1 = $x * $T->[8] + $y * $T->[9] + $z * $T->[10] + $T->[11];
    my $w  = $x * $T->[12] + $y * $T->[13] + $z * $T->[14] + $T->[15];

    #this shouldn't happen
    #if ($w == 0) {
    #    $w = 1;
    #    print "Vertex::transform() w == 0!!\n";
    #}

    #set x,y,z to new values
    $self->{x} = $x1 / $w;
    $self->{y} = $y1 / $w;
    $self->{z} = $z1 / $w;

}

#transforms Vertex Normal
sub transformNormal {
	my $self = shift;
  my $T    = shift;
 #and vertex normals (if they exist - eg. lights do not have normal but are vertices)
    $self->{normal}->transform($T) if defined( $self->{normal} );
    print "normal not that normal!" .$self->{normal} ."\n" if (  defined( $self->{normal} ) && 
    																		($self->{normal}->{x} >1 || $self->{normal}->{y} >1 || $self->{normal}->{z} >1)  );
    																		
}
							
#overloaded method for stringification
#to print/stringify the Vertex
#we don't want to format (sprintf) these, because now they are in use in filereader
#as hash keys
sub stringify {
    my $self   = shift;
    my $string = undef;
    $string .= defined( $self->{x} ) ? $self->{x} : "undef";
    $string .= ", ";
    $string .= defined( $self->{y} ) ? $self->{y} : "undef";
    $string .= ", ";
    $string .= defined( $self->{z} ) ? $self->{z} : "undef";
    if ( defined( $self->{normal} ) ) {
    		$string .= ",(vertex normal:";
    		$string .= defined( $self->{normal} ) ? $self->{normal} .")" : "undef)";
    }
    return $string;
}

#overloaded method for equality test
#vertexA == vertexB
sub equals {
    my ( $vertexA, $vertexB ) = @_;
    return ( ( $vertexA->{x} == $vertexB->{x} ) && ( $vertexA->{y} == $vertexB->{y} ) && ( $vertexA->{z} == $vertexB->{z} ) );
}

1;

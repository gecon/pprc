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

# Polygon - class to represent Polygons and polygon's operations
# Implementation based on triangles

package Polygon;
use strict;

use overload '""' => \&stringify;

use Vector;

#object fields
#vertices: this is an array holding polygon vertices (Vertex Objects) - polygons are triangles so far
#normal: this is the normal Vector of the polygon
#hidden: set to 1 when polygon is hidden from camera
use fields qw (vertices normal hidden);

sub new {    #object constructor
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my Polygon $self = fields::new($class);    #use pseudohash (array ref) for object

    $self->{vertices} = ();                    ##array reference, holds 3D points (Vertex objects) of polygon

    #add all vertices given
    $self->addVertices(@_);

    #compute normal of surface
    $self->computeNormal();

    return $self;

}

#returns an array of polygon Vertices
sub getVertices() {
    my $self = shift;
    return @{ $self->{vertices} };
}

#adds new vertices to polygon
sub addVertices {
    my $self = shift;
    push( @{ $self->{vertices} }, @_ );
}

#performs clipping of polygon lines on the near ($cfront) and far ($cback) clipping plane
sub clipLine {
    my $self      = shift;
    my Vertex $v1 = shift;
    my Vertex $v2 = shift;
    my $cfront    = shift;
    my $cback     = shift;
    my $t         = undef;

    if ( $v1->{z} <= $cfront && $v2->{z} <= $cfront ) {
        $v1->{clipped} = 1;
        $v2->{clipped} = 1;
        return;
    }
    if ( $v1->{z} >= $cback && $v2->{z} >= $cback ) {
        $v1->{clipped} = 1;
        $v2->{clipped} = 1;
        return;
    }
    if ( ( $v1->{z} < $cfront && $v2->{z} > $cfront ) || ( $v1->{z} > $cfront && $v2->{z} < $cfront ) ) {
        $t = ( $cfront - $v1->{z} ) / ( $v2->{z} - $v1->{z} );
        if ( $v1->{z} < $cfront ) {
            $v1->{x} = $v1->{x} + $t * ( $v2->{x} - $v1->{x} );
            $v1->{y} = $v1->{y} + $t * ( $v2->{y} - $v1->{y} );
            $v1->{z} = $cfront;
        }
        else {
            $v2->{x} = $v1->{x} + $t * ( $v2->{x} - $v1->{x} );
            $v2->{y} = $v1->{y} + $t * ( $v2->{y} - $v1->{y} );
            $v2->{z} = $cfront;
        }
    }

    if ( ( $v1->{z} < $cback && $v2->{z} > $cback ) || ( $v1->{z} > $cback && $v2->{z} < $cback ) ) {
        $t = ( $cback - $v1->{z} ) / ( $v2->{z} - $v1->{z} );
        if ( $v1->{z} < $cback ) {
            $v2->{x} = $v1->{x} + $t * ( $v2->{x} - $v1->{x} );
            $v2->{y} = $v1->{y} + $t * ( $v2->{y} - $v1->{y} );
            $v2->{z} = $cback;
        }
        else {
            $v1->{x} = $v1->{x} + $t * ( $v2->{x} - $v1->{x} );
            $v1->{y} = $v1->{y} + $t * ( $v2->{y} - $v1->{y} );
            $v1->{z} = $cback;
        }
    }

}


#returns polygon normal vector
sub getNormal() {
    my $self = shift;
    return $self->{normal};
}

#destroys polygon's normal
sub resetNormal() {
    my $self = shift;
    $self->{normal} = undef;
}

#computes face normal vector
sub computeNormal() {
    my $self = shift;

    #my Vector $line1Vector = Vector->new( startVertex => $self->{vertices}->[0], endVertex => $self->{vertices}->[1] );
    my Vector $line1Vector = Vector->new( $self->{vertices}->[0], $self->{vertices}->[1] );
    my Vector $line2Vector = Vector->new( $self->{vertices}->[1], $self->{vertices}->[2] );

    #compute cross product
    my Vector $normal = $line1Vector->cross($line2Vector);
    $line1Vector = $line2Vector = undef;

    #normalize vector
    $normal->normalize();

    $self->{normal} = $normal;

}

#checks and sets the hidden attribute of the polygon (if polygon is not visible)
sub checkIfHidden {
    my $self = shift;

    my Vector $viewDir = new Vector( $self->{vertices}->[1], new Vertex( 0, 0, 0 ) );
    

    #compute face normal
    #$self->computeNormal();

    my $crossProd = $self->{normal}->dot($viewDir);
    if ( $crossProd < 0 ) {
        $self->{hidden} = 1;
    }
    else {
        $self->{hidden} = 0;
    }

	#$self->{hidden} = 1 if ( $self->{normal}->{z} < 0 );

}

#returns hidden property (non-visible) for face
sub isHidden {
    my $self = shift;

    #check to set or unset hidden attribute
    #$self->checkIfHidden();

    return $self->{hidden};    #hidden attribute
}

#apply a 4x4 Transform Matrix to polygon normal
sub transformNormal() {
    my $self = shift;
    my $T    = shift;                               #Transformation Table\
    #print "nis was: " .$self->{normal} ."\n";
    $self->{normal}->transform($T);                 #transform normal
    #$self->{normal}->normalize();
    #print "Polygon::transformNormal abnormal normal (this is not always bad): " if ( $self->{normal}->{x} > 1 || $self->{normal}->{y} > 1 || $self->{normal}->{z} > 1);
}


#apply a 4x4 Transform Matrix to polygon
sub transform {
    my $self = shift;
    my $T    = shift;          #Transformation Table
    map $_->transform($T), $self->getVertices();    #transform each vertex
    

}

#apply a 4x4 Transform Matrix to polygon vertices normals
sub transformVerticesNormals {
    my $self = shift;
    my $T    = shift;          #Transformation Table
    map $_->transformNormal($T), $self->getVertices();    #transform each vertex
    

}


#apply a 4x4 Transform Matrix to polygon, iff is not hidden
sub transformVisible {
    my $self = shift;
    my $T    = shift;                               #Transformation Table

    return if $self->isHidden();                    #do not do anything if polygon is hidden

    foreach my $vertex ( $self->getVertices ) {
        $vertex->transform($T) if $vertex->{clipped} == 0;
    }

}

#object stringification
sub stringify {
    my $self   = shift;
    my $string = undef;
    $string = "Dumping polygon:";
    foreach my $vertex ( $self->getVertices ) {
        $string .= "$vertex\n";
    }
    return "$string";
}

1;

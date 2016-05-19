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

# ObjectReader::FileRaw - Reads an object in raw format from file

package ObjectReader::FileRaw;

use strict;
use warnings;

use Vertex;
use Vector;
use Polygon;
use Object3D;

#some magic
use Memoize;
memoize('Vertex::new');
memoize('Polygon::new');

#class constructor
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    #my $args = (shift);
    my $self = {};

    bless( $self, $class );

    $self->{filename} = shift;    #filename to read

    #the next one is a hash that stores polygons that each vertex use
    #this is for calculating vertices normals
    $self->{verticesPolygons} = {};

    return $self;
}

sub readObject {
    my $self = shift;
    my ( $p1x, $p1y, $p1z, $p2x, $p2y, $p2z, $p3x, $p3y, $p3z ) = undef;    #to read points coordinates from raw file
                                                                            #to keep new vertices
    my Vertex $point1 = undef;
    my Vertex $point2 = undef;
    my Vertex $point3 = undef;

    #to keep a new polygon
    my Polygon $aPolygon = undef;

    my $newObject3D = new Object3D();                                       #create a new 3D object

    #open file for reading
    open( OBJFILE, "<", $self->{filename} ) or die "Can not open file " . $self->{filename} . " for reading object";
    while (<OBJFILE>) {                                                     #read lines
                                                                            #print STDERR "About to parse line: $_";
                                                                            #read 3 3D points (vertices) from current line
        ( $p1x, $p1y, $p1z, $p2x, $p2y, $p2z, $p3x, $p3y, $p3z ) = m/([+-]?\d+\.?\d*)\s([+-]?\d+\.?\d*)\s([+-]?\d+\.?\d*)/og;
        if (   defined($p1x) && defined($p1y) && defined($p1z) && 
							 defined($p2x) && defined($p2y) && defined($p2z) && 
							 defined($p3x) && defined($p3y) && defined($p3z) )
        {

            #print "ObjectReader::FileRaw (p1x,p1y,p1z,p2x,p2y,p2z,p3x,p3y,p3z) = ($p1x,$p1y,$p1z,$p2x,$p2y,$p2z,$p3x,$p3y,$p3z)\n";
            #create the 3 3D points
            $point1 = new Vertex( $p1x, $p1y, $p1z );
            $point2 = new Vertex( $p2x, $p2y, $p2z );
            $point3 = new Vertex( $p3x, $p3y, $p3z );

            #add a new vertex based on those 3 new 3D points
            $aPolygon = new Polygon( $point1, $point2, $point3 );

            #an object reader is responsible for calculating the vertices normals, too
            $self->AddPolygon2Vertices( $point1, $point2, $point3, $aPolygon );

            $newObject3D->addPolygon($aPolygon);
            $point1 = $point2 = $point3 = undef;    #destroy points
            $aPolygon = undef;
        }
    }

    close(OBJFILE);

    #compute normals for each vertex
    $self->computeVerticesNormals($newObject3D);

    #$newObject3D->addPolygon($aPolygon);

    #just a whole dump to see if everything is fine
    #$self->printVerticesPolygons();

    Memoize::unmemoize('Vertex::new');
    Memoize::unmemoize('Polygon::new');


    my Object3D $newObj = new Object3D();
    foreach my $polygon ( $newObject3D->getPolygons() ) {
        my Vertex $v1 = new Vertex( $polygon->{vertices}->[0] );
        my Vertex $v2 = new Vertex( $polygon->{vertices}->[1] );
        my Vertex $v3 = new Vertex( $polygon->{vertices}->[2] );
        
        #my $anotherPoly = new Polygon($polygon->{vertices}->[0],$polygon->{vertices}->[1],$polygon->{vertices}->[2] );
        my $anotherPoly = new Polygon( $v1, $v2, $v3 );

        $newObj->addPolygon($anotherPoly);
    }


    #init object and scene (camera, lights, etc.)
    #$newObject3D->initObjectScene();
    $newObj->initObjectScene();

    #return object to caller
    #return $newObject3D;
    return $newObj;
}

sub computeVerticesNormals {
    my $self   = shift;
    my $object = shift;

    for my $vertexstring ( keys %{ $self->{verticesPolygons} } ) {

        #vertexstring is the key (a string) in veticesPolygons and not a ref to our Vertex
        #get first entry from hash of arrays verticesPolygons, which is the ref to our Vertex.

        #my Vertex $vertex = shift @{ ${$self->{verticesPolygons}}{$vertexstring} };

        my $polygonsInVectorCount = 0;    #in many polygons
        my $vecNorm_x             = 0;
        my $vecNorm_y             = 0;
        my $vecNorm_z             = 0;    #new vertex vector coords

        for my $i ( 1 .. $#{ ${ $self->{verticesPolygons} }{$vertexstring} } ) {
            $vecNorm_x += ${ $self->{verticesPolygons} }{$vertexstring}->[$i]->{normal}->{x};
            $vecNorm_y += ${ $self->{verticesPolygons} }{$vertexstring}->[$i]->{normal}->{y};
            $vecNorm_z += ${ $self->{verticesPolygons} }{$vertexstring}->[$i]->{normal}->{z};
            $polygonsInVectorCount++;
        }

        #print "FileRaw::computeVerticesNormals found $polygonsInVectorCount in vertex $vertex\n";
        $vecNorm_x = $vecNorm_x / $polygonsInVectorCount++;
        $vecNorm_y = $vecNorm_y / $polygonsInVectorCount++;
        $vecNorm_z = $vecNorm_z / $polygonsInVectorCount++;

        #vertex normal vector end as a new vertex
        my $NormalEnd = Vertex->new( $vecNorm_x, $vecNorm_y, $vecNorm_z );
        my Vector $vertexNormal = Vector->new($NormalEnd);

        #set vertex normal

        #and normalize
        $vertexNormal->normalize();

        #now set the vertex normal
        ${ $self->{verticesPolygons} }{$vertexstring}->[0]->normal($vertexNormal);

        #$vertex->normal($vertexNormal);

        #print "FileRaw::computeVerticesNormals Vertex is :$vertex with normal " .$vertex->normal ."\n";

        #return
    }

}

#for calculating vertices normals we need a list of all the polygons in which a vertex is being used
#we are using a hash of arrays to store polygons for each vertex
sub AddPolygon2Vertices {
    my $self      = shift;
    my $vertex1   = shift;
    my $vertex2   = shift;
    my $vertex3   = shift;
    my $inPolygon = shift;

    #hash keys are stringified vertices
    #first entry in each array will be a reference to the vertex (to use it later to set vertex normal)
    #we use stringifiles vertices for keys
    push @{ ${ $self->{verticesPolygons} }{$vertex1} }, $vertex1 if ( $#{ ${ $self->{verticesPolygons} }{$vertex1} } == -1 );
    push @{ ${ $self->{verticesPolygons} }{$vertex2} }, $vertex2 if ( $#{ ${ $self->{verticesPolygons} }{$vertex2} } == -1 );
    push @{ ${ $self->{verticesPolygons} }{$vertex3} }, $vertex3 if ( $#{ ${ $self->{verticesPolygons} }{$vertex3} } == -1 );

    #now the polygons
    push @{ ${ $self->{verticesPolygons} }{$vertex1} }, $inPolygon;
    push @{ ${ $self->{verticesPolygons} }{$vertex2} }, $inPolygon;
    push @{ ${ $self->{verticesPolygons} }{$vertex3} }, $inPolygon;

    return;
}

#this is just for testing
#a nasty dump the verticesPolygons Hash of Polygons Array
sub printVerticesPolygons {
    my $self = shift;

    print "FileRaw::PrintVerticesPolygons:\n";
    for my $vert ( keys %{ $self->{verticesPolygons} } ) {
        print "vertex $vert is in polygons:\n  @{ ${$self->{verticesPolygons}}{$vert} }\n";
    }

}

1;

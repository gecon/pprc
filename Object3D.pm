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

# Object3D - Class to represent 3D Object
#

package Object3D;

use strict;
use warnings;
use overload '""' => \&stringify;

use AffineTransform;
use Camera;
use RayCast;
use Ray;

#object fields
#polygons: array to hold polygons
#starting_polygons: array to hold original polygons (as read from file)
#objectCenter: holds object center
#camera: camera in the world
#lights: lights in the world
#colortones: colortones to use in raycasting
use fields
  qw (polygons objectCenter camera lights min_x min_y min_z max_x max_y max_z colortones starting_polygons starting_lights smoothShades)
  ;    #class fields

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my Object3D $self = fields::new($class);    #use pseudohash (array ref) for object blessing

    $self->{polygons} = ();                     #array reference, holds 3D points of object

    #TO DO: constructor based on existing/clone...
    return $self;
}

#This method is called after reading object from file to initialize object
#In this method we position lights and the camera to our world (feel free to change them)
sub initObjectScene() {
    my $self = shift;

    #get object's bounding box and center
    $self->getBoundingBoxAndCenter();

    #place camera into our world

    my $x_box  = abs( $self->{max_x} - $self->{min_x} );
    my $y_box  = abs( $self->{max_y} - $self->{min_y} );
    my $z_box  = abs( $self->{max_z} - $self->{min_z} );
    my $camera = new Camera(

        #new Vertex( $self->{objectCenter}->{x}, $self->{objectCenter}->{y} - 1 * $max_y_dist,
        #					  $self->{objectCenter}->{z} - 1 * $max_z_dist),                           #POSITION
        new Vertex( $self->{objectCenter}->{x}, $self->{objectCenter}->{y} + 2 * $y_box,
            $self->{objectCenter}->{z} + 1 * $z_box ),    #POSITION

        $self->{objectCenter},                            #look-at Vertex (object center)
        new Vector( new Vertex( 0, 1, 0 ) ),              #VUV Vector
    );
    $self->{camera} = $camera;

    print "\nInitialization:\n";
    print "Object center at: " . $self->{objectCenter} . "\n";
    print "Object B. Box: \n ";
    print "\t(xmin, ymin,zmin) = ("
      . sprintf( "%.3f", $self->{min_x} ) . ", "
      . sprintf( "%.3f", $self->{min_y} ) . ", "
      . sprintf( "%.3f", $self->{min_z} ) . ")\n";
    print "\t(xmax, ymax,zmax) = ("
      . sprintf( "%.3f", $self->{max_x} ) . ", "
      . sprintf( "%.3f", $self->{max_y} ) . ", "
      . sprintf( "%.3f", $self->{max_z} ) . ")\n";
    print "Camera:\n ";
    print "\t Position: " . $camera->{cPosition} . "\n";
    print "\t LookAt: " . $camera->{lookAt} . "\n";



		##
    ## Let's place lights into our world
    ##
    push @{ $self->{lights} }, new Vertex( -120, 110, 240 ); #gadget
    #push @{ $self->{lights} }, new Vertex( 150, 0, 600 );    #teapot2
    ##
    ## Enough Lights!
    ##
    
    print "Light Sources:\n";
    foreach my $light ( $self->getLights ) {
        print "\t Light at: " . $light . "\n";
    }



    print "Initialization completed.\n\n";
}

#getter method for Object's Polygons
sub getPolygons() {
    my $self = shift;
    return @{ $self->{polygons} };
}

sub getLights() {
    my $self = shift;
    return @{ $self->{lights} };
}

#adds a Polygon to object
sub addPolygon {
    my $self    = shift;
    my $polygon = shift;
    push( @{ $self->{polygons} }, $polygon );
    return;
}

#find object's center and bounding box
#stores found values as object properties
sub getBoundingBoxAndCenter {
    my $self = shift;

    my Vertex $objectCenter;
    my ( $x_min, $y_min, $z_min ) = ( 1.0e300,  1.0e300,  1.0e300 );
    my ( $x_max, $y_max, $z_max ) = ( -1.0e300, -1.0e300, -1.0e300 );
    my ( $x_center, $y_center, $z_center ) = ( undef, undef, undef );

    foreach my $objectPolygon ( $self->getPolygons ) {
        foreach my $vertex ( $objectPolygon->getVertices ) {
            $x_max = $vertex->{x} if ( $vertex->{x} > $x_max );
            $x_min = $vertex->{x} if ( $vertex->{x} < $x_min );

            $y_max = $vertex->{y} if ( $vertex->{y} > $y_max );
            $y_min = $vertex->{y} if ( $vertex->{y} < $y_min );

            $z_max = $vertex->{z} if ( $vertex->{z} > $z_max );
            $z_min = $vertex->{z} if ( $vertex->{z} < $z_min );
        }
    }
    $x_center = ( $x_max + $x_min ) * 0.5;
    $y_center = ( $y_max + $y_min ) * 0.5;
    $z_center = ( $z_max + $z_min ) * 0.5;

    #store found properties
    $self->{objectCenter} = new Vertex( $x_center, $y_center, $z_center );
    $self->{min_x}        = $x_min;
    $self->{min_y}        = $y_min;
    $self->{min_z}        = $z_min;

    #print "\(x_max, y_max, z_max) = ($x_max, $y_max, $z_max)\n";
    #print "\(x_min, y_min, z_min) = ($x_min, $y_min, $z_min)\n";

    $self->{max_x} = $x_max;
    $self->{max_y} = $y_max;
    $self->{max_z} = $z_max;

    #print "Object Center: " . $self->{objectCenter} . "\n";

    return $objectCenter;
}

#calculate normals of object's polygons
sub computeNormals() {
    my $self = shift;
    map $_->computeNormal(), $self->getPolygons();    #   #calculate normal of each polygon
}

sub transformVerticesNormals {
    my $self = shift;
    my $T    = shift;                                 #get the transformation array ref.
                                                      #print "Object3d::transformVerticesNormals\n";
    map $_->transformVerticesNormals($T), $self->getPolygons();
}

#apply a 4x4 Transform Matrix to object
sub transformVertices {
    my $self              = shift;
    my AffineTransform $T = shift;                    #get the transformation matrix

    #my $T = $viewTransform->getFinalTransformMatrix();    #get the Transform Matrix
    #   #transform each polygon's vertices
    map $_->transform($T), $self->getPolygons();

    #transform lights
    map $_->transform($T), $self->getLights();

}

#apply a 4x4 Transform Matrix to object, but transform normals only
sub transformFaceNormals {
    my $self = shift;
    my $T    = shift;    #get the transformation matrix
    map $_->transformNormal($T), $self->getPolygons();    #   #transform each polygon's vertices and normals

}

#apply a 4x4 Transform Matrix to object, but transform only visible faces
sub transformVisible {
    my $self = shift;
    my $T    = shift;                                     #get the transformation matrix

    map $_->transformVisible($T), $self->getPolygons();   #   #transform each polygon's vertices
    map $_->transform($T),        $self->getLights();     #lights, too

}

#method for rendering object (ray casting)
#this implements the tight loop of the ray casting process
sub render {
    my $self  = shift;
    my $memDC = shift;                                    #device contect to copy draw result into
    my $dc    = shift;                                    #device context to draw object into
    my $app   = shift;                                    #our application to yield...

    #construct a white pen (color will be set later, after ray casting)
    my $pixelColor = Wx::Colour->new( 255, 255, 255 );

    #local access to our camera.
    my $camera = $self->{camera};

    #print "Object3D::Render() will Ray Cast on (" .$camera->{rayCastScrW} .", ".$camera->{rayCastScrH} .")\n";

    #get a new RayCaster
    my RayCast $rayCasterObj = RayCast->new( $self->{colortones} );

    #loop through all canvas pixels
    for ( my $v = 0 ; $v < $camera->{rayCastScrH} ; $v++ ) {
        for ( my $h = 0 ; $h < $camera->{rayCastScrW} ; $h++ ) {

            #print "Object3D::render progress $h,$v\n" if ($v % 30 == 0);

            #Camera's getRay method is not called to gain a some speed.
            #It is inlined now. Performance tests showed important improvement.
            #my Vector $ray = $camera->getRay($h,$v);

            #Calculate World Vertex where ray hits the window

            my $i = ( 0.5 + $h ) / $camera->{rayCastScrW};
            my $j = ( $camera->{rayCastScrH} - 0.5 - $v ) / $camera->{rayCastScrH};

            my Vertex $P_onScreen = new Vertex(
                $camera->{scrLU}->{x} + ( $i * ( $camera->{scrRU}->{x} - $camera->{scrLU}->{x} ) ) +
                  ( $j * ( $camera->{scrLB}->{x} - $camera->{scrLU}->{x} ) ),
                $camera->{scrLU}->{y} + ( $i * ( $camera->{scrRU}->{y} - $camera->{scrLU}->{y} ) ) +
                  ( $j * ( $camera->{scrLB}->{y} - $camera->{scrLU}->{y} ) ),
                $camera->{scrLU}->{z} + ( $i * ( $camera->{scrRU}->{z} - $camera->{scrLU}->{z} ) ) +
                  ( $j * ( $camera->{scrLB}->{z} - $camera->{scrLU}->{z} ) )
            );
            my Ray $ray = new Ray( $camera->{cPosition}, $P_onScreen );    #the ray vector

            #ray casting, returns pixel color
            #$pixelColor = Wx::Colour->new(20,04,200); #do not raycast, just give me a color (for testing)
            $pixelColor = $rayCasterObj->rayCast( $ray, $self, $self->{smoothShades} );

            #draw given point/pixel on window DC
            my $pen = Wx::Pen->new( $pixelColor, 1, 0 );                   #pen initialization
            $dc->SetPen($pen);
            $dc->DrawPoint( $h, $v );

            #draw on memDC, too (to properly repaint in needed)
            $memDC->SetPen($pen);
            $memDC->DrawPoint( $h, $v );

            $pen        = undef;
            $pixelColor = undef;

            $app->Yield();                                                 #just to handle any pending events
            return if ( $app->{HALT} == 1 );                               #stop rendering process if 1

        }
    }
}

#draws wireframe rendering object on canvas (uses canvas' device context)
sub drawWireframe {
    my $self = shift;
    my $dc   = shift;                                                      #device context to draw object

    #local access to our camera
    my $camera = $self->{camera};

    #Transform World Space to Camera Space
    $camera->world2Camera($self);

    #Hide hidden (non-visible) polygons
    $self->hidePolygons();

    #Perspective transform
    $camera->perspectiveTransform($self);

    #    #draw lights
    #    my $colorInner = Wx::Colour->new( 250, 200, 0 );    #light inner color
    #    my $colorOuter = Wx::Colour->new( 255, 255, 0 );    #light outer color
    #    $dc->SetPen( Wx::Pen->new( $colorOuter, 4, 0 ) );
    #    $dc->SetBrush( new Wx::Brush( $colorInner, Wx::wxSOLID ) );
    #    foreach my $light ( $self->getLights ) {
    #        #print "will draw a light source at " . $light->x . ", " . $light->y . "\n";
    #        $dc->DrawEllipse( $light->x, $light->y, 10, 10 );
    #    }

    #draw polygons
    my $color = Wx::Colour->new( 0, 0, 0 );    #light inner color
    $dc->SetPen( Wx::Pen->new( $color, 1, 0 ) );
    $dc->SetBrush( new Wx::Brush( $color, Wx::wxSOLID ) );

    foreach my $objectPolygon ( $self->getPolygons ) {
        my $previousPoint = undef;
        my $firstPoint    = undef;

        #if face is hidden, loop
        next if $objectPolygon->isHidden();
        foreach my $vertex ( $objectPolygon->getVertices ) {

            #print "Dumping vertex: " .Dumper($vertex);
            if ( defined($previousPoint) ) {
                $dc->DrawLine( $previousPoint->x, $previousPoint->y, $vertex->x, $vertex->y )
                  if ( $previousPoint->{clipped} == 0 && $vertex->{clipped} == 0 );
            }
            $previousPoint = $vertex;
            $firstPoint = $vertex if !defined($firstPoint);
        }
        $dc->DrawLine( $firstPoint->x, $firstPoint->y, $previousPoint->x, $previousPoint->y )
          if ( $previousPoint->{clipped} == 0 && $firstPoint->{clipped} == 0 );
    }

}

#marks non visible faces as hidden.
sub hidePolygons() {
    my $self = shift;
    foreach my $objectPolygon ( $self->getPolygons ) {

        #$objectPolygon->computeNormal();    #calculate and store face normal
        $objectPolygon->checkIfHidden();
    }
}

#clip lines (vertices) that are before the near clipping plane or after the far clipping plane
sub ClipObject {
    my $self   = shift;
    my $cfront = shift;
    my $cback  = shift;
    my $vcount = 0;
    foreach my $objectPolygon ( $self->getPolygons ) {
        my $previousPoint = undef;
        my $firstPoint    = undef;
        next if $objectPolygon->isHidden();    #do not do anything if polygon is hidden
        foreach my $vertex ( $objectPolygon->getVertices ) {

            if ( defined($previousPoint) ) {

                #1-2, 2-3
                #print "\nclipLine($previousPoint, $vertex, $cfront, $cback)\n";
                $objectPolygon->clipLine( $previousPoint, $vertex, $cfront, $cback );
            }
            $previousPoint = $vertex;
            $firstPoint = $vertex if !defined($firstPoint);
        }

        #3-1
        #print "\nclipLine($previousPoint, $firstPoint, $cfront, $cback)\n";
        $objectPolygon->clipLine( $previousPoint, $firstPoint, $cfront, $cback );
    }
}

#sets the smoothShades property
sub setSmoothShades {
    my $self = shift;
    $self->{smoothShades} = shift;    #color of ray casted object

}

#sets the colortones property
sub SetColorTones {
    my $self = shift;
    $self->{colortones} = shift;      #color of ray casted object
}

#object stringification
sub stringify {
    my $self        = shift;
    my $numPolygons = 0;

    #dump all object points
    my $str = "Dumping Object...\n";
    foreach my $objectPolygon ( $self->getPolygons ) {
        $str .= "Object polygon ($numPolygons): $objectPolygon\n";
        $numPolygons++;
    }
    $str .= "Number of Polygons: $numPolygons\n";
    return $str;
}

sub storeObject {
    my $self = shift;

    #makes a copy of polygons and its vertices to keep the original vertices
    foreach my $objectPolygon ( $self->getPolygons ) {
        my @vertices = ();
        foreach my $existingVertex ( $objectPolygon->getVertices ) {
            my Vertex $vertexCopy = new Vertex($existingVertex);    #create a copy of the vertex
            push @vertices, $vertexCopy;
        }
        my Polygon $originalPolygon = new Polygon(@vertices);

        #$originalPolygon->{normal} = new Vector($objectPolygon->{normal}->{endVertex});
        push( @{ $self->{starting_polygons} }, $originalPolygon );
    }

    #make a copy of lights
    foreach my $light ( $self->getLights ) {
        my Vertex $lightsourceCopy = new Vertex($light);            #create a copy of the vertex
        push @{ $self->{starting_lights} }, $lightsourceCopy;
    }
}

sub restoreObject {
    my $self = shift;

    my $polyid = 0;                                                 #polygon count
    foreach my $polygon ( $self->getPolygons ) {
        my $vid = 0;                                                #vertex count
        foreach my $vertex ( $polygon->getVertices ) {
            $vertex->{x}       = $self->{starting_polygons}[$polyid]->{vertices}[$vid]->{x};
            $vertex->{y}       = $self->{starting_polygons}[$polyid]->{vertices}[$vid]->{y};
            $vertex->{z}       = $self->{starting_polygons}[$polyid]->{vertices}[$vid]->{z};
            $vertex->{clipped} = 0;
            $vertex->{normal}  = $self->{starting_polygons}[$polyid]->{vertices}[$vid]->normal;
            $vid++;
        }

        #$polygon->resetNormal();
        $polygon->{normal} = new Vector( $self->{starting_polygons}[$polyid]->{normal}->{endVertex} );
        $polyid++;
    }

    #get object's bounding box and center
    #$self->getBoundingBoxAndCenter();

    #reset Lights
    my $lid = 0;
    foreach my $light ( $self->getLights ) {
        $light->{x} = $self->{starting_lights}[$lid]->{x};
        $light->{y} = $self->{starting_lights}[$lid]->{y};
        $light->{z} = $self->{starting_lights}[$lid]->{z};
        $lid++;
    }
}

1;

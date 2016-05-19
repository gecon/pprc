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

# RayCast - class implementing Ray Casting methods
#

package RayCast;
use strict;

use constant EPSILON => 0.000000000001;
use constant PI      => 3.14159265358979;

#some magic
use Memoize;
memoize('calcBarycentricCoords');
#memoize('colourTable');


use Wx qw(:colour);

use Vertex;
use Vector;
use Polygon;
use Object3D;
use Ray;

use fields qw (colortones ambientColor colorTableRGB);    #object fields

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my RayCast $self = fields::new($class);               #use pseudohash (array ref) for object
    $self->{colortones} = shift;

    my $col = undef;
    my @RGB = ();

    #this is the ambient color to use
    if ( $self->{colortones} eq "red" ) {
        $col = Wx::Colour->new( 90, 0, 0 );               #redtones dark (ambientColor)
                                                          #For the color table lookup
        @RGB = (
            { r => 106, g => 53,  b => 53 },              #0 (in use)
            { r => 226, g => 199, b => 199 }              #1 (in use)
        );
    }
    elsif ( $self->{colortones} eq "green" ) {
        $col = Wx::Colour->new( 0, 90, 0 );               #greentones dark	(ambientColor)
                                                          #For the color table lookup
        @RGB = (
            { r => 46,   g => 136, b => 19 },               #0 (in use)
            { r => 243, g => 214, b => 214 }              #1 (in use) 
        );
    }
    elsif ( $self->{colortones} eq "blue" ) {
        $col = Wx::Colour->new( 60, 102, 128 );           #bluetones dark (ambientColor)
                                                          #For the color table lookup
        @RGB = (
            { r => 73,  g => 126, b => 158 },             #0 (in use)
            { r => 239, g => 243, b => 252 }              #1 (in use)
        );
    }
    else { die "RayCast::new() Wrong value for colortones (" . $self->{colortones} . ")\n"; }

    $self->{ambientColor}  = $col;
    $self->{colorTableRGB} = \@RGB;

    return $self;
}

#main ray casting method
sub rayCast {
    my $self            = shift;
    my Ray $ray         = shift;
    my Object3D $object = shift;
    my $smoothShades		= shift;

    #get camera and lights
    my Camera $camera = $object->{camera};
    my $lights = $object->{lights};

    use Wx qw(:colour);

    my $pixelColor = Wx::Colour->new( 0, 0, 0 );    #default: background color for rendering
                                                    #my $pixelColor = Wx::Colour->new(255,255,255); #default: background color

    #important accelaration: does the ray intersects the bounding box of the object?
    return $pixelColor if ( not defined( $self->intersectsBoundingBox( $ray, $object ) ) );

    #get closest intersection among all intersections
    my Vertex $intersectionVertex   = undef;
    my Polygon $intersectionPolygon = undef;

    #print "RayCast::rayCast will call findClosestIntersection\n";
    ( $intersectionPolygon, $intersectionVertex ) = $self->findClosestIntersection( $ray, $object );

    #print "RayCast::rayCast FOUND ClosestIntersection.\n" if (defined($intersectionPolygon));
    return $pixelColor if ( not defined($intersectionVertex) );

    #if ray has intersection with an object face calculate color
    return $self->calculateLocalColour( $intersectionVertex, $lights, $object, $intersectionPolygon, $camera, $smoothShades );
}

#
sub calculateLocalColour {
    my $self                        = shift;
    my Vertex $intersectionVertex   = shift;
    my $lights                      = shift;
    my Object3D $object             = shift;
    my Polygon $intersectionPolygon = shift;
    my Camera $camera               = shift;
    my $smoothShades								= shift;

    my $col = $self->{ambientColor};

    #normalized light intensity, that will be lookup up in color table in case the point is in light
    my $lookupVal    = 0;
    my $pointInLight = 0;

    #is intersectionVertex in shadow?
    foreach my $light (@$lights) {
        my Vector $offset_vec = $intersectionPolygon->{normal};

        my Ray $shadowFeeler = new Ray(
            new Vertex(
                $intersectionVertex->{x} + 0.001 * $offset_vec->{x},
                $intersectionVertex->{y} + 0.001 * $offset_vec->{y},
                $intersectionVertex->{z} + 0.001 * $offset_vec->{z}
            ),
            $light );

        #we will send a shadow ray to find out if point is in shadow
        #print "RayCast::calculateLocalColour will test ShadowFiller\n";
        my $hasIntersection = $self->rayIntersectsObject( $shadowFeeler, $object );

        #print "RayCast::calculateLocalColour shadowFiller intersects object, will color ambient\n";

        #if not in shadow, calculate local color and shadows (Phong Model)
        if ( $hasIntersection != 1 ) {    #point in light
        		$lookupVal += $self->localShadeModel( $intersectionVertex, $intersectionPolygon, $shadowFeeler, $camera, $smoothShades );
        		$pointInLight = 1;
        }
    }
    $lookupVal = 1 if ( $lookupVal > 1 );
    $lookupVal = 0 if ( $lookupVal < 0 );

    #print "will look up $lookupVal\n";
    $col = $self->colourTable($lookupVal) if ($pointInLight);
    
 
    return $col;
}

#calculates color for given intersection Vertex on Object
#uses the Phong model and Color Table
sub localShadeModel {
    my $self                        = shift;
    my Vertex $intersectionVertex   = shift;
    my Polygon $intersectionPolygon = shift;
    my Ray $light										= shift;
    my Camera $cam                  = shift;
    my $smoothShades								= shift;

    
    my $vec_L = $light->{direction};
		my Vector $vec_N = undef;
		
    #Phong Model parameters
    my $Ia = 6.0;                               #ambient light
    my $Ii = 12.0;                              #source intensity
    my $d0 = 1.0;
    my $d  = 0.0;
    my $ka = 0.3;                               #ambient light
    my $kd = 1.2;                               #diffuse reflection
    #my $kd = 0.5;
    my $ks = 2;                                 #directed reflection
		#my $ks = 0.7; 
    my $n  = 5;                               #roughness
		#my $n  = 7.0;                               #roughness
		
    if (not $smoothShades) {
    		$vec_N = Vector->new($intersectionPolygon->{normal}); #for non smooth shading
    }
    else{ #for smooth shading   
    	#calculate Normal at intersectionVertex on intersectionPolygon
    	my ($ba,$bb,$bc) = $self->calcBarycentricCoords($intersectionVertex, $intersectionPolygon);
    	#end of vector will be
    	my Vertex $N_isect_end = Vertex->new( #N0
    																					$ba * $intersectionPolygon->{vertices}->[0]->{normal}->{x} +
    																					$bb * $intersectionPolygon->{vertices}->[1]->{normal}->{x} +
    																					$bc * $intersectionPolygon->{vertices}->[2]->{normal}->{x},
    																					
    																					$ba * $intersectionPolygon->{vertices}->[0]->{normal}->{y} +
    																					$bb * $intersectionPolygon->{vertices}->[1]->{normal}->{y} +
    																					$bc * $intersectionPolygon->{vertices}->[2]->{normal}->{y},
    																					
    																					$ba * $intersectionPolygon->{vertices}->[0]->{normal}->{z} +
    																					$bb * $intersectionPolygon->{vertices}->[1]->{normal}->{z} +
    																					$bc * $intersectionPolygon->{vertices}->[2]->{normal}->{z}
    																					
    																			 );
    	
    	#the vector
    	$vec_N = Vector->new($N_isect_end);
		}

    #viewing direction vector
    my Vector $vec_V = new Vector( $intersectionVertex, $cam->{cPosition} );

     #half-way vector
    my Vector $vec_H =
      new Vector(
                  new Vertex( 0.5 * ( $vec_L->{x} + $vec_V->{x} ), 0.5 * ( $vec_L->{y} + $vec_V->{y} ),
                              0.5 * ( $vec_L->{z} + $vec_V->{z} ) ) );
    $vec_V->normalize();
    $vec_H->normalize();

    #print "RayCast::localShadeModel Got H_normalized = $vec_H\n\n";

    my $LdotN = $vec_L->dot($vec_N);
    my $NdotH = $vec_N->dot($vec_H);
    #print "got strange LN = $LdotN\n" if ($LdotN > 1 || $LdotN < -1);
    #print "got strange NH = $NdotH\n" if ($NdotH > 1 || $NdotH < -1);

    $NdotH = 0 if ( $NdotH < 0 );    #must be >= 0 or 0
                                     #phong formula
    my $I = $Ia * $ka + ( $Ii / ( $d + $d0 ) ) * ( $kd * $LdotN + $ks * ( $NdotH**$n ) );

    #it's maximum value
    my $maxI = $Ia * $ka + $Ii * ( $kd + $ks );

    #print "RayCast::localShadeModel about to request color for value I/Imax = : " .$I/$maxI ."\n";
    print "RayCast::localShadeModel found I/Imax > 1 !!\n" if ( $I / $maxI > 1 );

    #return value
    return ( $I / $maxI );

}

#returns a color from the color table, according to requested intensity
sub colourTable($) {
    my $self = shift;
    my $col  = shift;

    my $i = 0;

    #intensity values (0 .. 1) to use
    my @colorTable = ( 0, 1 );

    #my @colorTable = (0, 0.5, 1); #intensity values
    my @RGB = @{ $self->{colorTableRGB} };

    #find closest color value to requested
    for ( $i = 0; ( $colorTable[$i + 1] < $col ) && ( $i < scalar(@colorTable) ); $i++ ) { }
    my $c1 = $colorTable[$i];
    my $c2 = $colorTable[$i + 1];

    if ( $c1 == $c2 ) {
        return Wx::Colour->new( $RGB[$i]{r}, $RGB[$i]{b}, $RGB[$i]{g} );
    }
    else {

        #do linear interpolation
        my $t    = ( $col - $c1 ) / ( $c2 - $c1 );
        my $newR = ( 1 - $t ) * $RGB[$i]{r} + $t * $RGB[$i + 1]{r};
        my $newG = ( 1 - $t ) * $RGB[$i]{g} + $t * $RGB[$i + 1]{g};
        my $newB = ( 1 - $t ) * $RGB[$i]{b} + $t * $RGB[$i + 1]{b};

        return Wx::Colour->new( $newR, $newG, $newB );
    }

}

#find one intersection of ray and object
sub rayIntersectsObject {
    my $self         = shift;
    my Ray $ray      = shift;
    my Object3D $obj = shift;

    my Vertex $intersection = undef;
    foreach my $triangle ( $obj->getPolygons ) {
        $intersection = undef;
        $intersection = $self->rayTriangleIntersection( $ray, $triangle );
        return 1 if defined($intersection);
    }

    #no intersection found
    return 0;
}

#this method calculates barycentric coordinates u,v,s  for an intersection point to the triangle three vertices
#return a list (triad) of the coordinates
sub calcBarycentricCoords {
	my $self = shift;
	my Vertex $isectVertex = shift;
	my Polygon $isectPoly = shift;
	
	my Vector $vec1 = Vector->new($isectPoly->{vertices}->[0], $isectPoly->{vertices}->[1]);
	my Vector $vec2 = Vector->new($isectPoly->{vertices}->[1], $isectPoly->{vertices}->[2]);
	my Vector $normal = $vec1->cross($vec2);
	my $area_full = $normal->norm();
	$vec1 = $vec2 = $normal = undef;
	
	$vec1 = Vector->new($isectPoly->{vertices}->[1], $isectPoly->{vertices}->[2]);
	$vec2 = Vector->new($isectPoly->{vertices}->[1], $isectVertex);
	$normal = $vec1->cross($vec2);
	my $area_bci = $normal->norm();
	$vec1 = $vec2 = $normal = undef;
	
	$vec1 = Vector->new($isectPoly->{vertices}->[2], $isectPoly->{vertices}->[0]);
	$vec2 = Vector->new($isectPoly->{vertices}->[2], $isectVertex);
	$normal = $vec1->cross($vec2);
	my $area_cai = $normal->norm();
	$vec1 = $vec2 = $normal = undef;
	
	my $bary0 = $area_bci / $area_full;
	my $bary1 = $area_cai / $area_full;
	my $bary2 = 1 - $bary1 - $bary0;
	
	return ($bary0, $bary1, $bary2);
	
}


#this is our test for ray Triangle Intersection
#this method is called from more that one place in our Class, but
#after tests, we 've noticed important difference when inlining the function in findClosestIntersection method
#where it is called many times.
##Now we use the method call.
#
#First we check for intersection with the plane and then we do a check to see if
#any intersection found lies in the triangle
sub rayTriangleIntersection {
    my $self             = shift;
    my Ray $ray          = shift;
    my Polygon $triangle = shift;

########### MARK ####

    my $intersection = undef;
    my Vector $normal_vec = $triangle->{normal};    #polygon's normal plane

    #print "RayCast::rayTriangleIntersection\n";
    my $par =
      $normal_vec->{x} * $ray->{direction}->{x} + $normal_vec->{y} * $ray->{direction}->{y} + $normal_vec->{z} *
      $ray->{direction}->{z};    #N * RayDirection
                                 #no intersection, ray is parallel to plane
    return if ( $par < EPSILON && $par > -1 * EPSILON );

    #print "RayCast::rayTriangleIntersection: par = $par\n";

    my $d = {};
    my $a = {};

    $d =
      $normal_vec->{x} * $triangle->{vertices}->[0]->{x} + $normal_vec->{y} * $triangle->{vertices}->[0]->{y} + $normal_vec->{z} *
      $triangle->{vertices}->[0]->{z};

    $a = $normal_vec->{x} * $ray->{origin}->{x} + $normal_vec->{y} * $ray->{origin}->{y} + $normal_vec->{z} * $ray->{origin}->{z};

    $a = $a - $d;

    my $t = -$a / $par;

    #if t > 0 then we 've got an intersection which is after our ray start
    return if $t < EPSILON;


	#now we will check if intersection is on our triangle
	#

  	my Vertex $p1 = $triangle->{vertices}->[0];
    my Vertex $p2 = $triangle->{vertices}->[1];
    my Vertex $p3 = $triangle->{vertices}->[2];

    my $crossVertex = undef;
    $crossVertex->{x} = $ray->{origin}->{x} + $t * $ray->{direction}->{x};
    $crossVertex->{y} = $ray->{origin}->{y} + $t * $ray->{direction}->{y};
    $crossVertex->{z} = $ray->{origin}->{z} + $t * $ray->{direction}->{z};
    
#									#
#									#This is the Sum(Angles) <2 * PI test
#									# you can have a loot here
#									# http://www.peroxide.dk/download/tutorials/tut10/pxdtut10.html
#									#
#									#
#									#It is much simpler to implement but is very slow (as is, without optimizations).
#
#
#									#we need acos function. It is defined in Math::Trig, but you can just define it as:
#									# sub acos { atan2( sqrt(1 - $_[0] * $_[0]), $_[0] ) }
#									use Math::Trig;
#									my Vector $v1 = new Vector($triangle->{vertices}->[0],$crossVertex);
#									my Vector $v2 = new Vector($triangle->{vertices}->[1],$crossVertex);
#									my Vector $v3 = new Vector($triangle->{vertices}->[2],$crossVertex);
#
#									$v1->normalize();
#									$v2->normalize();
#									$v3->normalize();
#
#									my $total_angles += Math::Trig::acos($v1->dot($v2));
#  								$total_angles += Math::Trig::acos($v2->dot($v3));
#  								$total_angles += Math::Trig::acos($v3->dot($v1));
#
#
#    							if (abs($total_angles - 2 * PI) <=0.005) {
#										$intersection = new Vertex ($crossVertex->{x},$crossVertex->{y},$crossVertex->{z});
#								}

  
 
    #project triangle edges on a plane to solve equation

    if ( $normal_vec->{z} < EPSILON && $normal_vec->{z} > -1 * EPSILON ) {
        if ( $normal_vec->{x} < EPSILON && $normal_vec->{x} > -1 * EPSILON ) {

            #use (x,z) plane
            my $g1 =
              $crossVertex->{z} * ( $p2->{x} - $p1->{x} ) + $crossVertex->{x} * ( $p1->{z} - $p2->{z} ) +
              ( $p2->{z} * $p1->{x} - $p1->{z} * $p2->{x} );

            my $g2 =
              $crossVertex->{z} * ( $p3->{x} - $p2->{x} ) + $crossVertex->{x} * ( $p2->{z} - $p3->{z} ) +
              ( $p3->{z} * $p2->{x} - $p2->{z} * $p3->{x} );
            my $g3 =
              $crossVertex->{z} * ( $p1->{x} - $p3->{x} ) + $crossVertex->{x} * ( $p3->{z} - $p1->{z} ) +
              ( $p1->{z} * $p3->{x} - $p3->{z} * $p1->{x} );
            if ( ( $g1 * $g2 > 0 ) && ( $g1 * $g3 > 0 ) ) {
                $intersection = new Vertex( $crossVertex->{x}, $crossVertex->{y}, $crossVertex->{z} );
            }
 
        }
        else {    #(y,z) plane
            my $g1 =
              $crossVertex->{z} * ( $p2->{y} - $p1->{y} ) + $crossVertex->{y} * ( $p1->{z} - $p2->{z} ) +
              ( $p2->{z} * $p1->{y} - $p1->{z} * $p2->{y} );

            my $g2 =
              $crossVertex->{z} * ( $p3->{y} - $p2->{y} ) + $crossVertex->{y} * ( $p2->{z} - $p3->{z} ) +
              ( $p3->{z} * $p2->{y} - $p2->{z} * $p3->{y} );
            my $g3 =
              $crossVertex->{z} * ( $p1->{y} - $p3->{y} ) + $crossVertex->{y} * ( $p3->{z} - $p1->{z} ) +
              ( $p1->{z} * $p3->{y} - $p3->{z} * $p1->{y} );
            if ( ( $g1 * $g2 > 0 ) && ( $g1 * $g3 > 0 ) ) {
                $intersection = new Vertex( $crossVertex->{x}, $crossVertex->{y}, $crossVertex->{z} );
            }

        }
    }

    if ( $normal_vec->{x} < EPSILON && $normal_vec->{x} > -1 * EPSILON ) {
        if ( $normal_vec->{y} < EPSILON && $normal_vec->{y} > -1 * EPSILON ) {

            #use (x,y) plane

            my $g1 =
              $crossVertex->{y} * ( $p2->{x} - $p1->{x} ) + $crossVertex->{x} * ( $p1->{y} - $p2->{y} ) +
              ( $p2->{y} * $p1->{x} - $p1->{y} * $p2->{x} );

            my $g2 =
              $crossVertex->{y} * ( $p3->{x} - $p2->{x} ) + $crossVertex->{x} * ( $p2->{y} - $p3->{y} ) +
              ( $p3->{y} * $p2->{x} - $p2->{y} * $p3->{x} );

            my $g3 =
              $crossVertex->{y} * ( $p1->{x} - $p3->{x} ) + $crossVertex->{x} * ( $p3->{y} - $p1->{y} ) +
              ( $p1->{y} * $p3->{x} - $p3->{y} * $p1->{x} );

            if ( ( $g1 * $g2 > 0 ) && ( $g1 * $g3 > 0 ) ) {
                $intersection = new Vertex( $crossVertex->{x}, $crossVertex->{y}, $crossVertex->{z} );
            }

        }
        else {    #(x,z) plane
            my $g1 =
              $crossVertex->{z} * ( $p2->{x} - $p1->{x} ) + $crossVertex->{x} * ( $p1->{z} - $p2->{z} ) +
              ( $p2->{z} * $p1->{x} - $p1->{z} * $p2->{x} );

            my $g2 =
              $crossVertex->{z} * ( $p3->{x} - $p2->{x} ) + $crossVertex->{x} * ( $p2->{z} - $p3->{z} ) +
              ( $p3->{z} * $p2->{x} - $p2->{z} * $p3->{x} );

            my $g3 =
              $crossVertex->{z} * ( $p1->{x} - $p3->{x} ) + $crossVertex->{x} * ( $p3->{z} - $p1->{z} ) +
              ( $p1->{z} * $p3->{x} - $p3->{z} * $p1->{x} );
            if ( ( $g1 * $g2 > 0 ) && ( $g1 * $g3 > 0 ) ) {
                $intersection = new Vertex( $crossVertex->{x}, $crossVertex->{y}, $crossVertex->{z} );
            }
        }
    }
    else {

        my $g1 =
          $crossVertex->{z} * ( $p2->{y} - $p1->{y} ) + $crossVertex->{y} * ( $p1->{z} - $p2->{z} ) +
          ( $p2->{z} * $p1->{y} - $p1->{z} * $p2->{y} );

        my $g2 =
          $crossVertex->{z} * ( $p3->{y} - $p2->{y} ) + $crossVertex->{y} * ( $p2->{z} - $p3->{z} ) +
          ( $p3->{z} * $p2->{y} - $p2->{z} * $p3->{y} );

        my $g3 =
          $crossVertex->{z} * ( $p1->{y} - $p3->{y} ) + $crossVertex->{y} * ( $p3->{z} - $p1->{z} ) +
          ( $p1->{z} * $p3->{y} - $p3->{z} * $p1->{y} );

        if ( ( $g1 * $g2 > 0 ) && ( $g1 * $g3 > 0 ) ) {
            $intersection = new Vertex( $crossVertex->{x}, $crossVertex->{y}, $crossVertex->{z} );
        }

    }

########### MARK ####

    return $intersection;

}

#find all intersections of an object with a ray and return the closest to Ray
sub findClosestIntersection {
    my $self         = shift;
    my Ray $ray      = shift;
    my Object3D $obj = shift;

    my $min_distance                 = 1E200;
    my Vertex $closestIntersection   = undef;
    my Vertex $intersection          = undef;
    my Polygon $intersectionTriangle = undef;

    foreach my $triangle ( $obj->getPolygons ) {

        #find intersection of ray and triangle
        $intersection = $self->rayTriangleIntersection( $ray, $triangle );

        if ( defined($intersection) ) {    #intersection found
                                           #calculate distance of intersection Vertex from Ray Origin
            my $current_distance = $intersection->distance( $ray->{origin} );
            if ( $current_distance < $min_distance ) {
                $min_distance         = $current_distance;
                $closestIntersection  = $intersection;
                $intersectionTriangle = $triangle;
            }

        }
    }
    return ( $intersectionTriangle, $closestIntersection );    #return vertex with smallest distance and its polygon

}

#returns true if ray intersects object bounding box
#this is an acceleration, before testing each polygon, we check if ray intersects object's box.
sub intersectsBoundingBox {
    my $self         = shift;
    my Ray $ray      = shift;
    my Object3D $obj = shift;

    #z
    #my Vector $normal_vec = new Vector ( new Vertex(0,0,1) ); #plane's normal plane
    #my $par = $normal_vec->{z} * $ray->{direction}->{z}; #N * RayDirection
    my $par = $ray->{direction}->{z};    #N * RayDirection
    return 1 if ( $par < EPSILON && $par > -1 * EPSILON );

    #N * R0 + D (Ax+By+Cz+D = 0 is the plane equation, where D=max_z)
    #my $ar = $normal_vec->{z} * $ray->{origin}->{z} + $obj->{max_z};
    $par = 1 / $par;
    my $tmax_z = ( $obj->{max_z} - $ray->{origin}->{z} ) * $par;
    my $tmin_z = ( $obj->{min_z} - $ray->{origin}->{z} ) * $par;

    #y
    $par = $ray->{direction}->{y};       #N * RayDirection
    return 1 if ( $par < EPSILON && $par > -1 * EPSILON );

    $par = 1 / $par;
    my $tmax_y = ( $obj->{max_y} - $ray->{origin}->{y} ) * $par;
    my $tmin_y = ( $obj->{min_y} - $ray->{origin}->{y} ) * $par;

    #x
    $par = $ray->{direction}->{x};       #N * RayDirection
    return 1 if ( $par < EPSILON && $par > -1 * EPSILON );

    $par = 1 / $par;
    my $tmax_x = ( $obj->{max_x} - $ray->{origin}->{x} ) * $par;
    my $tmin_x = ( $obj->{min_x} - $ray->{origin}->{x} ) * $par;

    #swap max,min if required
    ( $tmax_x, $tmin_x ) = ( $tmin_x, $tmax_x ) if ( $tmin_x > $tmax_x );
    ( $tmax_y, $tmin_y ) = ( $tmin_y, $tmax_y ) if ( $tmin_y > $tmax_y );
    ( $tmax_z, $tmin_z ) = ( $tmin_z, $tmax_z ) if ( $tmin_z > $tmax_z );

    #$t_near is max(tmin)
    my $t_near = ( $tmin_y > $tmin_x ) ? $tmin_y : $tmin_x;
    $t_near = ( $tmin_z > $t_near ) ? $tmin_z : $t_near;

    #$t_far is min(tmax)
    my $t_far = ( $tmax_y < $tmax_x ) ? $tmax_y : $tmax_x;
    $t_far = ( $tmax_z < $t_far ) ? $tmax_z : $t_far;

    #print "\$t_far = $t_far, \$t_near = $t_near\n";

    #find $t_min
    my $t_min = ( $t_far < $t_near ) ? $t_far : $t_near;

    return undef if ( $t_near > $t_far );
    return undef if ( $t_far < $t_min );

    return 1;
}

1;

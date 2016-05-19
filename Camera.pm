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

# Camera - Class to represent our Camera
#

package Camera;
use strict;

use overload '""' => \&stringify;
use constant PI   => 3.14159265358979;

use Vertex;
use Vector;
use Object3D;
use Ray;
use AffineTransform;

#fields:
#position: Camera Position
#vec_N: Viewing Direction Vector (normal to view plane)
#vec_VUV: View Up Vector
#vec_U: VUV x N (direction of increasing 'x' in camera space)
#vec_V: N x U
use fields
  qw (cPosition vec_N lookAt vec_VUV vec_V vec_U focalLength backClipping scrW scrH rayCastScrW rayCastScrH scrCenter scrLU scrRU scrLB frameW frameH)
  ;    #object fields

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    #my $self = {};
    #bless ($self, $class);

    my Camera $self = fields::new($class);    #use pseudohash (array ref) for object

    #set fields
    my Vertex $cameraPosition = shift;
    my Vertex $lookAt         = shift;
    my Vector $vec_VUV        = shift;
    my $scrWidth              = shift;    #height of window on screen, to determine camera parameters. Can be omited (default 480)

    $self->{cPosition} = $cameraPosition; #camera position Vertex
    $self->{lookAt}    = $lookAt;         #lootAt position Vertex
    $self->{vec_VUV}   = $vec_VUV;        #ViewUp Vector

    $self->{scrW}        = 640;                                           #screen (image) width
    $self->{scrH}        = int( $self->{scrW} * 0.7519 + 0.5 );           #screen (image) height
    $self->{rayCastScrW} = 266;                                           #screen (image) width
    $self->{rayCastScrH} = int( $self->{rayCastScrW} * 0.7519 + 0.5 );    #screen (image) height

    #		#some old values
    #		$self->{frameH} = 40;                                           #window (world) height
    #		$self->{frameW} = int( $self->{frameH} * 1.33333333 + 0.5 );    #window (world) weight
    #   $self->{focalLength}  = 30;       #focalLength (near clipping plane)
    #   $self->{backClipping} = 4000;   #back clipping plane

    $self->{frameH}       = 5;       #window (world) height
    $self->{focalLength}  = 4;       #focalLength (near clipping plane)
    $self->{backClipping} = 4000;    #back clipping plane

    $self->{frameW} = int( $self->{frameH} * 1.33333333 + 0.5 );    #window (world) weight

    $self->generateUVN();                                           #generate UVN Vectors

    #calculate screen center
    my Vertex $scrCenter = new Vertex(
        $cameraPosition->{x} + $self->{focalLength} * $self->{vec_N}->{x},
        $cameraPosition->{y} + $self->{focalLength} * $self->{vec_N}->{y},
        $cameraPosition->{z} + $self->{focalLength} * $self->{vec_N}->{z},
    );
    $self->{scrCenter} = $scrCenter;

    #calculate screen U,V vectors
    my $vec_U          = $self->{vec_U};                            #the camera U vector
    my $vec_V          = $self->{vec_V};                            #the camera V vector
    my Vector $screenU =
      new Vector(
        new Vertex( $self->{frameW} * 0.5 * $vec_U->{x}, $self->{frameW} * 0.5 * $vec_U->{y},
            $self->{frameW} * 0.5 * $vec_U->{z} ) );
    my Vector $screenV =
      new Vector(
        new Vertex( $self->{frameH} * 0.5 * $vec_V->{x}, $self->{frameH} * 0.5 * $vec_V->{y},
            $self->{frameH} * 0.5 * $vec_V->{z} ) );

    #calculate screen edges vectices
    #left-upper
    $self->{scrLU} = new Vertex(
        -$screenU->{x} + $screenV->{x} + $scrCenter->{x},           #x
        -$screenU->{y} + $screenV->{y} + $scrCenter->{y},           #y
        -$screenU->{z} + $screenV->{z} + $scrCenter->{z}            #z
    );

    #right-upper
    $self->{scrRU} = new Vertex(
        $screenU->{x} + $screenV->{x} + $scrCenter->{x},            #x
        $screenU->{y} + $screenV->{y} + $scrCenter->{y},            #y
        $screenU->{z} + $screenV->{z} + $scrCenter->{z}             #z
    );

    #left bottom
    $self->{scrLB} = new Vertex(
        -$screenU->{x} - $screenV->{x} + $scrCenter->{x},           #x
        -$screenU->{y} - $screenV->{y} + $scrCenter->{y},           #y
        -$screenU->{z} - $screenV->{z} + $scrCenter->{z}            #z
    );

    return $self;
}

sub setScreenWidth {
    my $self = shift;

    my $w = shift;

    if ( defined($w) ) {
        $self->{scrW} = $w;                      #screen (image) width
        $self->{scrH} = $self->{scrW} * 0.75;    #screen (image) height
    }

}

sub generateUVN {
    my $self = shift;

    my Vector $vec_VUV = $self->{vec_VUV};

    #Generate U,V
    my Vector $vec_N = new Vector( $self->{cPosition}, $self->{lookAt} );
    my Vector $vec_U = $vec_VUV->cross($vec_N);
    my Vector $vec_V = $vec_N->cross($vec_U);

    #Normalize V,U,N Vectors
    $vec_V->normalize();
    $vec_U->normalize();
    $vec_N->normalize();

    $self->{vec_VUV} = $vec_VUV;
    $self->{vec_N}   = $vec_N;
    $self->{vec_U}   = $vec_U;
    $self->{vec_V}   = $vec_V;

}

sub getN {
    my $self = shift;
    return $self->{vec_N};
}

sub getV {
    my $self = shift;
    return $self->{vec_V};

}

sub getU {
    my $self = shift;
    return $self->{vec_U};
}

sub getPosition {
    my $self = shift;
    return $self->{cPosition};
}

sub setPosition {
    my $self        = shift;
    my $camPosition = shift;
    $self->{cPosition} = $camPosition;
    $self->generateUVN();
}

#tranform object to the opposite direction of requested camera movement
sub orbit {
    my $self              = shift;
    my Object3D $pivotObj = shift;
    my $phi               = shift;
    my $theta             = shift;
    my $zoom              = shift;
    my $viewType          = shift || "raycast";    #"wireframe" or "raycast"?

    #my Vertex $pivotVertex = new Vertex($pivotObj->{objectCenter}); #object center / pivot vertex
    my AffineTransform $cameraOrbit = new AffineTransform;
    my $finalT = undef;

    #$pivotObj->getBoundingBoxAndCenter();
    my Vertex $pivotVertex = $pivotObj->{objectCenter};

    #translate to -ObjectCenter
    $cameraOrbit->translate( -$pivotVertex->{x}, -$pivotVertex->{y}, -$pivotVertex->{z} );

    #scale object
    $cameraOrbit->scale($zoom);

    #$get final transformation Matrix to finalT ref.
    $finalT = $cameraOrbit->getFinalTransformMatrix();

    #apply cameraRotation AffineTransform to object
    $pivotObj->transformVertices($finalT);

    $cameraOrbit = new AffineTransform;

    #rotate
    $cameraOrbit->rotateX( -$theta );
    $cameraOrbit->rotateZ( -$phi );

    #$cameraOrbit->rotateY(-$theta);

    #$get final transformation Matrix to finalT ref.
    $finalT = $cameraOrbit->getFinalTransformMatrix();

    #apply cameraRotation AffineTransform to object
    $pivotObj->transformVertices($finalT);
    $pivotObj->transformFaceNormals($finalT);
    $pivotObj->transformVerticesNormals($finalT) if ( $viewType eq "raycast" && $pivotObj->{smoothShades} );

    $cameraOrbit = new AffineTransform;

    #translate to ObjectCenter
    #print "moving back to $pivotVertex\n";
    $cameraOrbit->translate2Vertex($pivotVertex);

    #$get final transformation Matrix to finalT ref.
    $finalT = $cameraOrbit->getFinalTransformMatrix();

    #apply cameraRotation AffineTransform to object
    $pivotObj->transformVertices($finalT);

}

#transform WCS to CS
sub world2Camera {
    my $self = shift;
    my Object3D $obj = shift;

    #Create a new affine transform
    my AffineTransform $w2cTransform = new AffineTransform();

    #move camera to origin
    $w2cTransform->translate( -$self->{cPosition}->{x}, -$self->{cPosition}->{y}, -$self->{cPosition}->{z} );

    #$get final transformation Matrix to finalT ref.
    my $finalT = $w2cTransform->getFinalTransformMatrix();
    $obj->transformVertices($finalT);

    $w2cTransform = new AffineTransform();

    #Transform to camera coordinates
    #[Ux Uy Uz 0]
    #[Vx Vy Vz 0]
    #[Nx Ny Nz 0]
    #[0  0  0  1]
    my @T = $w2cTransform->getIdentityMatrix();
    $T[0] = $self->{vec_U}->{x};
    $T[1] = $self->{vec_U}->{y};
    $T[2] = $self->{vec_U}->{z};

    $T[4] = $self->{vec_V}->{x};
    $T[5] = $self->{vec_V}->{y};
    $T[6] = $self->{vec_V}->{z};

    $T[8]  = $self->{vec_N}->{x};
    $T[9]  = $self->{vec_N}->{y};
    $T[10] = $self->{vec_N}->{z};

    $w2cTransform->arbitraryMatrix( \@T );

    #$get final transformation Matrix to finalT ref.
    $finalT = $w2cTransform->getFinalTransformMatrix();

    #print "\nCamera Transformation Matrix is: @{$viewTransform->getTransformMatrix()}\n";

    #transform Object
    $obj->transformVertices($finalT);
    $obj->transformFaceNormals($finalT);

}

#Transform object for perspective view and tranform nomalized perspective output to canvas/image dimensions
sub perspectiveTransform {
    my $self = shift;
    my Object3D $obj = shift;

    #perspective transform parameters
    my $d = $self->{focalLength};
    my $f = $self->{backClipping};

    #my $h = $self->{frameH} * 0.5;
    #my $h = $self->{frameW} * 0.5;
    my $h = $self->{frameW} * 0.75;

    #clip object
    $obj->ClipObject( $d, $f );

    #Transform object for perspective view (results x in [-1,1], y in [-1,1], z in [0,1])
    my AffineTransform $viewTransform = new AffineTransform();
    my @T = $viewTransform->getIdentityMatrix();
    $T[0] = $T[5] = $d / $h;
    $T[10] = $f / ( $f - $d );
    $T[11] = -$f * $d / ( $f - $d );
    $T[14] = 1;
    $T[15] = 0;
    $viewTransform->arbitraryMatrix( \@T );

    #Transform object's vertices to canvas (image) dimensions
    @T    = $viewTransform->getIdentityMatrix();
    $T[0] = $self->{scrW} * 0.5;
    $T[5] = $self->{scrH} * 0.5;
    $viewTransform->arbitraryMatrix( \@T );
    $viewTransform->translate( $self->{scrW} * 0.5, $self->{scrH} * 0.5, 0 );

    my $finalT = $viewTransform->getFinalTransformMatrix();

    #transform all visible (not hidden) faces
    $obj->transformVisible($finalT);

}

#getRay expects $i, $j pixel and returns a Ray Object directed from camera Origin to pixel position on window.
#-- method inlined in Object3D render(), for speed.
sub getRay {
    my $self = shift;
    my ( $i, $j ) = @_;

    $i = ( 0.5 + $i ) / $self->{rayCastScrW};
    $j = ( 0.5 + $j ) / $self->{rayCastScrH};

    my Vertex $P_onScreen = new Vertex(
        $self->{scrLU}->{x} + ( $i * ( $self->{scrRU}->{x} - $self->{scrLU}->{x} ) ) +
          ( $j * ( $self->{scrLB}->{x} - $self->{scrLU}->{x} ) ),
        $self->{scrLU}->{y} + ( $i * ( $self->{scrRU}->{y} - $self->{scrLU}->{y} ) ) +
          ( $j * ( $self->{scrLB}->{y} - $self->{scrLU}->{y} ) ),
        $self->{scrLU}->{z} + ( $i * ( $self->{scrRU}->{z} - $self->{scrLU}->{z} ) ) +
          ( $j * ( $self->{scrLB}->{z} - $self->{scrLU}->{z} ) )
    );    #point that ray is crossing screen
    my Ray $ray = new Ray( $self->{cPosition}, $P_onScreen );    #the ray vector

    return $ray;
}

#object stringification
sub stringify {
    my $self   = shift;
    my $string = undef;
    $string =
        "Camera: (cPosition, focalLength, scrLU,scrRU,scrLB) = "
      . $self->{cPosition} . " "
      . $self->{focalLength} . " "
      . $self->{scrLU} . " "
      . $self->{scrRU} . " "
      . $self->{scrLB} . "\n";
    return "$string";
}

1;
